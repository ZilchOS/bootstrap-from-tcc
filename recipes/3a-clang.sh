#!/store/2b4-busybox/bin/ash

#> FETCH 6075ad30f1ac0e15f07c1bf062c1e1268c241d674f11bd32cdf0e040c71f2bf3
#>  FROM https://github.com/llvm/llvm-project/releases/download/llvmorg-13.0.0/llvm-project-13.0.0.src.tar.xz

set -uex

export PATH='/store/2b4-busybox/bin'
export PATH="$PATH:/store/2b1-gnugcc10/bin"
export PATH="$PATH:/store/2b2-binutils/bin"
export PATH="$PATH:/store/2b5-gnumake/wrappers"
export PATH="$PATH:/store/3a-cmake/bin"
export PATH="$PATH:/store/3a-python/bin"
export PATH="$PATH:/store/_2a0-ccache/bin"

export SHELL=/store/2b4-busybox/bin/ash

mkdir -p /tmp/3a-clang; cd /tmp/3a-clang
# clang's cmake configuration should pick up ccache automatically from PATH
#if [ -e /store/_2a0-ccache ]; then . /store/_2a0-ccache/wrap-available; fi
command -v ccache && USE_CCACHE=YES || USE_CCACHE=NO

echo "### $0: unpacking LLVM/Clang sources..."
tar --strip-components=1 -xf /downloads/llvm-project-13.0.0.src.tar.xz

echo "### $0: fixing up LLVM/Clang sources..."
sed -i "s|COMMAND sh|COMMAND $SHELL|" \
	llvm/cmake/modules/GetHostTriple.cmake clang/CMakeLists.txt
echo 'echo x86_64-unknown-linux-musl' > llvm/cmake/config.guess
sed -i 's|/lib/ld-musl-" + ArchName + ".so.1|/store/2b0-musl/lib/libc.so|' \
	clang/lib/Driver/ToolChains/Linux.cpp

echo "### $0: building LLVM/Clang..."
export VERBOSE=1
export LD_LIBRARY_PATH='/store/2b1-gnugcc10/lib'
export LD_LIBRARY_PATH="/store/3a-python/lib:$LD_LIBRARY_PATH"
GCC_PATH=/store/2b1-gnugcc10
cmake -S llvm -B build -G 'Unix Makefiles' \
	-DCMAKE_BUILD_TYPE=MinSizeRel \
	-DC_INCLUDE_DIRS=/store/2b0-musl/include \
	-DDEFAULT_SYSROOT=/store/2b0-musl \
	-DGCC_INSTALL_PREFIX=$GCC_PATH \
	-DLLVM_ENABLE_PROJECTS='clang;lld;compiler-rt' \
	-DCMAKE_C_FLAGS=-I/store/2b3-linux-headers/include \
	-DCMAKE_CXX_FLAGS=-I/store/2b3-linux-headers/include \
	-DCLANG_DEFAULT_LINKER=lld \
	-DLLVM_TARGET_ARCH=X86 \
	-DLLVM_TARGETS_TO_BUILD=X86 \
	-DLLVM_DEFAULT_TARGET_TRIPLE=x86_64-linux-musl \
	-DLLVM_APPEND_VC_REV=NO \
	-DLLVM_INCLUDE_TESTS=NO \
	-DLLVM_INCLUDE_EXAMPLES=NO \
	-DLLVM_INCLUDE_BENCHMARKS=NO \
	-DLLVM_ENABLE_BACKTRACES=NO \
	-DCOMPILER_RT_BUILD_SANITIZERS=NO \
	-DCLANG_ENABLE_ARCMT=NO \
	-DCLANG_ENABLE_STATIC_ANALYZER=NO \
	-DCMAKE_INSTALL_PREFIX=/store/3a-clang \
	-DLLVM_INSTALL_BINUTILS_SYMLINKS=YES \
	-DLLVM_INSTALL_CCTOOLS_SYMLINKS=YES \
	-DLLVM_UTILS_INSTALL_DIR=utils \
	-DLLVM_CCACHE_BUILD=$USE_CCACHE \
	-DCOMPILER_RT_BUILD_SANITIZERS=NO \
	-DCOMPILER_RT_BUILD_XRAY=NO \
	-DCOMPILER_RT_BUILD_LIBFUZZER=NO \
	-DCOMPILER_RT_BUILD_PROFILE=NO \
	-DCOMPILER_RT_BUILD_MEMPROF=NO \
	-DCOMPILER_RT_BUILD_ORC=NO \
	-DCMAKE_CXX_LINK_FLAGS="-Wl,-rpath,$GCC_PATH/lib -L$GCC_PATH/lib" \
	-DCOMPILER_RT_USE_BUILTINS_LIBRARY=YES \
	-DCLANG_DEFAULT_RTLIB=compiler-rt \
	-DCLANG_CONFIG_FILE_SYSTEM_DIR=/store/3a-clang/cfg \
	-DLIBCXX_HAS_MUSL_LIBC=YES

	#-DLLVM_ENABLE_RUNTIMES='compiler-rt' \
	#-DLLVM_BUILD_RUNTIME=NO \
	#-DBUILD_SHARED_LIBS=YES \
	#-DLLVM_ENABLE_UNWIND_TABLES=NO \
	#-DLLVM_ENABLE_WARNINGS=NO \
	#-DLLVM_ENABLE_PEDANTIC=NO \
	#-DLLVM_POLLY_BUILD=NO \
	#-DLLVM_INCLUDE_DOCS=NO \
	#-DLLVM_ENABLE_OCAMLDOC=NO \
	#-DLLVM_ENABLE_BINDINGS=NO \
	#-DLLVM_INSTALL_UTILS=NO \
	#-DCMAKE_BUILD_TYPE=Release \
	#-DCOMPILER_RT_USE_BUILTINS_LIBRARY=YES \
	#-DCMAKE_CXX_LINK_FLAGS="-Wl,-rpath,$GCC_PATH/lib -L$GCC_PATH/lib/" \
	#-DLLVM_ENABLE_PROJECTS="clang;compiler-rt" \
	#-DCLANG_DEFAULT_CXX_STDLIB=libc++ \
	#-DCLANG_DEFAULT_UNWINDLIB=libunwind \
	#-DLLVM_DEFAULT_LINKER=lld \
	#-DLLVM_ENABLE_LLD=YES \
	#-DLLVM_ENABLE_ZLIB=YES \
	#-DLLVM_ENABLE_PROJECTS="clang;libcxx;libcxxabi" \
	#-DLLVM_ENABLE_LIBCXX=YES \
	#-DCLANG_ENABLE_BOOTSTRAP=NO \
	#--sysroot=/store/2a3-intermediate-musl \
	#--target=x86_64-linux-musl \
make -j $NPROC -C build
unset LD_LIBRARY_PATH

echo "### $0: installing LLVM/Clang..."
make -j $NPROC install/strip -C build
mkdir /store/3a-clang/bin/generic-names
ln -s /store/3a-clang/bin/clang /store/3a-clang/bin/generic-names/cc
ln -s /store/3a-clang/bin/clang++ /store/3a-clang/bin/generic-names/c++
ln -s /store/3a-clang/bin/clang-cpp /store/3a-clang/bin/generic-names/cpp

mkdir /store/3a-clang/cfg
echo '-Wl,-dynamic-linker > /store/2b0-musl/lib/libc.so' \
	> /store/3a-clang/cfg/x86_64.cfg
