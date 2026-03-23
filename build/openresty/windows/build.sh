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

wget "https://raw.githubusercontent.com/ssc806/iuap-middleware-stack/guocaifeng-patch-1/build/openresty/windows/openresty-1.27.1.2.zip"
unzip openresty-1.27.1.2.zip
cd openresty-1.27.1.2 && bash -x 127-win32.sh
