#!/bin/bash

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
BINARY_NAME="codext"

# Replace OWNER_PLACEHOLDER with your GitHub username (or org) before publishing.
REPO_OWNER="${REPO_OWNER:-sanchitmonga22}"
REPO_NAME="${REPO_NAME:-Codext}"
REPO_URL="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/main"

echo "🔂 Installing Codext (Codex, in a Loopt)..."

if [ "$REPO_OWNER" = "OWNER_PLACEHOLDER" ]; then
    echo -e "${RED}❌ This installer is not yet configured.${NC}" >&2
    echo "   Edit install.sh and set REPO_OWNER to your GitHub username/org," >&2
    echo "   or invoke with: REPO_OWNER=your-name bash install.sh" >&2
    exit 1
fi

mkdir -p "$INSTALL_DIR"

echo "📥 Downloading $BINARY_NAME..."
if ! curl -fsSL "$REPO_URL/codext.sh" -o "$INSTALL_DIR/$BINARY_NAME"; then
    echo -e "${RED}❌ Failed to download $BINARY_NAME${NC}" >&2
    exit 1
fi

chmod +x "$INSTALL_DIR/$BINARY_NAME"

echo -e "${GREEN}✅ $BINARY_NAME installed to $INSTALL_DIR/$BINARY_NAME${NC}"

if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo -e "${YELLOW}⚠️  Warning: $INSTALL_DIR is not in your PATH${NC}"
    echo ""
    echo "To add it to your PATH, add this line to your shell profile:"
    echo ""

    if [[ "$SHELL" == *"zsh"* ]]; then
        echo "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc"
        echo "  source ~/.zshrc"
    elif [[ "$SHELL" == *"bash"* ]]; then
        echo "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
        echo "  source ~/.bashrc"
    else
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
    echo ""
fi

echo ""
echo "🔍 Checking dependencies..."

missing_deps=()

if ! command -v codex &> /dev/null; then
    missing_deps+=("Codex CLI")
fi

if ! command -v gh &> /dev/null; then
    missing_deps+=("GitHub CLI")
fi

if ! command -v jq &> /dev/null; then
    missing_deps+=("jq")
fi

if [ ${#missing_deps[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ All dependencies installed${NC}"
else
    echo -e "${YELLOW}⚠️  Missing dependencies:${NC}"
    for dep in "${missing_deps[@]}"; do
        echo "   - $dep"
    done
    echo ""
    echo "Install them with:"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "  brew install gh jq"
        echo "  brew install --cask codex   # or follow https://github.com/openai/codex"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "  # Install GitHub CLI: https://github.com/cli/cli#installation"
        echo "  sudo apt-get install jq  # or equivalent for your distro"
        echo "  # Install Codex CLI: https://github.com/openai/codex"
    fi
fi

echo ""
echo -e "${GREEN}🎉 Installation complete!${NC}"
echo ""
echo "Get started with:"
echo "  $BINARY_NAME --prompt \"your task\" --max-runs 5 --owner YourGitHubUser --repo your-repo"
echo ""
echo "For more information, visit: https://github.com/${REPO_OWNER}/${REPO_NAME}"
