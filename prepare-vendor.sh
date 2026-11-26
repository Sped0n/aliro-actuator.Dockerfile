#!/bin/sh
set -eu

revision=e8db11cabcfe589993dbe6f2d0e288d75abe233b
root=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

case "${1:-}" in
    --download) source_dir= ;;
    '')
        printf 'Usage: %s --download | /path/to/aliro-th-additions\n' "$0" >&2
        exit 2
        ;;
    *) source_dir=$1 ;;
esac

stage_file() (
    name=$1
    destination=$2
    checksum=$3
    if [ -e "$destination" ]; then
        printf '%s  %s\n' "$checksum" "$destination" | sha256sum -c -
        return
    fi

    temporary=$(mktemp "${destination}.XXXXXX")
    trap 'rm -f -- "$temporary"' EXIT
    trap 'exit 1' HUP INT TERM
    if [ -n "$source_dir" ]; then
        cp -- "$source_dir/$name" "$temporary"
    else
        curl --fail --silent --show-error --location \
            "https://raw.githubusercontent.com/NXP/aliro-th-additions/$revision/$name" \
            --output "$temporary"
    fi
    printf '%s  %s\n' "$checksum" "$temporary" | sha256sum -c -
    mv -- "$temporary" "$destination"
)

wheel=ucitool-2.0.4-py3-none-any.whl
firmware=ALIRO_IOT_SR150_FW_v46.43.14.bin
mkdir -p "$root/vendor"
stage_file "$wheel" "$root/vendor/$wheel" \
    ff64a741b743b382341896668ed2f08a73298ef958bc869bbd1b67f40c7c2453
stage_file "$firmware" "$root/vendor/$firmware" \
    02d8dcb8a8fc584d502e6dabf87ed2318d1940d4df54fef46297fd9009ad2d93
