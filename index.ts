import type { Plugin, PluginInput } from "@opencode-ai/plugin";
import { tool } from "@opencode-ai/plugin";

const getBinPath = (): string => {
	return `${import.meta.dirname}/bin/claude-mem`;
};

const getPlatformBinaryName = (): string => {
	const platform = process.platform;
	const arch = process.arch;

	if (platform === "darwin") {
		return arch === "arm64"
			? "claude-mem-darwin-arm64"
			: "claude-mem-darwin-x64";
	}
	if (platform === "linux") {
		return arch === "arm64" ? "claude-mem-linux-arm64" : "claude-mem-linux-x64";
	}

	throw new Error(`Unsupported platform: ${platform} ${arch}`);
};

const getCurrentVersion = async (
	$: PluginInput["$"],
): Promise<string | null> => {
	const binPath = getBinPath();
	const result = await $`${binPath} version`.quiet().nothrow();
	if (result.exitCode !== 0) {
		return null;
	}
	const text = result.text();
	const match = text.match(/v?(\d+\.\d+\.\d+)/);
	return match ? match[1] : null;
};

const getLatestVersion = async (): Promise<{
	version: string;
	downloadUrl: string;
} | null> => {
	const response = await fetch(
		"https://api.github.com/repos/RageLtd/claude-mem/releases/latest",
		{
			headers: {
				"User-Agent": "opencode-mem",
			},
		},
	);

	if (!response.ok) {
		return null;
	}

	const data = (await response.json()) as {
		tag_name: string;
		assets: Array<{ name: string; browser_download_url: string }>;
	};

	const binaryName = getPlatformBinaryName();
	const asset = data.assets.find((a) => a.name === binaryName);

	if (!asset) {
		return null;
	}

	const version = data.tag_name.replace(/^v/, "");
	return {
		version,
		downloadUrl: asset.browser_download_url,
	};
};

const downloadBinary = async (
	$: PluginInput["$"],
	url: string,
): Promise<{ data: true; error: null } | { data: null; error: string }> => {
	const binPath = getBinPath();
	const binDir = binPath.replace(/\/[^/]+$/, "");

	const mkdirResult = await $`mkdir -p ${binDir}`.quiet().nothrow();
	if (mkdirResult.exitCode !== 0) {
		return { data: null, error: "Failed to create bin directory" };
	}

	const curlResult = await $`curl -fSL -o ${binPath} ${url}`.quiet().nothrow();
	if (curlResult.exitCode !== 0) {
		return {
			data: null,
			error: `curl failed (exit ${curlResult.exitCode}): ${curlResult.text()}`,
		};
	}

	const chmodResult = await $`chmod +x ${binPath}`.quiet().nothrow();
	if (chmodResult.exitCode !== 0) {
		return { data: null, error: "Failed to make binary executable" };
	}

	return { data: true, error: null };
};

const ensureBinaryUpToDate = async (
	$: PluginInput["$"],
	log: PluginInput["client"]["app"]["log"],
): Promise<boolean> => {
	const currentVersion = await getCurrentVersion($);
	const latest = await getLatestVersion();

	if (!latest) {
		await log({
			body: {
				service: "opencode-mem",
				level: "warn",
				message: "Could not check for latest claude-mem version",
			},
		});
		return currentVersion !== null;
	}

	const needsUpdate = !currentVersion || latest.version !== currentVersion;

	if (needsUpdate) {
		await log({
			body: {
				service: "opencode-mem",
				level: "info",
				message: `Updating claude-mem from ${currentVersion || "none"} to ${latest.version}`,
			},
		});

		const downloadResult = await downloadBinary($, latest.downloadUrl);
		if (downloadResult.error) {
			await log({
				body: {
					service: "opencode-mem",
					level: "error",
					message: "Failed to download claude-mem",
					extra: { error: downloadResult.error },
				},
			});
			return false;
		}
	}

	return true;
};

/**
 * Runs a claude-mem hook by piping JSON input via stdin.
 * The binary reads JSON from stdin and writes JSON to stdout.
 */
