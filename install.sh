#!/bin/bash

# Endor Labs Claude Code Skill Installer
# This script installs the Endor Labs skills, rules, and hooks
# into your Claude Code configuration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_SOURCE="$SCRIPT_DIR"

# Validate source directories
if [ ! -d "$SKILL_SOURCE/skills" ]; then
    echo "Error: Skills directory not found at $SKILL_SOURCE/skills"
    echo "Please run this script from the endor-solutions-claude-skills repository root."
    exit 1
fi

if [ ! -d "$SKILL_SOURCE/hooks" ]; then
    echo "Warning: Hooks directory not found at $SKILL_SOURCE/hooks"
    echo "Hooks will not be installed."
    SKIP_HOOKS=true
else
    SKIP_HOOKS=false
fi

echo "==================================="
echo "Endor Labs Claude Code Skill Setup"
echo "==================================="
echo

# Check for endorctl
if ! command -v endorctl &> /dev/null; then
    echo "Warning: endorctl not found in PATH"
    echo "Install it with one of these methods:"
    echo "  - brew install endorlabs/tap/endorctl"
    echo "  - npm install -g endorctl"
    echo "  - curl -sSL https://api.endorlabs.com/download/latest/endorctl_\$(uname -s | tr '[:upper:]' '[:lower:]')_\$(uname -m | sed 's/x86_64/amd64/' | sed 's/aarch64/arm64/') -o endorctl && chmod +x endorctl"
    echo
fi

# Check for ENDOR_NAMESPACE
if [ -z "$ENDOR_NAMESPACE" ]; then
    echo "Warning: ENDOR_NAMESPACE environment variable not set"
    echo "Set it with: export ENDOR_NAMESPACE=your-namespace"
    echo
fi

# Choose installation type
echo "Where do you want to install the skill?"
echo "1) Current project (./.claude) - Team can share via git (copies files)"
echo "2) User home (~/.claude) - Available in all projects (symlinks for auto-updates)"
echo "3) Custom path (copies files)"
echo
read -p "Choose option [1-3]: " choice

case $choice in
    1)
        INSTALL_DIR="./.claude"
        USE_SYMLINKS=false
        ;;
    2)
        INSTALL_DIR="$HOME/.claude"
        USE_SYMLINKS=true
        ;;
    3)
        read -p "Enter custom path: " INSTALL_DIR
        USE_SYMLINKS=false
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

# Create directories if needed
mkdir -p "$INSTALL_DIR/skills"
mkdir -p "$INSTALL_DIR/rules"
if [ "$SKIP_HOOKS" = false ]; then
    mkdir -p "$INSTALL_DIR/hooks"
fi

echo "Installing to $INSTALL_DIR..."

if [ "$USE_SYMLINKS" = true ]; then
    echo "Using symlinks (updates to the source repo will apply automatically)"
    echo

    # Symlink each skill directory
    for skill_dir in "$SKILL_SOURCE/skills/"*/; do
        skill_name=$(basename "$skill_dir")
        target="$INSTALL_DIR/skills/$skill_name"
        if [ -L "$target" ]; then
            rm "$target"
        elif [ -d "$target" ]; then
            echo "  Warning: $skill_name exists as a regular directory, replacing with symlink"
            rm -rf "$target"
        fi
        ln -s "$skill_dir" "$target"
        echo "  Linked: $skill_name"
    done

    # Symlink each rule file
    for rule_file in "$SKILL_SOURCE/rules/"*.md; do
        rule_name=$(basename "$rule_file")
        target="$INSTALL_DIR/rules/$rule_name"
        if [ -L "$target" ]; then
            rm "$target"
        elif [ -f "$target" ]; then
            echo "  Warning: $rule_name exists as a regular file, replacing with symlink"
            rm "$target"
        fi
        ln -s "$rule_file" "$target"
        echo "  Linked: $rule_name"
    done

    # Symlink each hook script
    if [ "$SKIP_HOOKS" = false ]; then
        for hook_file in "$SKILL_SOURCE/hooks/"*.sh; do
            hook_name=$(basename "$hook_file")
            target="$INSTALL_DIR/hooks/$hook_name"
            if [ -L "$target" ]; then
                rm "$target"
            elif [ -f "$target" ]; then
                echo "  Warning: $hook_name exists as a regular file, replacing with symlink"
                rm "$target"
            fi
            ln -s "$hook_file" "$target"
            echo "  Linked: $hook_name"
        done

        # Copy hooks README
        if [ -f "$SKILL_SOURCE/hooks/README.md" ]; then
            target="$INSTALL_DIR/hooks/README.md"
            if [ -L "$target" ]; then
                rm "$target"
            fi
            ln -s "$SKILL_SOURCE/hooks/README.md" "$target"
            echo "  Linked: README.md (hooks)"
        fi
    fi
