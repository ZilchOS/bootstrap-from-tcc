#!/store/1-stage1/protobusybox/bin/ash

#> FETCH 6075ad30f1ac0e15f07c1bf062c1e1268c241d674f11bd32cdf0e040c71f2bf3
#>  FROM https://github.com/llvm/llvm-project/releases/download/llvmorg-13.0.0/llvm-project-13.0.0.src.tar.xz

set -uex

export PATH='/store/1-stage1/protobusybox/bin/'
export PATH="$PATH:/store/2a0-static-gnumake/wrappers"
export PATH="$PATH:/store/2a7-cmake/bin"
export PATH="$PATH:/store/2a8-python/bin"
# 2a9-intermediate-clang intentionally not added to $PATH to prevent confusion

export SHELL=/store/1-stage1/protobusybox/bin/ash
LINUX_HEADERS_INCLUDES="/store/2a6-linux-headers/include"
PREV_CLANG=/store/2a9-intermediate-clang

mkdir -p /tmp/2b1-clang; cd /tmp/2b1-clang
# clang's cmake configuration should pick up ccache automatically from PATH
#if [ -e /ccache/setup ]; then . /ccache/setup; fi
export PATH="$PATH:/ccache/bin"
command -v ccache && USE_CCACHE=YES || USE_CCACHE=NO

echo "### $0: preparing future sysroot..."
OUT=/store/2b1-clang
SYSROOT=$OUT/sysroot
mkdir -p $SYSROOT/lib $SYSROOT/include
ln -s /store/2b0-musl/lib/* $SYSROOT/lib/
ln -s /store/2b0-musl/include/* $SYSROOT/include/

echo "### $0: unpacking LLVM/Clang sources..."
tar --strip-components=1 -xf /downloads/llvm-project-13.0.0.src.tar.xz

echo "### $0: fixing up LLVM/Clang sources..."
sed -i "s|COMMAND sh|COMMAND $SHELL|" \
	llvm/cmake/modules/GetHostTriple.cmake clang/CMakeLists.txt
echo 'echo x86_64-unknown-linux-musl' > llvm/cmake/config.guess
LOADER=/store/2b0-musl/lib/libc.so
sed -i "s|/lib/ld-musl-\" + ArchName + \".so.1|$LOADER|" \
	clang/lib/Driver/ToolChains/Linux.cpp
BEGINEND='const bool HasCRTBeginEndFiles'
sed -i "s|${BEGINEND} =|${BEGINEND} = false; ${BEGINEND}_unused =|" \
	clang/lib/Driver/ToolChains/Gnu.cpp
REL_ORIGIN='_install_rpath \"\$ORIGIN/../lib${LLVM_LIBDIR_SUFFIX}\"'
sed -i "s|_install_rpath \"\\\\\$ORIGIN/..|_install_rpath \"$OUT|" \
	llvm/cmake/modules/AddLLVM.cmake
sed -i 's|intrinsics_gen|intrinsics_gen\n  ClangDriverOptions|' \
	clang/lib/Interpreter/CMakeLists.txt

echo "### $0: building LLVM/Clang..."
export LD_LIBRARY_PATH="/store/2b0-musl/lib:$PREV_CLANG/lib"
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/tmp/2b1-clang/build/lib" # libLLVM

C_INCLUDES="$SYSROOT/include"
C_INCLUDES="$C_INCLUDES:$LINUX_HEADERS_INCLUDES"

EXTRA_INCL='/tmp/2b1-clang/extra_includes'
mkdir -p $EXTRA_INCL
cp clang/lib/Headers/*mmintrin.h $EXTRA_INCL/
cp clang/lib/Headers/mm_malloc.h $EXTRA_INCL/

export VERBOSE=1
OPTS=''
add_opt() {
	OPTS="$OPTS -D$1"
}
add_opt CMAKE_BUILD_TYPE=Release
add_opt LLVM_OPTIMIZED_TABLEGEN=YES
add_opt LLVM_CCACHE_BUILD=$USE_CCACHE
add_opt DEFAULT_SYSROOT=$SYSROOT
add_opt C_INCLUDE_DIRS=$C_INCLUDES
add_opt CMAKE_INSTALL_PREFIX=$OUT
add_opt LLVM_INSTALL_BINUTILS_SYMLINKS=YES
add_opt LLVM_INSTALL_CCTOOLS_SYMLINKS=YES
add_opt CMAKE_INSTALL_DO_STRIP=YES
add_opt LLVM_TARGET_ARCH=X86
add_opt LLVM_TARGETS_TO_BUILD=Native
add_opt LLVM_DEFAULT_TARGET_TRIPLE=x86_64-unknown-linux-musl
add_opt LLVM_HOST_TRIPLE=x86_64-unknown-linux-musl
add_opt COMPILER_RT_DEFAULT_TARGET_TRIPLE=x86_64-unknown-linux-musl
add_opt LLVM_APPEND_VC_REV=NO
add_opt LLVM_INCLUDE_TESTS=NO
add_opt LLVM_INCLUDE_EXAMPLES=NO
add_opt LLVM_INCLUDE_BENCHMARKS=NO
add_opt LLVM_ENABLE_BACKTRACES=NO
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
add_opt LIBCXXABI_USE_COMPILER_RT=YES
add_opt LIBCXXABI_USE_LLVM_UNWINDER=YES
add_opt LLVM_INSTALL_TOOLCHAIN_ONLY=YES
add_opt LIBUNWIND_USE_COMPILER_RT=YES

cmake -S llvm -B build -G 'Unix Makefiles' \
	-DCMAKE_ASM_COMPILER=$PREV_CLANG/bin/clang \
	-DCMAKE_C_COMPILER=$PREV_CLANG/bin/clang \
	-DCMAKE_CXX_COMPILER=$PREV_CLANG/bin/clang++ \
	-DLLVM_ENABLE_PROJECTS='clang;lld' \
	-DLLVM_ENABLE_RUNTIMES='compiler-rt;libcxx;libcxxabi;libunwind' \
	-DCMAKE_C_FLAGS="--sysroot=$SYSROOT" \
	-DCMAKE_CXX_FLAGS="--sysroot=$SYSROOT -I$EXTRA_INCL -D_LARGEFILE64_SOURCE" \
	-DCMAKE_C_LINK_FLAGS="-Wl,--dynamic-linker=$LOADER" \
	-DCMAKE_CXX_LINK_FLAGS="-Wl,--dynamic-linker=$LOADER" \
	-DLLVM_BUILD_LLVM_DYLIB=YES \
	-DLLVM_LINK_LLVM_DYLIB=YES \
	-DCLANG_LINK_LLVM_DYLIB=YES \
	$OPTS
        # TODO: remove _LARGEFILE64_SOURCE stopgap on update

	#-DLLVM_ENABLE_LTO=Thin \

make -C build -j $NPROC clang  # runs OK in parallel
make -C build runtimes-configure  # sometimes explodes when run in parallel =(
make -C build -j $NPROC runtimes  # continue in parallel again

echo "### $0: installing LLVM/Clang..."
make -C build install/strip  # again, serial because flaky
ln -s $OUT/lib/x86_64-unknown-linux-musl/* $OUT/lib/

echo "### $0: setting up generic names..."
ln -s $OUT/bin/clang $OUT/bin/cc
ln -s $OUT/bin/clang++ $OUT/bin/c++
ln -s $OUT/bin/clang-cpp $OUT/bin/cpp
ln -s $OUT/bin/lld $OUT/bin/ld

echo "### $0: mixing new stuff into sysroot..."
ln -s $OUT/lib/* $OUT/sysroot/lib/
