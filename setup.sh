#!/bin/bash -xe

# Check if asdf is installed
if ! command -v asdf &> /dev/null; then
    echo "asdf not found. It is required to manage tool versions."

    # Check if Go is installed
    if ! command -v go &> /dev/null; then
        echo "Go is not installed. Go is required to install asdf."
        echo "Please install Go first: https://golang.org/doc/install"
        exit 1
    fi

    echo ""
    echo "Would you like to install asdf using Go? (y/n)"
    read -r response

    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "Installing asdf v0.18.0 via Go..."
        go install github.com/asdf-vm/asdf/cmd/asdf@v0.18.0

        # Add Go bin to PATH for current session if not already there
        export PATH="$HOME/go/bin:$PATH"

        # Check if asdf is now available
        if command -v asdf &> /dev/null; then
            echo "asdf installed successfully!"
            echo ""
            echo "Add the following to your shell configuration file (.bashrc, .zshrc, etc.):"
            echo "  export PATH=\"\$HOME/go/bin:\$PATH\""
        else
            echo "Failed to install asdf. Please install it manually."
            exit 1
        fi
    else
        echo "Aborting. Please install asdf manually:"
        echo "  go install github.com/asdf-vm/asdf/cmd/asdf@v0.18.0"
        echo "Or visit: https://asdf-vm.com/guide/getting-started.html"
        exit 1
    fi
fi

# Uninstall previous asdf plugins that shouldn't be managed anymore under asdf
asdf uninstall ansible || true
asdf uninstall ansible-lint || true

# Plugin list
asdf plugin add age https://github.com/threkk/asdf-age.git || true
asdf plugin add shellcheck https://github.com/luizm/asdf-shellcheck.git || true
asdf plugin add sops https://github.com/feniix/asdf-sops.git || true
asdf plugin add terraform https://github.com/asdf-community/asdf-hashicorp.git || true
asdf plugin-add helm https://github.com/Antiarchitect/asdf-helm.git || true
asdf plugin-add python || true
asdf plugin-add yq https://github.com/sudermanjr/asdf-yq.git || true
asdf plugin add awscli || true

asdf install
asdf reshim

# Check if uv is installed
if ! command -v uv &> /dev/null; then
    echo "uv not found. It is required to manage Python dependencies."
    echo ""
    echo "Would you like to install uv automatically? (y/n)"
    read -r response

    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "Installing uv..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
        # Add uv to PATH for current session
        export PATH="$HOME/.cargo/bin:$PATH"
        echo "uv installed successfully!"
    else
        echo "Aborting. Please install uv manually:"
        echo "  curl -LsSf https://astral.sh/uv/install.sh | sh"
        echo "Or visit: https://github.com/astral-sh/uv"
        exit 1
    fi
fi

# Create virtual environment with uv
echo "Creating virtual environment with uv..."
uv venv .venv

# Install Python dependencies with uv (doesn't require activation)
echo "Installing Python dependencies with uv..."
uv pip sync pyproject.toml

echo "Setup complete! Run:"
echo "source .venv/bin/activate"
