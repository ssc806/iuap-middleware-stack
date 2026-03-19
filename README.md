# iuap-middleware-stack

用于统一管理 Windows 中间件制品构建的 GitHub Actions 仓库。

当前已落地的第一条构建链路是 OpenResty on `windows-2022`。仓库结构按组件拆分，后续新增中间件时沿用同一套 `configs/<component>`、`build/<component>/windows`、`patches/<component>/windows` 约定即可，不需要复制整套工作流。

详细触发方式、输入参数、制品命名和目录说明见 [docs/windows-builds.md](docs/windows-builds.md)。
