#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
	printf 'usage: %s <ipxe-source> <embed-script> <output-dir>\n' "$0" >&2
	exit 2
fi

source_dir=$1
embed_script=$2
output_dir=$3

mkdir -p "$output_dir"
cd "$source_dir"

# iPXE does not track a changed EMBED path in every target dependency graph.
rm -f bin-x86_64-efi/embedded.o bin-x86_64-efi/snponly.efi
rm -f bin/embedded.o bin/undionly.kpxe

make -j"${JOBS:-4}" bin-x86_64-efi/snponly.efi EMBED="$embed_script"
make -j"${JOBS:-4}" bin/undionly.kpxe EMBED="$embed_script"

install -m 0644 bin-x86_64-efi/snponly.efi "$output_dir/ipxe.efi"
install -m 0644 bin/undionly.kpxe "$output_dir/undionly.kpxe"

sha256sum "$output_dir/ipxe.efi" "$output_dir/undionly.kpxe"