else
    echo "Copying files..."
    echo

    # Copy skills
    if ! cp -r "$SKILL_SOURCE/skills/"* "$INSTALL_DIR/skills/"; then
        echo "Error: Failed to copy skills from $SKILL_SOURCE/skills/"
        exit 1
    fi

    # Copy rules
    if ! cp -r "$SKILL_SOURCE/rules/"* "$INSTALL_DIR/rules/"; then
        echo "Error: Failed to copy rules from $SKILL_SOURCE/rules/"
        exit 1
    fi

    # Copy hooks
    if [ "$SKIP_HOOKS" = false ]; then
        if ! cp -r "$SKILL_SOURCE/hooks/"* "$INSTALL_DIR/hooks/"; then
            echo "Error: Failed to copy hooks from $SKILL_SOURCE/hooks/"
            exit 1
        fi
        # Ensure hook scripts are executable
        chmod +x "$INSTALL_DIR/hooks/"*.sh 2>/dev/null || true
        echo "  Installed hooks ($(ls -1 "$INSTALL_DIR/hooks/"*.sh 2>/dev/null | wc -l | tr -d ' ') scripts)"
    fi
fi

# Merge or create settings.json
if [ -f "$INSTALL_DIR/settings.json" ]; then
    echo
    echo "Existing settings.json found. Please manually merge:"
    echo "  - MCP server configuration (mcpServers)"
    echo "  - Hooks configuration (hooks)"
    echo
    echo "Source file: $SKILL_SOURCE/settings.json"
    echo
else
    cp "$SKILL_SOURCE/settings.json" "$INSTALL_DIR/settings.json"
    echo "Created settings.json with MCP server and hooks configuration"
fi

# Copy CLAUDE.md if installing to project
if [ "$choice" = "1" ]; then
    if [ -f "./CLAUDE.md" ]; then
        echo "Existing CLAUDE.md found. Please manually merge content from:"
        echo "$SCRIPT_DIR/CLAUDE.md"
    else
        cp "$SCRIPT_DIR/CLAUDE.md" "./CLAUDE.md"
        echo "Created CLAUDE.md with project instructions"
    fi
fi

echo
echo "==================================="
echo "Installation complete!"
echo "==================================="
echo
if [ "$USE_SYMLINKS" = true ]; then
    echo "Skills, rules, and hooks are symlinked to: $SCRIPT_DIR"
    echo "Any updates to that repo (e.g. git pull) will apply automatically."
    echo
fi
echo "Available commands:"
echo "  /endor                   - Main security assistant (routes to specialized skills)"
echo "  /endor-setup             - First-time setup wizard"
echo "  /endor-help              - Full command reference"
echo "  /endor-scan              - Quick security scan"
echo "  /endor-scan-full         - Deep scan with reachability analysis"
echo "  /endor-check             - Check a dependency for vulnerabilities"
echo "  /endor-fix               - Remediate vulnerabilities"
echo "  /endor-explain           - Explain a CVE"
echo "  /endor-findings          - View security findings"
echo "  /endor-review            - Pre-PR security review"
echo "  /endor-score             - Package health scores"
echo "  /endor-upgrade-impact    - Analyze upgrade impact (Endor Labs UIA)"
echo "  /endor-secrets           - Scan for exposed secrets"
echo "  /endor-sast              - Static application security testing"
echo "  /endor-ai-sast           - View AI-powered SAST findings"
echo "  /endor-license           - License compliance check"
echo "  /endor-container         - Container/Dockerfile scanning"
echo "  /endor-sbom              - Software Bill of Materials"
echo "  /endor-policy            - Security policy management"
echo "  /endor-cicd              - Generate CI/CD pipelines"
echo "  /endor-api               - Direct API access"
echo "  /endor-demo              - Try without an account"
echo
echo "Installed components:"
echo "  - Skills (slash commands for security workflows)"
echo "  - Rules (advisory security guidance)"
if [ "$SKIP_HOOKS" = false ]; then
    echo "  - Hooks (route to Endor Labs skills at the right moments)"
fi
echo
echo "Next steps:"
echo "1. Set ENDOR_NAMESPACE in .claude/settings.json (or export ENDOR_NAMESPACE=your-namespace)"
echo "2. Restart Claude Code to load the MCP server, skills, and hooks"
echo "3. Run /endor-setup if you need help with authentication"
echo
echo "Try it: /endor-scan"
