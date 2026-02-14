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

const runClaudeMem = async (
	$: PluginInput["$"],
	args: string[],
): Promise<{ data: string; error: null } | { data: null; error: string }> => {
	const binPath = getBinPath();
	const result = await $`${binPath} ${args}`.quiet().nothrow();
	if (result.exitCode !== 0) {
		const errMsg = result.stderr ? result.text() : "Unknown error";
		return { data: null, error: errMsg };
	}
	return { data: result.text(), error: null };
};

export const opencodeMem: Plugin = async (ctx: PluginInput) => {
	const { client, $, directory } = ctx;

	// Use Bun.file for non-blocking binary existence check
	const binPath = getBinPath();
	const isBinaryPresent = await Bun.file(binPath).exists();

	// If binary exists, check for updates in the background
	if (isBinaryPresent) {
		ensureBinaryUpToDate($, client.app.log);
	}

	// Pre-fetch context eagerly so system.transform returns instantly
	let cachedContext: string | null = null;
	let contextReady = false;

	const refreshContext = () => {
		if (!isBinaryPresent) return;
		runClaudeMem($, ["hook:context", "--project", directory]).then((result) => {
			cachedContext = result.error ? null : result.data;
			contextReady = true;
		});
	};

	// Start fetching context immediately at plugin init
	refreshContext();

	return {
		"experimental.chat.system.transform": async (_input, output) => {
			if (!isBinaryPresent && !contextReady) {
				// Binary missing — try to download (blocks only on first use with no binary)
				const success = await ensureBinaryUpToDate($, client.app.log);
				if (!success) return;
				const result = await runClaudeMem($, [
					"hook:context",
					"--project",
					directory,
				]);
				if (result.data) {
					output.system.push(result.data);
				}
				return;
			}

			// Return cached context immediately (non-blocking)
			if (cachedContext) {
				output.system.push(cachedContext);
			}

			// Refresh context in the background for next message
			refreshContext();
		},

		"tool.execute.after": async (input, _output) => {
			if (!isBinaryPresent) return;
			const toolName = input.tool;
			const args = JSON.stringify(input.args || {});
			const toolOutput = _output.output || "";

			// Fire-and-forget to avoid blocking OpenCode's UI
			runClaudeMem($, [
				"hook:save",
				"--project",
				directory,
				"--tool",
				toolName,
				"--args",
				args,
				"--result",
				toolOutput,
			]);
		},

		"experimental.session.compacting": async (_input, output) => {
			if (!isBinaryPresent) return;
			const summaryResult = await runClaudeMem($, [
				"hook:summary",
				"--project",
				directory,
			]);

			if (summaryResult.data) {
				output.context.push(summaryResult.data);
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
						const result = await runClaudeMem($, [
							"search",
							"--query",
							args.query,
							"--project",
							context.directory,
						]);
						if (result.error) {
							return `Error searching memory: ${result.error}`;
						}
						return result.data || "No results found";
					}

					if (args.action === "list") {
						const result = await runClaudeMem($, [
							"list",
							"--project",
							context.directory,
						]);
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
