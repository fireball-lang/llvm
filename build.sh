#!/bin/bash
set -e # Exit immediately if a command fails

# --- Configuration ---
LLVM_VERSION="${LLVM_VERSION}"
TOOLS_DIR="$(pwd)/tools"

mkdir -p "$TOOLS_DIR"

echo "=== Cloning LLVM ($LLVM_VERSION) ==="
if [ ! -d "llvm-project" ]; then
    git clone --depth 1 --branch "llvmorg-$LLVM_VERSION" https://github.com/llvm/llvm-project.git
fi

cd llvm-project
mkdir -p build && cd build

# Detect OS and Architecture
OS=$(uname -s)
ARCH=$(uname -m)
echo "=== Detected OS: $OS, ARCH: $ARCH ==="

# Determine the single LLVM backend to build
if [[ "$ARCH" == "x86_64" ]] || [[ "$ARCH" == "amd64" ]]; then
    LLVM_TARGET="X86"
elif [[ "$ARCH" == "arm64" ]] || [[ "$ARCH" == "aarch64" ]]; then
    LLVM_TARGET="AArch64"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

# Base CMake flags for ALL platforms
CMAKE_FLAGS=(
    "-G" "Ninja"
    "-DCMAKE_BUILD_TYPE=Release"
    "-DLLVM_ENABLE_ASSERTIONS=OFF"

    # Projects and targets to build
    "-DLLVM_ENABLE_PROJECTS=lld"
    "-DLLVM_TARGETS_TO_BUILD=$LLVM_TARGET"

    # Disable external dependencies
    "-DLLVM_ENABLE_ZLIB=OFF"
    "-DLLVM_ENABLE_ZSTD=OFF"
    "-DLLVM_ENABLE_LIBXML2=OFF"
    "-DCMAKE_DISABLE_FIND_PACKAGE_LibXml2=TRUE"
    "-DLLVM_ENABLE_CURL=OFF"
    "-DLLVM_ENABLE_TERMINFO=OFF"

    # Disable unnecessary components
    "-DLLVM_INCLUDE_TESTS=OFF"
    "-DLLVM_BUILD_TESTS=OFF"
    "-DLLVM_INCLUDE_EXAMPLES=OFF"
    "-DLLVM_INCLUDE_BENCHMARKS=OFF"
    "-DLLVM_INCLUDE_DOCS=OFF"
    "-DLLVM_ENABLE_DOXYGEN=OFF"
    "-DLLVM_INCLUDE_UTILS=OFF"
    "-DLLVM_ENABLE_BINDINGS=OFF"
    "-DLLVM_ENABLE_WARNINGS=OFF"
)

if [[ "$OS" == "Linux" ]]; then
    echo "=== Configuring for Linux ==="
    CMAKE_FLAGS+=(
        "-DLLVM_BUILD_LLVM_DYLIB=ON"
        "-DLLVM_LINK_LLVM_DYLIB=ON"
        "-DCMAKE_BUILD_WITH_INSTALL_RPATH=ON"
        '-DCMAKE_INSTALL_RPATH=$ORIGIN'
    )
    LIB_EXT="so"
    EXE_EXT=""

elif [[ "$OS" == "Darwin" ]]; then
    echo "=== Configuring for macOS ==="
    CMAKE_FLAGS+=(
        "-DLLVM_BUILD_LLVM_DYLIB=ON"
        "-DLLVM_LINK_LLVM_DYLIB=ON"
        "-DCMAKE_BUILD_WITH_INSTALL_RPATH=ON"
        "-DCMAKE_INSTALL_RPATH=@executable_path"
    )
    LIB_EXT="dylib"
    EXE_EXT=""

elif [[ "$OS" == *"MINGW"* ]] || [[ "$OS" == *"MSYS"* ]] || [[ "$OS" == *"CYGWIN"* ]]; then
    echo "=== Configuring for Windows ==="
    # MSVC static fallback. No RPATH needed.
    CMAKE_FLAGS+=()
    LIB_EXT="dll"
    EXE_EXT=".exe"
else
    echo "Unsupported OS: $OS"
    exit 1
fi

# Build tools
echo "=== Running CMake ==="
cmake ../llvm "${CMAKE_FLAGS[@]}"

echo "=== Building tools ==="
ninja llc llvm-as lld

echo "=== Extracting tools to $TOOLS_DIR ==="
cp -P bin/llc${EXE_EXT} "$TOOLS_DIR/"
cp -P bin/llvm-as${EXE_EXT} "$TOOLS_DIR/"
cp -P bin/ld.lld${EXE_EXT} bin/lld-link${EXE_EXT} bin/ld64.lld${EXE_EXT} bin/lld${EXE_EXT} "$TOOLS_DIR/"

# Copy the dynamic library (Linux and macOS only)
if [[ "$OS" == "Linux" || "$OS" == "Darwin" ]]; then
    cp -P lib/libLLVM*.$LIB_EXT* "$TOOLS_DIR/"

    echo "=== Stripping binaries ==="
    if [[ "$OS" == "Darwin" ]]; then
        # Safely fully-strip the executables
        strip -u -r "$TOOLS_DIR"/llc "$TOOLS_DIR"/llvm-as "$TOOLS_DIR"/lld

        # Partially strip the dynamic library so it doesn't break
        strip -x "$TOOLS_DIR"/libLLVM*.$LIB_EXT* || true
    else
        # Linux standard strip is fine for both
        strip "$TOOLS_DIR"/llc "$TOOLS_DIR"/llvm-as "$TOOLS_DIR"/lld
        strip "$TOOLS_DIR"/libLLVM*.$LIB_EXT* || true
    fi
fi

echo "=== Build Complete! ==="
ls -lh "$TOOLS_DIR"
