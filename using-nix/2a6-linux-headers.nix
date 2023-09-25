{ fetchurl, mkDerivationStage2, stage1, static-gnumake, static-binutils, gnugcc10 }:

let
  source-tarball-linux = fetchurl {
    # local = /downloads/linux-6.4.12.tar.xz;
    url = "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.4.12.tar.xz";
    sha256 = "cca91be956fe081f8f6da72034cded96fe35a50be4bfb7e103e354aa2159a674";
  };
in
  mkDerivationStage2 {
    name = "bootstrap-2a6-linux-headers";
    buildInputPaths = [
      "${stage1.protobusybox}/bin"
      "${static-gnumake}/bin"
      "${static-binutils}/bin"
      "${gnugcc10}/bin"
    ];
    script = ''
      # unpack:
        mkdir build-dir; cd build-dir
        unpack ${source-tarball-linux} \
          linux-6.4.12/Makefile \
          linux-6.4.12/arch/x86 \
          linux-6.4.12/include \
          linux-6.4.12/scripts \
          linux-6.4.12/tools
      # build:
        make -j $NPROC \
                CONFIG_SHELL=${stage1.protobusybox}/bin/ash \
                CC=gcc HOSTCC=gcc ARCH=x86_64 \
                headers
      # install:
        find usr/include -name '.*' | xargs rm
        mkdir -p $out
        cp -rv usr/include $out/
      # check for build path leaks:
        ( ! grep -rF $(pwd) $out )
    '';
  }
