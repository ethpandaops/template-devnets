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
# Older pips trust the compromised eMudhra CAs: upgrade them from a hash-pinned wheel before fetching anything else.
pip_version=$(python -m pip --version | cut -d' ' -f2)
if [ "$(printf '%s\n' 26.2.2 "$pip_version" | sort -V | head -n1)" != 26.2.2 ]; then
  python -m pip install "pip @ https://files.pythonhosted.org/packages/3f/06/3e4420302363fbb71be3c7f35ce042f54bfca330e3e66b3a2e3c4cca579f/pip-26.2.2-py3-none-any.whl#sha256=fd7f4dfa8190e014013b9f08f3e973f4e4c26ffd179a204895533a7254813a70"
fi
python -m pip install -r requirements.txt

# Create asdf shims for the executables pip just installed (ansible-lint, ansible-playbook, ...).
asdf reshim python
