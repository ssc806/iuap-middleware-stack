#!/usr/bin/env bash

set -euo pipefail

readonly NGINX_MODULE_VTS_VERSION="0.2.2"
readonly NGINX_MODULE_VTS_TAG="v${NGINX_MODULE_VTS_VERSION}"
readonly NGINX_UPSTREAM_CHECK_VERSION="0.4.0"
readonly NGINX_UPSTREAM_CHECK_TAG="v${NGINX_UPSTREAM_CHECK_VERSION}"
readonly LUA_RESTY_HTTP_VERSION="0.17.2"
readonly LUA_RESTY_HTTP_TAG="v${LUA_RESTY_HTTP_VERSION}"

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

extract_upstream_var() {
    local script_path=$1
    local key=$2

    awk -F= -v key="$key" '
        $1 == key {
            gsub(/[[:space:]]/, "", $2)
            print $2
            exit
        }
    ' "$script_path"
}

is_valid_targz() {
    local archive_path=$1
    tar -tzf "$archive_path" >/dev/null 2>&1
}

download_targz() {
    local archive_path=$1
    shift

    local tmp_path
    tmp_path="${archive_path}.tmp"

    rm -f "$tmp_path"

    for url in "$@"; do
        if curl -fL "$url" -o "$tmp_path" && is_valid_targz "$tmp_path"; then
            mv -f "$tmp_path" "$archive_path"
            return 0
        fi

        rm -f "$tmp_path"
    done

    echo "failed to download a valid tar.gz archive for $archive_path" >&2
    return 1
}

ensure_targz() {
    local archive_path=$1
    shift

    if [[ -f "$archive_path" ]] && is_valid_targz "$archive_path"; then
        return 0
    fi

    rm -f "$archive_path"
    download_targz "$archive_path" "$@"
}

