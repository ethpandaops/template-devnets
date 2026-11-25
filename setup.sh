#!/bin/bash -xe

# The only step that installs anything. Re-run it after pulling changes to
# .python-version, uv.lock or ansible/requirements.yaml (.envrc warns you).
cd "$(dirname "$0")"

# Binary tools, pinned in .tool-versions.
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

# Put asdf's pinned uv ahead of any other uv on PATH — this script runs under bash,
# which does not source the shell rc where asdf shims are normally added.
export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"

# Python, ansible-core, mitogen, ... into .venv, exactly as pinned and hash-checked in uv.lock.
uv sync --locked

# Roles/collections into ansible/vendor, exactly as pinned in requirements.yaml.
# Rebuilt from scratch so nothing stale survives.
rm -rf ansible/vendor
(cd ansible && ../.venv/bin/ansible-galaxy install -r requirements.yaml)

# Record what was installed; .envrc compares against it on every cd.
cat .python-version uv.lock ansible/requirements.yaml > .venv/.setup-inputs

# Trust this checkout's .envrc (you just ran its setup.sh); later edits to it still need `direnv allow`.
if command -v direnv >/dev/null; then direnv allow .; fi
