#!/bin/sh

# this is optional, really just a stricter `nix-build default.nix -A default`,
# with the only difference being /bin/sh absence for stage2+
# you need to be a trusted user to modify sandbox-paths, shrinking included

# also, your nix needs experimental-options = ca-derivations

set -uex

# stage1 needs /bin/sh for silliest reasons ever: passing args
nix-build default.nix -A stage1.protomusl "$@"
nix-build default.nix -A stage1.protobusybox "$@"
nix-build default.nix -A stage1.tinycc "$@"

# rest should be buildable without /bin/sh as well, this ensures it
sudo env "NIX_CONFIG=sandbox-paths =" nix-build default.nix "$@"
