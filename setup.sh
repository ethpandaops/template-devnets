#!/bin/bash -xe

# Uninstall previous asdf plugins that shouldn't be managed anymore under asdf
asdf uninstall ansible || true
asdf uninstall ansible-lint || true

# Plugin list
asdf plugin add age https://github.com/threkk/asdf-age.git || true
asdf plugin add shellcheck https://github.com/luizm/asdf-shellcheck.git || true
asdf plugin add sops https://github.com/feniix/asdf-sops.git || true
asdf plugin add terraform https://github.com/asdf-community/asdf-hashicorp.git || true
asdf plugin add helm https://github.com/Antiarchitect/asdf-helm.git || true
asdf plugin add python || true
asdf plugin add yq https://github.com/sudermanjr/asdf-yq.git || true
asdf plugin add awscli || true

asdf install
asdf reshim

# Ensure asdf shims (python/pip) are on PATH — this script runs under bash,
# which does not source the shell rc where asdf shims are normally added.
export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"

# Install python tools
python -m pip install -r requirements.txt

# Regenerate shims so pip-installed console scripts (ansible-lint, ansible,
# molecule) resolve on PATH in subsequent steps.
asdf reshim python
