# Setup script for fancy-agents Claude Code environment (Windows)
# Installs dependencies, configures the RageLtd/claude-mem marketplace,
# and installs Claude Code rules to the target project or globally.
#
# Usage: .\scripts\setup.ps1 [-InstallMemory] [project-path]
#   -InstallMemory: install the RageLtd/claude-mem marketplace
#   project-path:   optional path to a project directory
#                   rules install to <project-path>\.claude\rules\
#                   if omitted, rules install to ~\.claude\rules\ (global)

param(
    [switch]$InstallMemory,
    [string]$TargetPath = ""
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir

Write-Host "=== Fancy Agents - Claude Code Setup ===" -ForegroundColor Cyan
Write-Host ""

# Helper functions
function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Green }
function Write-Warn { param($Message) Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Write-Err { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }

# Check if a command exists
function Test-Command {
    param($Command)
    $exists = $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
    if ($exists) {
        Write-Info "$Command is installed"
    } else {
        Write-Warn "$Command is not installed"
    }
    return $exists
}

# Install TypeScript LSP
function Install-TypeScriptLSP {
    Write-Info "Checking TypeScript LSP..."

    if (Test-Command "typescript-language-server") {
        return $true
    }

    if (Test-Command "npm") {
        Write-Info "Installing typescript-language-server via npm..."
        npm install -g typescript-language-server typescript
        return $true
    } elseif (Test-Command "pnpm") {
        Write-Info "Installing typescript-language-server via pnpm..."
        pnpm add -g typescript-language-server typescript
        return $true
    } elseif (Test-Command "yarn") {
        Write-Info "Installing typescript-language-server via yarn..."
        yarn global add typescript-language-server typescript
        return $true
    } else {
        Write-Err "No package manager (npm/pnpm/yarn) found. Please install Node.js first."
        return $false
    }
}

# Install Rust Analyzer
function Install-RustAnalyzer {
    Write-Info "Checking Rust Analyzer..."

    if (Test-Command "rust-analyzer") {
        return $true
    }

    if (Test-Command "rustup") {
        Write-Info "Installing rust-analyzer via rustup..."
        rustup component add rust-analyzer
        return $true
    } elseif (Test-Command "winget") {
        Write-Info "Installing rust-analyzer via winget..."
        winget install --id RustLang.rust-analyzer -e
        return $true
    } elseif (Test-Command "choco") {
        Write-Info "Installing rust-analyzer via Chocolatey..."
        choco install rust-analyzer -y
        return $true
    } elseif (Test-Command "scoop") {
        Write-Info "Installing rust-analyzer via Scoop..."
        scoop install rust-analyzer
        return $true
    } else {
        Write-Warn "Please install rust-analyzer manually:"
        Write-Warn "  - Via rustup: rustup component add rust-analyzer"
        Write-Warn "  - Via winget: winget install RustLang.rust-analyzer"
        Write-Warn "  - Or download from: https://github.com/rust-lang/rust-analyzer/releases"
        return $false
    }
}

# Add RageLtd/claude-mem marketplace
function Add-ClaudeMemMarketplace {
    Write-Info "Adding RageLtd/claude-mem marketplace..."

    $claudeDir = Join-Path $env:USERPROFILE ".claude"
    $pluginsDir = Join-Path $claudeDir "plugins"
    $marketplacesFile = Join-Path $pluginsDir "known_marketplaces.json"
    $marketplaceInstallDir = Join-Path $pluginsDir "marketplaces\rageltd"

    # Create directories if they don't exist
    $marketplacesDir = Join-Path $pluginsDir "marketplaces"
    if (-not (Test-Path $marketplacesDir)) {
        New-Item -ItemType Directory -Path $marketplacesDir -Force | Out-Null
    }

    # Clone or update the marketplace
    if (Test-Path $marketplaceInstallDir) {
        Write-Info "Marketplace already cloned, updating..."
        Push-Location $marketplaceInstallDir
        try {
            git pull origin main 2>$null
            if ($LASTEXITCODE -ne 0) {
                git pull origin master 2>$null
            }
        } catch {
            Write-Warn "Could not update marketplace, continuing..."
        }
        Pop-Location
    } else {
        Write-Info "Cloning RageLtd/claude-mem marketplace..."
        git clone https://github.com/RageLtd/claude-mem.git $marketplaceInstallDir
    }

    # Update known_marketplaces.json
    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.000Z")

    $rageltdEntry = @{
        source = @{
            source = "git"
            url = "https://github.com/RageLtd/claude-mem.git"
        }
        installLocation = $marketplaceInstallDir.Replace('\', '/')
        lastUpdated = $timestamp
    }

    if (Test-Path $marketplacesFile) {
        $marketplaces = Get-Content $marketplacesFile -Raw | ConvertFrom-Json

        # Check if rageltd entry already exists
        if ($null -eq $marketplaces.rageltd) {
            Write-Info "Adding marketplace entry to known_marketplaces.json..."
            $marketplaces | Add-Member -NotePropertyName "rageltd" -NotePropertyValue $rageltdEntry -Force
        } else {
            Write-Info "Marketplace entry already exists, updating..."
            $marketplaces.rageltd = $rageltdEntry
        }

        $marketplaces | ConvertTo-Json -Depth 10 | Set-Content $marketplacesFile -Encoding UTF8
    } else {
        Write-Info "Creating known_marketplaces.json..."
        @{ rageltd = $rageltdEntry } | ConvertTo-Json -Depth 10 | Set-Content $marketplacesFile -Encoding UTF8
    }

    Write-Info "Marketplace configured successfully!"
    return $true
}

# Install Claude Code rules
function Install-Rules {
    $sourceRules = Join-Path $RepoRoot ".claude\rules"

    if (-not (Test-Path $sourceRules)) {
        Write-Err "Rules directory not found at $sourceRules"
        return $false
    }

    if ($TargetPath -ne "") {
        $dest = Join-Path $TargetPath ".claude\rules"
        Write-Info "Installing rules to project: $dest"
    } else {
        $dest = Join-Path $env:USERPROFILE ".claude\rules"
        Write-Info "Installing rules globally: $dest"
    }

    if (-not (Test-Path $dest)) {
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
    }

    Copy-Item -Path "$sourceRules\*" -Destination $dest -Recurse -Force
    Write-Info "Rules installed successfully!"
    return $true
}

# Main setup
Write-Host ""
Write-Info "Installing dependencies..."
Write-Host ""

$failures = 0

if (-not (Install-TypeScriptLSP)) { $failures++ }
Write-Host ""

if (-not (Install-RustAnalyzer)) { $failures++ }
Write-Host ""

if ($InstallMemory) {
    if (-not (Add-ClaudeMemMarketplace)) { $failures++ }
} else {
    Write-Info "Skipping claude-mem marketplace (use -InstallMemory to include)"
}
Write-Host ""

if (-not (Install-Rules)) { $failures++ }
Write-Host ""

# Summary
Write-Host "=== Setup Complete ===" -ForegroundColor Cyan
if ($failures -eq 0) {
    Write-Info "All dependencies installed successfully!"
} else {
    Write-Warn "$failures component(s) could not be installed automatically."
    Write-Warn "Please install them manually and re-run this script."
}

Write-Host ""
Write-Info "Next steps:"
Write-Host "  1. Restart Claude Code to pick up the new marketplace"
Write-Host "  2. Run '/plugins' to see available plugins from RageLtd/claude-mem"
Write-Host "  3. Enable desired plugins in Claude Code settings"
Write-Host ""
