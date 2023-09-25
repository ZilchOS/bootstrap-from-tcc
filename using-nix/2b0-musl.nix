{ fetchurl, mkDerivationStage2
, stage1, static-gnumake, intermediate-clang }:

let
  source-tarball-musl = fetchurl {
    # local = /downloads/musl-1.2.4.tar.gz;
    url = "http://musl.libc.org/releases/musl-1.2.4.tar.gz";
    sha256 = "7a35eae33d5372a7c0da1188de798726f68825513b7ae3ebe97aaaa52114f039";
  };
in
  mkDerivationStage2 {
    name = "bootstrap-2b0-musl";
    buildInputPaths = [
      "${stage1.protobusybox}/bin"
      "${static-gnumake}/bin"
      "${intermediate-clang}/bin"
      "${intermediate-clang}/bin/generic-names"
    ];
    script = ''
      # unpack:
        mkdir build-dir; cd build-dir
        unpack ${source-tarball-musl}
      # fixup:
        sed -i 's|/bin/sh|${stage1.protobusybox}/bin/ash|' tools/*.sh \
        # patch popen/system to search in PATH instead of hardcoding /bin/sh
        sed -i 's|posix_spawn(&pid, "/bin/sh",|posix_spawnp(\&pid, "sh",|' \
                src/stdio/popen.c src/process/system.c
        sed -i 's|execl("/bin/sh", "sh", "-c",|execlp("sh", "-c",|'\
                src/misc/wordexp.c
        # avoid absolute path references
        sed -i 's/__FILE__/__FILE_NAME__/' include/assert.h
      # configure:
        ash ./configure --prefix=$out CFLAGS=-O2
      # build:
        make -j $NPROC
      # install:
        make -j $NPROC install
        mkdir $out/bin
        ln -s $out/lib/libc.so $out/bin/ldd
      # check for build path leaks:
        ( ! grep -rF $(pwd) $out )
    '';
    extra.allowedRequisites = [ "out" ];
    extra.allowedReferences = [ "out" ];
  }
