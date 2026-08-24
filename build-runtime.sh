#!/bin/bash
set -e # Exit immediately if a command fails

# --- Configuration ---
LLVM_VERSION="${LLVM_VERSION}"
RUNTIME_DIR="$(pwd)/runtime"

mkdir -p "$RUNTIME_DIR"

if [ ! -d "llvm-project" ]; then
    echo "Error: llvm-project directory not found."
    echo "Please run the tools build script first to clone the repository."
    exit 1
fi

cd llvm-project
mkdir build-runtime && cd build-runtime

# Detect OS and Architecture
OS=$(uname -s)
ARCH=$(uname -m)
echo "=== Detected OS: $OS, ARCH: $ARCH ==="

if [[ "$ARCH" == "x86_64" ]] || [[ "$ARCH" == "amd64" ]]; then
    ARCH_PREFIX="x86_64"
elif [[ "$ARCH" == "arm64" ]] || [[ "$ARCH" == "aarch64" ]]; then
    if [[ "$OS" == "Darwin" ]]; then
        ARCH_PREFIX="arm64"
    else
        ARCH_PREFIX="aarch64"
    fi
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

# Determine Target Triple
case "$OS" in
    Windows|*MINGW*|*MSYS*|*CYGWIN*)
        TARGET_TRIPLE="${ARCH_PREFIX}-pc-windows-gnu"
        ;;
    Linux)
        TARGET_TRIPLE="${ARCH_PREFIX}-pc-linux-gnu"
        ;;
    Darwin)
        TARGET_TRIPLE="${ARCH_PREFIX}-apple-darwin"
        ;;
    *)
        echo "Unsupported OS: $OS"
        exit 1
        ;;
esac

echo "=== Target Triple: $TARGET_TRIPLE ==="

# Base CMake flags for ALL platforms
CMAKE_FLAGS=(
    "-G" "Ninja"
    "-DCMAKE_BUILD_TYPE=Release"

    "-DLLVM_ENABLE_RUNTIMES=compiler-rt;libunwind"

    # Exact target triples
    "-DCMAKE_C_COMPILER_TARGET=$TARGET_TRIPLE"
    "-DCMAKE_CXX_COMPILER_TARGET=$TARGET_TRIPLE"
    "-DCMAKE_ASM_COMPILER_TARGET=$TARGET_TRIPLE"

    # Restrict compiler-rt to ONLY the target architecture (safely disables i386)
    "-DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON"

    "-DCOMPILER_RT_BUILD_BUILTINS=ON"
    "-DCOMPILER_RT_BUILD_SANITIZERS=OFF"
    "-DCOMPILER_RT_BUILD_XRAY=OFF"
    "-DCOMPILER_RT_BUILD_LIBFUZZER=OFF"
    "-DCOMPILER_RT_BUILD_PROFILE=OFF"
    "-DCOMPILER_RT_INCLUDE_TESTS=OFF"

    "-DLIBUNWIND_ENABLE_SHARED=OFF"
    "-DLIBUNWIND_ENABLE_STATIC=ON"
    "-DLIBUNWIND_INCLUDE_TESTS=OFF"
)

if [[ "$OS" == "Darwin" ]]; then
    echo "=== Configuring for macOS ==="
    CMAKE_FLAGS+=("-DCMAKE_OSX_ARCHITECTURES=$ARCH_PREFIX")
elif [[ "$OS" == "Linux" ]]; then
    echo "=== Configuring for Linux ==="
else
    echo "=== Configuring for Windows ==="
fi

echo "=== Running CMake ==="
cmake ../runtimes "${CMAKE_FLAGS[@]}"

echo "=== Building runtimes ==="
ninja

echo "=== Extracting runtimes to $RUNTIME_DIR ==="

# 1. Extract compiler-rt builtins
echo "Copying compiler-rt..."
find . -type f \( -name "*clang_rt.builtins*.a" -o -name "*clang_rt.builtins*.lib" \) | while read -r file; do
    echo " -> Found: $file"
    cp -P "$file" "$RUNTIME_DIR/"
done

# 2. Extract libunwind
echo "Copying libunwind..."
find . -type f \( -name "libunwind.a" -o -name "libunwind.lib" \) | while read -r file; do
    echo " -> Found: $file"
    cp -P "$file" "$RUNTIME_DIR/"
done

echo "=== Build Complete! ==="
ls -lh "$RUNTIME_DIR"