extract_tarball_to_named_dir() {
    local archive_path=$1
    local parent_dir=$2
    local expected_dir=$3

    local tmp_extract extracted_entries extracted_dir

    tmp_extract="${parent_dir}/.${expected_dir}.extract"

    rm -rf "$tmp_extract" "${parent_dir}/${expected_dir}"
    mkdir -p "$tmp_extract"
    tar -xzf "$archive_path" -C "$tmp_extract"

    shopt -s nullglob dotglob
    extracted_entries=("$tmp_extract"/*)
    shopt -u nullglob dotglob

    if (( ${#extracted_entries[@]} != 1 )) || [[ ! -d "${extracted_entries[0]}" ]]; then
        echo "expected a single top-level directory in $archive_path" >&2
        return 1
    fi

    extracted_dir="${extracted_entries[0]}"
    mv "$extracted_dir" "${parent_dir}/${expected_dir}"
    rmdir "$tmp_extract"
}

ensure_extracted_module() {
    local archive_path=$1
    local expected_dir=$2
    local parent_dir=$3
    shift 3

    ensure_targz "$archive_path" "$@"
    extract_tarball_to_named_dir "$archive_path" "$parent_dir" "$expected_dir"
}

find_single_directory() {
    local pattern=$1
    local matches

    shopt -s nullglob
    matches=($pattern)
    shopt -u nullglob

    if (( ${#matches[@]} != 1 )); then
        echo "expected a single directory for pattern: $pattern" >&2
        return 1
    fi

    printf '%s\n' "${matches[0]}"
}

apply_local_patches() {
    local source_dir=$1
    local patch_dir=$2
    local -n patch_ref=$3

    shopt -s nullglob
    patch_ref=("$patch_dir"/*.patch)
    shopt -u nullglob

    if (( ${#patch_ref[@]} == 0 )); then
        return 0
    fi

    for patch_file in "${patch_ref[@]}"; do
        patch -d "$source_dir" -p1 < "$patch_file"
    done
}

apply_upstream_check_patch() {
    local nginx_source_dir=$1
    local module_dir=$2
    local patch_path="${module_dir}/check_1.20.1+.patch"

    if [[ ! -f "$patch_path" ]]; then
        echo "missing upstream check patch: $patch_path" >&2
        return 1
    fi

    if rg -q "check_index" "$nginx_source_dir/src/http/ngx_http_upstream_round_robin.h"; then
        return 0
    fi

    patch -p1 -d "$nginx_source_dir" < "$patch_path"
}

stage_lua_resty_http() {
    local module_dir=$1
    local target_dir=$2

    mkdir -p "${target_dir}/resty"
    cp -f "${module_dir}/lib/resty/http.lua" "${target_dir}/resty/"
    cp -f "${module_dir}/lib/resty/http_connect.lua" "${target_dir}/resty/"
    cp -f "${module_dir}/lib/resty/http_headers.lua" "${target_dir}/resty/"
}

run_configure() {
    local jobs=$1
    local pcre_dir=$2
    local zlib_dir=$3
    local openssl_dir=$4
    local luajit_lib_dir=$5

    ./configure \
        --with-cc='gcc -fdiagnostics-color=always' \
        --prefix= \
        --sbin-path=nginx.exe \
        --with-pcre-jit \
        --without-http_rds_json_module \
        --without-http_rds_csv_module \
        --without-lua_rds_parser \
        --with-ipv6 \
        --with-stream \
        --with-stream_ssl_module \
        --with-stream_ssl_preread_module \
        --with-http_v2_module \
        --without-mail_pop3_module \
        --without-mail_imap_module \
        --without-mail_smtp_module \
        --with-http_stub_status_module \
        --with-http_realip_module \
        --with-http_addition_module \
        --with-http_auth_request_module \
        --with-http_secure_link_module \
        --with-http_random_index_module \
        --with-http_gzip_static_module \
        --with-http_sub_module \
        --with-http_dav_module \
        --with-http_flv_module \
        --with-http_mp4_module \
        --with-http_gunzip_module \
        --with-select_module \
        --with-http_slice_module \
        --with-compat \
        --with-http_image_filter_module \
        --with-cc-opt='-DFD_SETSIZE=1024 -m64' \
        --with-ld-opt="-Wl,-rpath,${luajit_lib_dir}" \
        --with-luajit-xcflags='-DLUAJIT_NUMMODE=2 -DLUAJIT_ENABLE_LUA52COMPAT' \
        --with-pcre="$pcre_dir" \
        --with-zlib="$zlib_dir" \
        --with-openssl="$openssl_dir" \
        --add-module="objs/nginx-module-vts-${NGINX_MODULE_VTS_VERSION}" \
        --add-module="objs/nginx_upstream_check_module-${NGINX_UPSTREAM_CHECK_VERSION}" \
        -j"$jobs"
}

package_with_upstream() {
    local package_path=$1
    local upstream_output

    [[ -x util/package-win32.sh ]] || return 1
    [[ -f /c/Strawberry/perl/bin/pl2bat.bat ]] || return 1

    if ! upstream_output=$(./util/package-win32.sh | tail -n 1 | tr -d '\r'); then
        return 1
    fi

    [[ -n "$upstream_output" && -f "$upstream_output" ]] || return 1

    rm -f "$package_path"
    mv -f "$upstream_output" "$package_path"
}

package_fallback() {
    local build_root=$1
    local package_file_name=$2
    local package_path=$3
    local package_basename stage_root copied
    local entries

    package_basename=${package_file_name%.zip}
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
        nginx
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
        echo "fallback packaging found no installable files in $(pwd)" >&2
        return 1
    fi

    (
        cd "$(dirname "$stage_root")"
        rm -f "$package_file_name"
        zip -r "$package_file_name" "$(basename "$stage_root")"
    )

    rm -f "$package_path"
    mv -f "$(dirname "$stage_root")/$package_file_name" "$package_path"
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

ensure_targz "$source_archive_path" "$SOURCE_URL"

rm -rf "$source_dir"
tar -xzf "$source_archive_path" -C "$build_root"

if [[ ! -d "$source_dir" ]]; then
    echo "source directory was not created after extracting $SOURCE_ARCHIVE_NAME" >&2
    exit 1
fi

declare -a local_patches=()
apply_local_patches "$source_dir" "$patch_dir" local_patches

build_script_path="$source_dir/util/build-win32.sh"
openssl_version=$(extract_upstream_var "$build_script_path" "OPENSSL")
zlib_version=$(extract_upstream_var "$build_script_path" "ZLIB")
pcre_version=$(extract_upstream_var "$build_script_path" "PCRE")
jobs=$(extract_upstream_var "$build_script_path" "JOBS")

ensure_targz "$build_root/${openssl_version}.tar.gz" \
    "https://github.com/openssl/openssl/releases/download/${openssl_version}/${openssl_version}.tar.gz"

ensure_targz "$build_root/${zlib_version}.tar.gz" \
    "https://www.zlib.net/fossils/${zlib_version}.tar.gz" \
    "https://zlib.net/fossils/${zlib_version}.tar.gz"

ensure_targz "$build_root/${pcre_version}.tar.gz" \
    "https://github.com/PCRE2Project/pcre2/releases/download/${pcre_version}/${pcre_version}.tar.gz"

vts_archive="$build_root/nginx-module-vts-${NGINX_MODULE_VTS_VERSION}.tar.gz"
upstream_check_archive="$build_root/nginx_upstream_check_module-${NGINX_UPSTREAM_CHECK_VERSION}.tar.gz"
lua_resty_http_archive="$build_root/lua-resty-http-${LUA_RESTY_HTTP_VERSION}.tar.gz"

cd "$source_dir"
rm -rf objs
mkdir -p objs/lib

ensure_extracted_module \
    "$vts_archive" \
    "nginx-module-vts-${NGINX_MODULE_VTS_VERSION}" \
    "$source_dir/objs" \
    "https://github.com/vozlt/nginx-module-vts/archive/refs/tags/${NGINX_MODULE_VTS_TAG}.tar.gz"

ensure_extracted_module \
    "$upstream_check_archive" \
    "nginx_upstream_check_module-${NGINX_UPSTREAM_CHECK_VERSION}" \
    "$source_dir/objs" \
    "https://github.com/yaoweibin/nginx_upstream_check_module/archive/refs/tags/${NGINX_UPSTREAM_CHECK_TAG}.tar.gz"

ensure_extracted_module \
    "$lua_resty_http_archive" \
    "lua-resty-http-${LUA_RESTY_HTTP_VERSION}" \
    "$source_dir/objs" \
    "https://github.com/ledgetech/lua-resty-http/archive/refs/tags/${LUA_RESTY_HTTP_TAG}.tar.gz"

(
    cd objs/lib
    tar -xzf "../../../${openssl_version}.tar.gz"
    tar -xzf "../../../${zlib_version}.tar.gz"
    tar -xzf "../../../${pcre_version}.tar.gz"
)

(
    cd "objs/lib/${openssl_version}"
    patch -p1 < "../../../patches/${openssl_version}-sess_set_get_cb_yield.patch"
)

nginx_source_dir=$(find_single_directory "$source_dir/bundle/nginx-*")
apply_upstream_check_patch "$nginx_source_dir" "$source_dir/objs/nginx_upstream_check_module-${NGINX_UPSTREAM_CHECK_VERSION}"
stage_lua_resty_http "$source_dir/objs/lua-resty-http-${LUA_RESTY_HTTP_VERSION}" "$source_dir/lualib"

luajit_lib_dir="$source_dir/build/luajit-root/luajit/lib"

run_configure \
    "$jobs" \
    "objs/lib/${pcre_version}" \
    "objs/lib/${zlib_version}" \
    "objs/lib/${openssl_version}" \
    "$luajit_lib_dir"

make -j"$jobs"
make install

stage_lua_resty_http "$source_dir/objs/lua-resty-http-${LUA_RESTY_HTTP_VERSION}" "$source_dir/lualib"

if ! package_with_upstream "$package_path"; then
    package_fallback "$build_root" "$PACKAGE_FILE_NAME" "$package_path"
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
