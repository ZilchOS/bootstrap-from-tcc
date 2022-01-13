{ tcc-seed, protosrc, recipesStage1ExtrasPath, stage1cPath }:

derivation {
  name = "bootstrap-1-stage1";
  builder = "/bin/sh";  # purely to pass $vars, which is silly
  args = [ "-c" ''
    ${tcc-seed} \
      -nostdinc -nostdlib -Werror \
      -I${recipesStage1ExtrasPath} \
      -DINSIDE_NIX \
      -DPROTOSRC='"'${protosrc}'"' \
      -DTCC_SEED='"'${tcc-seed}'"' \
      -DRECIPES_STAGE1='"'${recipesStage1ExtrasPath}'"' \
      -DTMP_STAGE1='"'$TMPDIR/tmp'"' \
      -DSTORE_PROTOBUSYBOX='"'$protobusybox/'"' \
      -DSTORE_PROTOMUSL='"'$protomusl'"' \
      -DSTORE_TINYCC='"'$tinycc'"' \
      -run ${stage1cPath}
  ''];
  outputs = [ "protobusybox" "protomusl" "tinycc" ];
  allowedReferences = [ "protobusybox" "protomusl" "tinycc" ];
  allowedRequisites = [ "protobusybox" "protomusl" "tinycc" ];
  system = "x86_64-linux";
  __contentAddressed = true;
  outputHashAlgo = "sha256"; outputHashMode = "recursive";
}
