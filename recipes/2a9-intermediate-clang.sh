#!/store/1-stage1/protobusybox/bin/ash

#> FETCH 60493f4e974fcca7b739aea4901af2d957b0eaea34b42815359be59cf6c88fa2
#>  FROM https://github.com/llvm/llvm-project/releases/download/llvmorg-17.0.0-rc3/llvm-project-17.0.0rc3.src.tar.xz

set -uex

export PATH='/store/1-stage1/protobusybox/bin/'
export PATH="$PATH:/store/2a0-static-gnumake/wrappers"
export PATH="$PATH:/store/2a1-static-binutils/bin"
export PATH="$PATH:/store/2a5-gnugcc10/bin"
export PATH="$PATH:/store/2a7-cmake/bin"
export PATH="$PATH:/store/2a8-python/bin"

export SHELL=/store/1-stage1/protobusybox/bin/ash
LINUX_HEADERS_INCLUDES="/store/2a6-linux-headers/include"
GCC_PATH=/store/2a5-gnugcc10

mkdir -p /tmp/2a9-intermediate-clang; cd /tmp/2a9-intermediate-clang
# clang's cmake configuration should pick up ccache automatically from PATH
#if [ -e /ccache/setup ]; then . /ccache/setup; fi
export PATH="$PATH:/ccache/bin"
command -v ccache && USE_CCACHE=YES || USE_CCACHE=NO

