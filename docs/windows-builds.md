# Windows 构建流程

## 当前覆盖范围

- 组件：`openresty`
- Runner：`windows-2022`
- 工具链：`msys2/setup-msys2@v2` + `MINGW64`

## 目录约定

- `.github/workflows/build-windows-artifact.yml`：GitHub Actions 入口
- `build/windows/resolve-build.ps1`：通用版本、路径、制品元数据解析
- `build/openresty/windows/build.sh`：OpenResty Windows 构建与打包脚本
- `configs/openresty/windows.env`：默认版本、源码地址模板、Tag 规则
- `patches/openresty/windows/`：本地补丁投放目录
- `artifacts/`：运行时产物暂存目录，已通过 Git 忽略

## 触发方式

- `workflow_dispatch`：手工触发，可覆盖版本号和制品保留天数
- `push` 到 `main`：当工作流、脚本、配置或文档发生变更时，按默认版本重新构建
- `push` Tag `openresty-v*`：从 Tag 后缀自动解析版本号，例如 `openresty-v1.29.2.1`

## 输入参数

- `component`：当前只开放 `openresty`
- `version`：可选。手工触发时优先使用；如果为空且本次构建来自 Tag，则会去掉 `openresty-v` 前缀后作为版本号；仍为空时回落到 `configs/openresty/windows.env`
- `artifact_retention_days`：可选。为空时回落到配置文件默认值

## 制品说明

- GitHub Actions 中展示的制品名：`openresty-<version>-win64`
- 当前 workflow run 内的下载入口：Actions 页面右侧 `Artifacts`
- 上传内容包含 `openresty-<version>-win64.zip`
- 上传内容包含 `build-metadata.txt`
- Workflow 运行期间的工作区暂存路径：`artifacts/openresty/<version>/`

## 扩展新组件

- 新增 `configs/<component>/windows.env`
- 新增 `build/<component>/windows/build.sh`
- 如需源码调整，可在 `patches/<component>/windows/` 放置 `*.patch`
- 如需允许手工选择新组件，再把 `.github/workflows/build-windows-artifact.yml` 的 `component` 选项扩展出去
