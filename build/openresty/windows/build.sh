#!/usr/bin/env bash

set -euo pipefail

# 安装必要的构建工具（如果尚未安装）
echo "Installing required packages..."
if command -v pacman &>/dev/null; then
    # 检查并安装必要的软件包
    for pkg in unzip tar make gcc patch curl wget; do
        if ! command -v "$pkg" &>/dev/null; then
            echo "Installing $pkg..."
            pacman -S --noconfirm "$pkg"
        fi
    done
else
    echo "Error: pacman not found. Please run this script in MSYS2 environment." >&2
    exit 1
fi


wget https://github.com/ssc806/iuap-middleware-stack/blob/guocaifeng-patch-1/build/openresty/windows/openresty-1.27.1.2.zip
unzip openresty-1.27.1.2.zip && cd openresty-1.27.1.2
bash -x 127-win32.sh


# #!/usr/bin/env bash
#
# set -euo pipefail
#
# # This is the full OpenResty/nginx configure argument list for Windows builds.
# # Edit, remove, or reorder entries here when you need to change the build.
# # Entries are written into the generated shell script as-is.
# configure_args=(
#     "--platform=msys"
#     "--with-cc=gcc"
#     "--prefix="
#     "--sbin-path=nginx.exe"
#     "--with-pcre-jit"
#     "--without-http_rds_json_module"
#     "--without-http_rds_csv_module"
#     "--without-lua_rds_parser"
#     "--with-ipv6"
#     "--with-stream"
#     "--with-stream_ssl_module"
#     "--with-stream_ssl_preread_module"
#     "--with-http_v2_module"
#     "--without-mail_pop3_module"
#     "--without-mail_imap_module"
#     "--without-mail_smtp_module"
#     "--with-http_stub_status_module"
#     "--with-http_realip_module"
#     "--with-http_addition_module"
#     "--with-http_auth_request_module"
#     "--with-http_secure_link_module"
#     "--with-http_random_index_module"
#     "--with-http_gzip_static_module"
#     "--with-http_sub_module"
#     "--with-http_dav_module"
#     "--with-http_flv_module"
#     "--with-http_mp4_module"
#     "--with-http_gunzip_module"
#     "--with-select_module"
#     "--with-http_slice_module"
#     "--with-compat"
#     "--with-http_image_filter_module"
#     '--with-cc="gcc -fdiagnostics-color=always"'
#     '--with-cc-opt="-DFD_SETSIZE=1024 -m64"'
#     '--with-ld-opt="-Wl,-rpath,$(pwd)/build/luajit-root/luajit/lib"'
#     '--with-luajit-xcflags="-DLUAJIT_NUMMODE=2 -DLUAJIT_ENABLE_LUA52COMPAT"'
#     '--with-pcre=objs/lib/$PCRE'
#     '--with-zlib=objs/lib/$ZLIB'
#     '--with-openssl=objs/lib/$OPENSSL'
#     '--add-module=objs/lib/nginx-module-vts-0.2.2'
#     '--add-module=objs/lib/nginx_upstream_check_module-0.4.0'
# )
#
# require_var() {
#     local name=$1
#     if [[ -z "${!name:-}" ]]; then
#         echo "missing required environment variable: $name" >&2
#         exit 1
#     fi
# }
#
# to_unix_path() {
#     cygpath -u "$1"
# }
#
# extract_upstream_var() {
#     local key=$1
#
#     awk -F= -v key="$key" '
#         $1 == key {
#             gsub(/[[:space:]]/, "", $2)
#             print $2
#             exit
#         }
#     ' util/build-win32.sh
# }
#
# is_valid_targz() {
#     local archive_path=$1
#     tar -tzf "$archive_path" >/dev/null 2>&1
# }
#
# download_targz() {
#     local archive_path=$1
#     shift
#
#     local tmp_path
#     tmp_path="${archive_path}.tmp"
#
#     rm -f "$tmp_path"
#
#     for url in "$@"; do
#         if curl -fL "$url" -o "$tmp_path" && is_valid_targz "$tmp_path"; then
#             mv -f "$tmp_path" "$archive_path"
#             return 0
#         fi
#
#         rm -f "$tmp_path"
#     done
#
#     echo "failed to download a valid tar.gz archive for $archive_path" >&2
#     return 1
# }
#
# ensure_targz() {
#     local archive_path=$1
#     shift
#
#     if [[ -f "$archive_path" ]] && is_valid_targz "$archive_path"; then
#         return 0
#     fi
#
#     rm -f "$archive_path"
#     download_targz "$archive_path" "$@"
# }
#
# replace_configure_invocation() {
#     local script_path=$1
#     local tmp_path=$2
#     local block_path configure_block arg
#
#     configure_block='./configure \'
#     configure_block+=$'\n'
#
#     for arg in "${configure_args[@]}"; do
#         configure_block+="    ${arg} \\"$'\n'
#     done
#
#     configure_block+='    -j$JOBS || exit 1'
#     configure_block+=$'\n'
#
#     block_path="${tmp_path}.block"
#     printf '%s' "$configure_block" > "$block_path"
#
#     if ! awk -v block_path="$block_path" '
#         function print_block(    line) {
#             while ((getline line < block_path) > 0) {
#                 print line
#             }
#             close(block_path)
#         }
#
#         $0 == "./configure \\" && replaced == 0 {
#             print_block()
#             replaced = 1
#             in_block = 1
#             next
#         }
#
#         in_block {
#             if ($0 ~ /-j\$JOBS \|\| exit 1$/) {
#                 in_block = 0
#             }
#             next
#         }
#
#         { print }
#
#         END {
#             if (replaced == 0 || in_block != 0) {
#                 exit 1
#             }
#         }
#     ' "$script_path" > "$tmp_path"; then
#         rm -f "$block_path"
#         return 1
#     fi
#
#     rm -f "$block_path"
# }
#
# for required_var in \
#     BUILD_ROOT \
#     COMPONENT \
#     COMPONENT_VERSION \
#     SOURCE_URL \
#     SOURCE_ARCHIVE_NAME \
#     SOURCE_DIR_NAME \
#     COMPONENT_CONFIG \
#     PATCH_DIR \
#     ARTIFACT_UPLOAD_PATH \
#     PACKAGE_FILE_NAME \
#     PACKAGE_FILE_PATH
# do
#     require_var "$required_var"
# done
#
# build_root=$(to_unix_path "$BUILD_ROOT")
# source_archive_path="$build_root/$SOURCE_ARCHIVE_NAME"
# source_dir="$build_root/$SOURCE_DIR_NAME"
# config_file=$(to_unix_path "$COMPONENT_CONFIG")
# patch_dir=$(to_unix_path "$PATCH_DIR")
# artifact_dir=$(to_unix_path "$ARTIFACT_UPLOAD_PATH")
# package_path=$(to_unix_path "$PACKAGE_FILE_PATH")
#
# mkdir -p "$build_root" "$artifact_dir"
#
# ensure_targz "$source_archive_path" "$SOURCE_URL"
#
# rm -rf "$source_dir"
# tar -xzf "$source_archive_path" -C "$build_root"
#
#
# if [[ ! -d "$source_dir" ]]; then
#     echo "source directory was not created after extracting $SOURCE_ARCHIVE_NAME" >&2
#     exit 1
# fi
#
# shopt -s nullglob
# local_patches=("$patch_dir"/*.patch)
# shopt -u nullglob
#
# if (( ${#local_patches[@]} > 0 )); then
#     for patch_file in "${local_patches[@]}"; do
#         patch -d "$source_dir" -p1 < "$patch_file"
#     done
# fi
#
# tmp_build_script="${source_dir}/util/build-win32.sh.tmp"
# replace_configure_invocation "$source_dir/util/build-win32.sh" "$tmp_build_script"
# mv -f "$tmp_build_script" "$source_dir/util/build-win32.sh"
#
# cd "$source_dir"
#
# openssl_version=$(extract_upstream_var OPENSSL)
# zlib_version=$(extract_upstream_var ZLIB)
# pcre_version=$(extract_upstream_var PCRE)
# # 定义额外模块版本
# nginx_module_vts="nginx-module-vts-0.2.2"
# nginx_module_check="nginx_upstream_check_module-0.4.0"
# lua_resty_http="lua-resty-http-0.17.2"
#
# ensure_targz "$build_root/${openssl_version}.tar.gz" \
#     "https://github.com/openssl/openssl/releases/download/${openssl_version}/${openssl_version}.tar.gz"
#
# ensure_targz "$build_root/${zlib_version}.tar.gz" \
#     "https://www.zlib.net/fossils/${zlib_version}.tar.gz" \
#     "https://zlib.net/fossils/${zlib_version}.tar.gz"
#
# ensure_targz "$build_root/${pcre_version}.tar.gz" \
#     "https://github.com/PCRE2Project/pcre2/releases/download/${pcre_version}/${pcre_version}.tar.gz"
#
# # 下载额外模块
# ensure_targz "$build_root/${nginx_module_vts}.tar.gz" \
#     "https://github.com/vozlt/nginx-module-vts/archive/v0.2.2.tar.gz"
#
# ensure_targz "$build_root/${nginx_module_check}.tar.gz" \
#     "https://github.com/yaoweibin/nginx_upstream_check_module/archive/v0.4.0.tar.gz"
#
# ensure_targz "$build_root/${lua_resty_http}.tar.gz" \
#     "https://github.com/ledgetech/lua-resty-http/archive/v0.17.2.tar.gz"
#
# # 解压额外模块
# tar -xzf "$build_root/${nginx_module_vts}.tar.gz" -C "$build_root"
# tar -xzf "$build_root/${nginx_module_check}.tar.gz" -C "$build_root"
# tar -xzf "$build_root/${lua_resty_http}.tar.gz" -C "$build_root"
#
# # 创建模块目录结构
# mkdir -p "$build_root/objs/lib"
#
# # 移动模块到正确位置
# # 查找并移动nginx-module-vts模块
# echo "Debug: Looking for nginx-module-vts in $build_root"
# for vts_dir in "$build_root"/nginx-module-vts-*; do
#   if [[ -d "$vts_dir" ]]; then
#     echo "Debug: Found vts_dir=$vts_dir"
#     if [[ -f "$vts_dir/config" ]]; then
#       echo "Debug: Found config in $vts_dir, copying to $build_root/objs/lib/nginx-module-vts-0.2.2"
#       cp -r "$vts_dir" "$build_root/objs/lib/nginx-module-vts-0.2.2"
#       break
#     else
#       # 可能存在嵌套目录结构，查找内部目录
#       for sub_dir in "$vts_dir"/*; do
#         if [[ -d "$sub_dir" && -f "$sub_dir/config" ]]; then
#           echo "Debug: Found config in sub_dir=$sub_dir, copying to $build_root/objs/lib/nginx-module-vts-0.2.2"
#           cp -r "$sub_dir" "$build_root/objs/lib/nginx-module-vts-0.2.2"
#           break
#         fi
#       done
#     fi
#   fi
# done
#
# # 查找并移动nginx_upstream_check_module模块
# echo "Debug: Looking for nginx_upstream_check_module in $build_root"
# for check_dir in "$build_root"/nginx_upstream_check_module-*; do
#   if [[ -d "$check_dir" ]]; then
#     echo "Debug: Found check_dir=$check_dir"
#     if [[ -f "$check_dir/config" ]]; then
#       echo "Debug: Found config in $check_dir, copying to $build_root/objs/lib/nginx_upstream_check_module-0.4.0"
#       cp -r "$check_dir" "$build_root/objs/lib/nginx_upstream_check_module-0.4.0"
#       break
#     else
#       # 可能存在嵌套目录结构，查找内部目录
#       for sub_dir in "$check_dir"/*; do
#         if [[ -d "$sub_dir" && -f "$sub_dir/config" ]]; then
#           echo "Debug: Found config in sub_dir=$sub_dir, copying to $build_root/objs/lib/nginx_upstream_check_module-0.4.0"
#           cp -r "$sub_dir" "$build_root/objs/lib/nginx_upstream_check_module-0.4.0"
#           break
#         fi
#       done
#     fi
#   fi
# done
#
# ./util/build-win32.sh
#
# # 复制lua-resty-http库到相应位置
# lua_resty_http="lua-resty-http-0.17.2"
# if [[ -d "$build_root/$lua_resty_http" ]]; then
#     mkdir -p "$source_dir/lualib/resty/"
#     cp -f "$build_root/$lua_resty_http/lib/resty/http.lua" "$source_dir/lualib/resty/" 2>/dev/null || true
#     cp -f "$build_root/$lua_resty_http/lib/resty/http_connect.lua" "$source_dir/lualib/resty/" 2>/dev/null || true
#     cp -f "$build_root/$lua_resty_http/lib/resty/http_headers.lua" "$source_dir/lualib/resty/" 2>/dev/null || true
# fi
#
# package_with_upstream() {
#     local upstream_output
#
#     [[ -x util/package-win32.sh ]] || return 1
#     [[ -f /c/Strawberry/perl/bin/pl2bat.bat ]] || return 1
#
#     upstream_output=$(./util/package-win32.sh | tail -n 1 | tr -d '\r')
#     [[ -n "$upstream_output" && -f "$upstream_output" ]] || return 1
#
#     rm -f "$package_path"
#     mv -f "$upstream_output" "$package_path"
# }
#
# package_fallback() {
#     local package_basename stage_root copied
#     local entries
#
#     package_basename=${PACKAGE_FILE_NAME%.zip}
#     stage_root="$build_root/package/$package_basename"
#     copied=0
#     entries=(
#         COPYRIGHT
#         conf
#         html
#         include
#         logs
#         lua
#         lua51.dll
#         lualib
#         luajit.exe
#         nginx.exe
#         pod
#         resty
#         restydoc
#         restydoc-index
#     )
#
#     rm -rf "$stage_root"
#     mkdir -p "$stage_root"
#
#     for entry in "${entries[@]}"; do
#         if [[ -e "$entry" ]]; then
#             cp -R "$entry" "$stage_root/"
#             copied=1
#         fi
#     done
#
#     if [[ -f README-windows.txt ]]; then
#         cp README-windows.txt "$stage_root/README.txt"
#     fi
#
#     if (( copied == 0 )); then
#         echo "fallback packaging found no installable files in $source_dir" >&2
#         return 1
#     fi
#
#     (
#         cd "$(dirname "$stage_root")"
#         rm -f "$PACKAGE_FILE_NAME"
#         zip -r "$PACKAGE_FILE_NAME" "$(basename "$stage_root")"
#     )
#
#     rm -f "$package_path"
#     mv -f "$(dirname "$stage_root")/$PACKAGE_FILE_NAME" "$package_path"
# }
#
# if ! package_with_upstream; then
#     package_fallback
# fi
#
# package_sha256=$(sha256sum "$package_path" | awk '{print $1}')
# metadata_path="$artifact_dir/build-metadata.txt"
#
# cat > "$metadata_path" <<EOF
# component=$COMPONENT
# version=$COMPONENT_VERSION
# source_url=$SOURCE_URL
# source_archive=$SOURCE_ARCHIVE_NAME
# source_dir=$SOURCE_DIR_NAME
# config_path=$config_file
# package=$PACKAGE_FILE_NAME
# package_sha256=$package_sha256
# runner=${RUNNER_OS:-Windows}
# toolchain=MSYS2 MINGW64
# built_at_utc=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
# workflow=${GITHUB_WORKFLOW:-}
# run_id=${GITHUB_RUN_ID:-}
# run_attempt=${GITHUB_RUN_ATTEMPT:-}
# local_patch_count=${#local_patches[@]}
# EOF
