{ mkDerivationStage2
, stage1, static-gnumake, static-binutils, static-gnugcc4-c }:

let
  source-tarball-musl = builtins.fetchurl {
    # local = /downloads/musl-1.2.2.tar.gz;
    url = "http://musl.libc.org/releases/musl-1.2.2.tar.gz";
    sha256 = "9b969322012d796dc23dda27a35866034fa67d8fb67e0e2c45c913c3d43219dd";
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
      # configure:
        ash ./configure --prefix=$out
      # build:
        make -j $NPROC
      # install:
        make -j $NPROC install
    '';
  }
