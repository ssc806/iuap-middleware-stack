# OpenResty Windows Patches

将需要额外应用到 OpenResty 源码树的 `*.patch` 文件放在这里。

`build/openresty/windows/build.sh` 会在源码解压后、执行上游 `util/build-win32.sh` 之前，按文件名字典序依次应用这些补丁。
