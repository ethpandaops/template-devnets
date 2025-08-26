#!/bin/sh

ansible-galaxy install -r requirements.yaml --force

# Install Mitogen for Ansible performance optimization
# Following official installation instructions from https://mitogen.networkgenomics.com/ansible_detailed.html
MITOGEN_VERSION="0.3.27"

MITOGEN_DIR="vendor/mitogen-${MITOGEN_VERSION}"
MITOGEN_URL="https://files.pythonhosted.org/packages/source/m/mitogen/mitogen-${MITOGEN_VERSION}.tar.gz"

echo "Installing Mitogen v${MITOGEN_VERSION} from official PyPI source..."

# Create vendor directory if it doesn't exist
mkdir -p vendor

# Remove old Mitogen installation if it exists
if [ -d "${MITOGEN_DIR}" ]; then
    echo "Removing existing Mitogen installation..."
    rm -rf "${MITOGEN_DIR}"
fi

# Download and extract Mitogen from official PyPI source
if command -v wget >/dev/null 2>&1; then
    wget -q -O - "${MITOGEN_URL}" | tar -xz -C vendor
elif command -v curl >/dev/null 2>&1; then
    curl -sL "${MITOGEN_URL}" | tar -xz -C vendor
else
    echo "Error: Neither wget nor curl is available. Please install one of them."
    exit 1
fi

if [ -d "${MITOGEN_DIR}/ansible_mitogen" ]; then
    echo "Mitogen ${MITOGEN_VERSION} installed successfully in ${MITOGEN_DIR}"
    echo "Ansible configuration has been updated to use this installation."
else
    echo "Error: Mitogen installation failed"
    exit 1
fi