echo "### $0: preparing future sysroot..."
OUT=/store/2a9-intermediate-clang
SYSROOT=$OUT/sysroot
mkdir -p $SYSROOT/lib $SYSROOT/include
ln -s /store/2a3-intermediate-musl/lib/* $SYSROOT/lib/
ln -s /store/2a3-intermediate-musl/include/* $SYSROOT/include/

echo "### $0: unpacking LLVM/Clang sources..."
tar --strip-components=1 -xf /downloads/llvm-project-17.0.0rc3.src.tar.xz

echo "### $0: fixing up LLVM/Clang sources..."
sed -i "s|COMMAND sh|COMMAND $SHELL|" \
	llvm/cmake/modules/GetHostTriple.cmake clang/CMakeLists.txt
echo 'echo x86_64-unknown-linux-musl' > llvm/cmake/config.guess
LOADER=/store/2a3-intermediate-musl/lib/libc.so
sed -i "s|/lib/ld-musl-\" + ArchName + \".so.1|$LOADER|" \
	clang/lib/Driver/ToolChains/Linux.cpp
BEGINEND='const bool HasCRTBeginEndFiles'
sed -i "s|${BEGINEND} =|${BEGINEND} = false; ${BEGINEND}_unused =|" \
	clang/lib/Driver/ToolChains/Gnu.cpp
REL_ORIGIN='_install_rpath \"\$ORIGIN/../lib${LLVM_LIBDIR_SUFFIX}\"'
sed -i "s|_install_rpath \"\\\\\$ORIGIN/..|_install_rpath \"$OUT|" \
	llvm/cmake/modules/AddLLVM.cmake

echo "### $0: building LLVM/Clang (stage 1)..."
export LD_LIBRARY_PATH='/store/2a5-gnugcc10/lib'
#export LD_LIBRARY_PATH="/store/2a8-python/lib:$LD_LIBRARY_PATH"

C_INCLUDES="$SYSROOT/include"
C_INCLUDES="$C_INCLUDES:$LINUX_HEADERS_INCLUDES"

EXTRA_INCL='/tmp/2a9-intermediate-clang/extra_includes'
mkdir -p $EXTRA_INCL
cp clang/lib/Headers/*intrin*.h $EXTRA_INCL/
cp clang/lib/Headers/mm_malloc.h $EXTRA_INCL/
[ -e $EXTRA_INCL/immintrin.h ]

BOTH_STAGES_OPTS=''
add_opt() {
	BOTH_STAGES_OPTS="$BOTH_STAGES_OPTS -D$1 -DBOOTSTRAP_$1"
}
add_opt CMAKE_BUILD_TYPE=MinSizeRel
add_opt LLVM_OPTIMIZED_TABLEGEN=YES
add_opt LLVM_CCACHE_BUILD=$USE_CCACHE
add_opt DEFAULT_SYSROOT=$SYSROOT
add_opt C_INCLUDE_DIRS=$C_INCLUDES
add_opt CMAKE_INSTALL_PREFIX=$OUT
add_opt LLVM_INSTALL_BINUTILS_SYMLINKS=YES
add_opt LLVM_INSTALL_CCTOOLS_SYMLINKS=YES
add_opt CMAKE_INSTALL_DO_STRIP=YES
add_opt LLVM_ENABLE_PER_TARGET_RUNTIME_DIR=YES
add_opt LLVM_TARGET_ARCH=X86
add_opt LLVM_TARGETS_TO_BUILD=Native
add_opt LLVM_BUILTIN_TARGETS=x86_64-unknown-linux-musl
add_opt LLVM_DEFAULT_TARGET_TRIPLE=x86_64-unknown-linux-musl
add_opt LLVM_HOST_TRIPLE=x86_64-unknown-linux-musl
add_opt COMPILER_RT_DEFAULT_TARGET_TRIPLE=x86_64-unknown-linux-musl
add_opt LLVM_APPEND_VC_REV=NO
add_opt LLVM_INCLUDE_TESTS=NO
add_opt LLVM_INCLUDE_EXAMPLES=NO
add_opt LLVM_INCLUDE_BENCHMARKS=NO
add_opt LLVM_ENABLE_BACKTRACES=NO
add_opt LLVM_ENABLE_EH=YES
add_opt LLVM_ENABLE_RTTI=YES
add_opt CLANG_ENABLE_ARCMT=NO
add_opt CLANG_ENABLE_STATIC_ANALYZER=NO
add_opt COMPILER_RT_BUILD_SANITIZERS=NO
add_opt COMPILER_RT_BUILD_XRAY=NO
add_opt COMPILER_RT_BUILD_LIBFUZZER=NO
add_opt COMPILER_RT_BUILD_PROFILE=NO
add_opt COMPILER_RT_BUILD_MEMPROF=NO
add_opt COMPILER_RT_BUILD_ORC=NO
add_opt COMPILER_RT_USE_BUILTINS_LIBRARY=YES
add_opt CLANG_DEFAULT_CXX_STDLIB=libc++
add_opt CLANG_DEFAULT_LINKER=lld
add_opt CLANG_DEFAULT_RTLIB=compiler-rt
add_opt LIBCXX_HAS_MUSL_LIBC=YES
add_opt LIBCXX_USE_COMPILER_RT=YES
add_opt LIBCXX_INCLUDE_BENCHMARKS=NO
add_opt LIBCXX_CXX_ABI=libcxxabi
add_opt LIBCXXABI_USE_COMPILER_RT=YES
add_opt LIBCXXABI_USE_LLVM_UNWINDER=YES
add_opt LLVM_INSTALL_TOOLCHAIN_ONLY=YES
add_opt LIBUNWIND_USE_COMPILER_RT=YES

cmake -S llvm -B build -G 'Unix Makefiles' \
	-DLLVM_ENABLE_PROJECTS='clang;lld' \
	-DLLVM_ENABLE_RUNTIMES='compiler-rt;libcxx;libcxxabi;libunwind' \
	-DGCC_INSTALL_PREFIX=$GCC_PATH \
	-DCMAKE_C_FLAGS=--sysroot=$SYSROOT \
	"-DBOOTSTRAP_CMAKE_C_FLAGS=-isystem $EXTRA_INCL" \
	"-DBOOTSTRAP_CMAKE_CXX_FLAGS=-isystem $EXTRA_INCL" \
	-DCLANG_ENABLE_BOOTSTRAP=YES $BOTH_STAGES_OPTS

make -C build -j $NPROC clang lld runtimes

echo "### $0: building LLVM/Clang (stage 2)..."
NEW_LIB_DIR="$(pwd)/build/lib/x86_64-unknown-linux-musl"
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$NEW_LIB_DIR"
make -C build -j $NPROC stage2

echo "### $0: installing LLVM/Clang..."
make -C build -j $NPROC stage2-install
ln -s $OUT/lib/x86_64-unknown-linux-musl/* $OUT/lib/

echo "### $0: setting up generic names..."
mkdir $OUT/bin/generic-names
ln -s $OUT/bin/clang $OUT/bin/generic-names/cc
ln -s $OUT/bin/clang++ $OUT/bin/generic-names/c++
ln -s $OUT/bin/clang-cpp $OUT/bin/generic-names/cpp

echo "### $0: mixing new stuff into sysroot..."
ln -s $OUT/lib/* $OUT/sysroot/lib/
