{ fetchurl, mkDerivationStage2
, stage1, static-gnumake, static-binutils, static-gnugcc4-c }:

let
  source-tarball-musl = fetchurl {
    # local = /downloads/musl-1.2.4.tar.gz;
    url = "http://musl.libc.org/releases/musl-1.2.4.tar.gz";
    sha256 = "7a35eae33d5372a7c0da1188de798726f68825513b7ae3ebe97aaaa52114f039";
  };
in
  mkDerivationStage2 {
    name = "bootstrap-2a3-intermediate-musl";
    buildInputPaths = [
      "${stage1.protobusybox}/bin"
      "${static-gnumake}/bin"
      "${static-binutils}/bin"
      "${static-gnugcc4-c}/bin"
    ];
    script = ''
        mkdir build-dir; cd build-dir
      # unpack:
        unpack ${source-tarball-musl}
      # fixup:
        sed -i 's|/bin/sh|${stage1.protobusybox}/bin/ash|' \
                tools/*.sh \
        # patch popen/system to search in PATH instead of hardcoding /bin/sh
        sed -i 's|posix_spawn(&pid, "/bin/sh",|posix_spawnp(\&pid, "sh",|' \
                src/stdio/popen.c src/process/system.c
        sed -i 's|execl("/bin/sh", "sh", "-c",|execlp("sh", "-c",|'\
                src/misc/wordexp.c
        # eliminate a source path reference
        sed -i 's/__FILE__/"__FILE__"/' include/assert.h
      # configure:
        ash ./configure --prefix=$out
      # build:
        make -j $NPROC
      # install:
        make -j $NPROC install
      # check for build path leaks:
        ( ! grep -rF $(pwd) $out )
    '';
  }
