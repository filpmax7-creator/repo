#!/usr/bin/env bash
# Fails if the arm64e slices in a .deb carry unsigned Objective-C class
# metadata. iOS 17's libobjc authenticates class_ro pointers while it
# registers classes, so an unsigned image crashes SpringBoard at load time
# (before any %ctor runs). Builds made with Apple's Xcode toolchain pass;
# builds made with the on-device Procursus clang did not.
#
# Usage: check-ptrauth.sh path/to/package.deb
set -euo pipefail

deb="${1:?usage: check-ptrauth.sh package.deb}"
deb="$(cd "$(dirname "$deb")" && pwd)/$(basename "$deb")"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

(cd "$work" && ar x "$deb")
mkdir "$work/data"
tar -xf "$work"/data.tar.* -C "$work/data"

status=0
checked=0
while IFS= read -r -d '' bin; do
    lipo -archs "$bin" 2>/dev/null | grep -qw arm64e || continue
    otool -arch arm64e -l "$bin" | grep -q 'sectname __objc_classlist' || continue
    checked=$((checked + 1))
    name="${bin#"$work/data/"}"

    fixups="$(dyld_info -arch arm64e -fixups "$bin" | grep '__objc_data' || true)"
    plain_rebase="$(grep -cE '[[:space:]]rebase[[:space:]]' <<<"$fixups" || true)"
    auth_rebase="$(grep -c 'auth-rebase' <<<"$fixups" || true)"

    flags_hex="$( { otool -arch arm64e -s __DATA_CONST __objc_imageinfo "$bin" || true; \
                    otool -arch arm64e -s __DATA __objc_imageinfo "$bin" || true; } 2>/dev/null \
                 | awk '/^[0-9a-f]+\t/{print $NF; exit}' || true)"
    signed_ro=$(( (16#${flags_hex:-0} & 0x10) != 0 ))

    if [[ "$plain_rebase" -eq 0 && "$auth_rebase" -gt 0 && "$signed_ro" -eq 1 ]]; then
        echo "OK   $name (auth-rebase=$auth_rebase, imageinfo flags=0x$flags_hex)"
    else
        echo "FAIL $name (plain rebase=$plain_rebase, auth-rebase=$auth_rebase, imageinfo flags=0x${flags_hex:-?}; SignedClassRO bit 0x10 must be set)"
        status=1
    fi
done < <(find "$work/data" -type f -print0)

if [[ "$checked" -eq 0 ]]; then
    echo "FAIL no arm64e binaries with Objective-C classes found in $deb"
    exit 1
fi
exit "$status"
