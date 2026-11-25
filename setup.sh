#!/bin/bash -xe

# asdf (.tool-versions) and uv (pyproject.toml) both resolve from the repo root.
cd "$(dirname "$0")"

# Uninstall previous asdf plugins that shouldn't be managed anymore under asdf
asdf uninstall ansible || true
asdf uninstall ansible-lint || true

# Plugin list
asdf plugin add age https://github.com/threkk/asdf-age.git || true
asdf plugin add shellcheck https://github.com/luizm/asdf-shellcheck.git || true
asdf plugin add sops https://github.com/feniix/asdf-sops.git || true
asdf plugin add terraform https://github.com/asdf-community/asdf-hashicorp.git || true
asdf plugin add helm https://github.com/Antiarchitect/asdf-helm.git || true
asdf plugin add uv https://github.com/asdf-community/asdf-uv.git || true
asdf plugin add yq https://github.com/sudermanjr/asdf-yq.git || true
asdf plugin add awscli || true

asdf install
asdf reshim

# Ensure asdf shims (uv) are on PATH — this script runs under bash,
# which does not source the shell rc where asdf shims are normally added.
export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"

# Python + tools (ansible, ansible-lint, ...) into .venv, exactly as pinned in uv.lock.
# uv fetches the interpreter from .python-version itself; no asdf python needed.
uv sync --locked
