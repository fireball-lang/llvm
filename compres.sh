#!/bin/bash
set -e # Exit immediately if a command fails

# Detect OS
OS_NAME=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

if [[ "$OS_NAME" == *"mingw"* ]] || [[ "$OS_NAME" == *"msys"* ]] || [[ "$OS_NAME" == *"cygwin"* ]]; then
  OS_NAME="windows"
elif [[ "$OS_NAME" == "darwin" ]]; then
  OS_NAME="macos"
elif [[ "$OS_NAME" == "linux" ]]; then
  OS_NAME="linux"
fi

# Standardize Architecture names
if [[ "$ARCH" == "x86_64" ]] || [[ "$ARCH" == "amd64" ]]; then
  ARCH="amd64"
elif [[ "$ARCH" == "arm64" ]] || [[ "$ARCH" == "aarch64" ]]; then
  ARCH="aarch64"
fi

# Set Extension based on OS
if [[ "$OS_NAME" == "windows" ]]; then
  EXT="zip"
else
  EXT="tar.gz"
fi

# Formulate File Name
ARCHIVE_NAME="llvm-tools-${LLVM_VERSION}-${OS_NAME}-${ARCH}.${EXT}"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "archive_name=${ARCHIVE_NAME}" >> "$GITHUB_OUTPUT"
fi

# Compress the tools directory
cd tools
if [[ "$OS_NAME" == "windows" ]]; then
  7z a "../${ARCHIVE_NAME}" ./*
else
  tar -czvf "../${ARCHIVE_NAME}" ./*
fi