const runHook = async (
	$: PluginInput["$"],
	command: string,
	input: Record<string, unknown>,
): Promise<{ data: string | null; error: string | null }> => {
	const binPath = getBinPath();
	const jsonInput = JSON.stringify(input);
	const result = await $`echo ${jsonInput} | ${binPath} ${command}`
		.quiet()
		.nothrow();

	if (result.exitCode !== 0) {
		return { data: null, error: result.text() || "Unknown error" };
	}

	return { data: result.text(), error: null };
};

/**
 * Parses hook output JSON to extract context or additional info.
 */
const parseHookOutput = (
	raw: string,
): {
	context: string | null;
	systemMessage: string | null;
} => {
	const parsed = JSON.parse(raw) as {
		continue: boolean;
		systemMessage?: string;
		hookSpecificOutput?: {
			additionalContext?: string;
		};
	};
	return {
		context: parsed.hookSpecificOutput?.additionalContext ?? null,
		systemMessage: parsed.systemMessage ?? null,
	};
};

export const opencodeMem: Plugin = async (ctx: PluginInput) => {
	const { client, $, directory } = ctx;

	// Lazy state — no work done until first hook fires
	let binaryChecked = false;
	let isBinaryPresent = false;
	let contextLoaded = false;
	let cachedContext: string | null = null;

	const checkBinary = async (): Promise<boolean> => {
		if (binaryChecked) return isBinaryPresent;
		binaryChecked = true;
		isBinaryPresent = await Bun.file(getBinPath()).exists();
		if (isBinaryPresent) {
			// Background update check — no blocking
			ensureBinaryUpToDate($, client.app.log);
		}
		return isBinaryPresent;
	};

	return {
		"experimental.chat.system.transform": async (_input, output) => {
			const hasBinary = await checkBinary();

			if (!hasBinary) {
				// Binary missing — try to download (blocks only on first use with no binary)
				const success = await ensureBinaryUpToDate($, client.app.log);
				if (!success) return;
				isBinaryPresent = true;
			}

			// Load context once per session (mirrors Claude Code's SessionStart hook)
			if (!contextLoaded) {
				contextLoaded = true;
				const result = await runHook($, "hook:context", {
					cwd: directory,
				});
				if (result.data) {
					const parsed = parseHookOutput(result.data);
					cachedContext = parsed.context ?? null;
				}
			}

			if (cachedContext) {
				output.system.push(cachedContext);
			}
		},

		"tool.execute.after": async (input, _output) => {
			if (!isBinaryPresent) return;

			// Fire-and-forget to avoid blocking OpenCode's UI
			runHook($, "hook:save", {
				session_id: "",
				cwd: directory,
				tool_name: input.tool,
				tool_input: input.args || {},
				tool_response: (_output.output || "").slice(0, 4096),
			});
		},

		"experimental.session.compacting": async (_input, output) => {
			if (!isBinaryPresent) return;
			const result = await runHook($, "hook:summary", {
				session_id: "",
				cwd: directory,
			});

			if (result.data) {
				const parsed = parseHookOutput(result.data);
				if (parsed.context) {
					output.context.push(parsed.context);
				}
			}
		},

		tool: {
			memory: tool({
				description:
					"Search and manage persistent memory from OpenCode sessions",
				args: {
					query: tool.schema.string().optional(),
					action: tool.schema
						.enum(["search", "list", "clear"])
						.default("search"),
				},
				async execute(args, context) {
					if (args.action === "search" && args.query) {
						const result = await runHook($, "hook:context", {
							cwd: context.directory,
							query: args.query,
						});
						if (result.error) {
							return `Error searching memory: ${result.error}`;
						}
						return result.data || "No results found";
					}

					if (args.action === "list") {
						const result = await runHook($, "hook:context", {
							cwd: context.directory,
						});
						if (result.error) {
							return `Error listing memory: ${result.error}`;
						}
						return result.data || "No memories found";
					}

					if (args.action === "clear") {
						return "Use the claude-mem CLI to clear memory";
					}

					return "Unknown action";
				},
			}),
		},
	};
};

export default opencodeMem;
