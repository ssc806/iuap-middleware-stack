#!/usr/bin/env bash

set -euo pipefail

require_var() {
    local name=$1
    if [[ -z "${!name:-}" ]]; then
        echo "missing required environment variable: $name" >&2
        exit 1
    fi
}

to_unix_path() {
    cygpath -u "$1"
}

for required_var in \
    BUILD_ROOT \
    COMPONENT \
    COMPONENT_VERSION \
    SOURCE_URL \
    SOURCE_ARCHIVE_NAME \
    SOURCE_DIR_NAME \
    COMPONENT_CONFIG \
    PATCH_DIR \
    ARTIFACT_UPLOAD_PATH \
    PACKAGE_FILE_NAME \
    PACKAGE_FILE_PATH
do
    require_var "$required_var"
done

build_root=$(to_unix_path "$BUILD_ROOT")
source_archive_path="$build_root/$SOURCE_ARCHIVE_NAME"
source_dir="$build_root/$SOURCE_DIR_NAME"
config_file=$(to_unix_path "$COMPONENT_CONFIG")
patch_dir=$(to_unix_path "$PATCH_DIR")
artifact_dir=$(to_unix_path "$ARTIFACT_UPLOAD_PATH")
package_path=$(to_unix_path "$PACKAGE_FILE_PATH")

mkdir -p "$build_root" "$artifact_dir"

if [[ ! -f "$source_archive_path" ]]; then
    curl -fL "$SOURCE_URL" -o "$source_archive_path"
fi

rm -rf "$source_dir"
tar -xzf "$source_archive_path" -C "$build_root"

if [[ ! -d "$source_dir" ]]; then
    echo "source directory was not created after extracting $SOURCE_ARCHIVE_NAME" >&2
    exit 1
fi

shopt -s nullglob
local_patches=("$patch_dir"/*.patch)
shopt -u nullglob

if (( ${#local_patches[@]} > 0 )); then
    for patch_file in "${local_patches[@]}"; do
        patch -d "$source_dir" -p1 < "$patch_file"
    done
fi

cd "$source_dir"
./util/build-win32.sh

package_with_upstream() {
    local upstream_output

    [[ -x util/package-win32.sh ]] || return 1
    [[ -f /c/Strawberry/perl/bin/pl2bat.bat ]] || return 1

    upstream_output=$(./util/package-win32.sh | tail -n 1 | tr -d '\r')
    [[ -n "$upstream_output" && -f "$upstream_output" ]] || return 1

    rm -f "$package_path"
    mv -f "$upstream_output" "$package_path"
}

package_fallback() {
    local package_basename stage_root copied
    local entries

    package_basename=${PACKAGE_FILE_NAME%.zip}
    stage_root="$build_root/package/$package_basename"
    copied=0
    entries=(
        COPYRIGHT
        conf
        html
        include
        logs
        lua
        lua51.dll
        lualib
        luajit.exe
        nginx.exe
        pod
        resty
        restydoc
        restydoc-index
    )

    rm -rf "$stage_root"
    mkdir -p "$stage_root"

    for entry in "${entries[@]}"; do
        if [[ -e "$entry" ]]; then
            cp -R "$entry" "$stage_root/"
            copied=1
        fi
    done

    if [[ -f README-windows.txt ]]; then
        cp README-windows.txt "$stage_root/README.txt"
    fi

    if (( copied == 0 )); then
        echo "fallback packaging found no installable files in $source_dir" >&2
        return 1
    fi

    (
        cd "$(dirname "$stage_root")"
        rm -f "$PACKAGE_FILE_NAME"
        zip -r "$PACKAGE_FILE_NAME" "$(basename "$stage_root")"
    )

    rm -f "$package_path"
    mv -f "$(dirname "$stage_root")/$PACKAGE_FILE_NAME" "$package_path"
}

if ! package_with_upstream; then
    package_fallback
fi

package_sha256=$(sha256sum "$package_path" | awk '{print $1}')
metadata_path="$artifact_dir/build-metadata.txt"

cat > "$metadata_path" <<EOF
component=$COMPONENT
version=$COMPONENT_VERSION
source_url=$SOURCE_URL
source_archive=$SOURCE_ARCHIVE_NAME
source_dir=$SOURCE_DIR_NAME
config_path=$config_file
package=$PACKAGE_FILE_NAME
package_sha256=$package_sha256
runner=${RUNNER_OS:-Windows}
toolchain=MSYS2 MINGW64
built_at_utc=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
workflow=${GITHUB_WORKFLOW:-}
run_id=${GITHUB_RUN_ID:-}
run_attempt=${GITHUB_RUN_ATTEMPT:-}
local_patch_count=${#local_patches[@]}
EOF
