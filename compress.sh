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

# Formulate File Names
TOOLS_ARCHIVE="llvm-tools-${LLVM_VERSION}-${OS_NAME}-${ARCH}.${EXT}"
RUNTIME_ARCHIVE="llvm-runtime-${LLVM_VERSION}-${OS_NAME}-${ARCH}.${EXT}"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "tools_archive_name=${TOOLS_ARCHIVE}" >> "$GITHUB_OUTPUT"
  echo "runtime_archive_name=${RUNTIME_ARCHIVE}" >> "$GITHUB_OUTPUT"
fi

# Compress the tools directory
echo "=== Compressing Tools ==="
if [ -d "tools" ]; then
  cd tools
  if [[ "$OS_NAME" == "windows" ]]; then
    7z a "../${TOOLS_ARCHIVE}" ./*
  else
    tar -czvf "../${TOOLS_ARCHIVE}" ./*
  fi
  cd ..
else
  echo "Error: tools directory not found!"
  exit 1
fi

# Compress the runtime directory
echo "=== Compressing Runtime ==="
if [ -d "runtime" ]; then
  cd runtime
  if [[ "$OS_NAME" == "windows" ]]; then
    7z a "../${RUNTIME_ARCHIVE}" ./*
  else
    tar -czvf "../${RUNTIME_ARCHIVE}" ./*
  fi
  cd ..
else
  echo "Error: runtime directory not found!"
  exit 1
fi

echo "=== Compression Complete ==="
ls -lh "$TOOLS_ARCHIVE" "$RUNTIME_ARCHIVE"
