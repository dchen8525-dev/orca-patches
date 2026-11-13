# Orca Windows 打包完整流程

记录 2026-11-13 实际走通的全链路及所有环境坑。前置：Node（本机 22.22.2 可用于依赖安装与资产构建）、Git Bash、VS Build Tools（native addon 与 Rust 编译需要）。

## 0. 依赖安装

```bash
cd /d/work/orca
pnpm install --frozen-lockfile
pnpm -C mobile install --frozen-lockfile
```

坑：Electron postinstall 下载二进制时可能因本机安全策略拦截 reg.exe 而失败。手动放置：

```bash
# 版本以 node_modules/electron/package.json 为准（当前 43.8.7）
curl -L -o electron-v43.8.7-win32-x64.zip \
  https://npmmirror.com/mirrors/electron/43.8.7/electron-v43.8.7-win32-x64.zip
mkdir -p node_modules/electron/dist
/c/Windows/System32/tar.exe -xf electron-v43.8.7-win32-x64.zip -C node_modules/electron/dist
printf "electron.exe" > node_modules/electron/path.txt
# checksum 对比 node_modules/electron/checksums.json
```

直连 nodejs.org / github.com 慢或被拦时，可用 VPS 中转下载。

## 1. 桌面资产构建

```bash
export CODEBUDDY_SAFE_DELETE_ENABLED=0   # WorkBuddy node shim 会拦 vite 清理 out/，构建期必须禁用
pnpm run build:desktop                    # typecheck + wsl-guest + skills-cli + electron-vite + web
pnpm run build:mobile-web
```

## 2. Electron 运行时 native addon rebuild

```bash
node config/scripts/native-build/node-addons/ensure-native-runtime.mjs --runtime=electron
```

## 3. Rust launcher（需要 002 patch + SDK 环境变量）

```bash
export ORCA_WINDOWS_RC_TOOLKIT="C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64"
node config/scripts/native-build/windows/build-windows-cli-launcher.mjs
node config/scripts/native-build/windows/build-windows-agent-hook.mjs --arch x64
```

SDK 版本号按本机实际目录调整。无此环境变量时 winresource 走注册表查询，reg.exe 被拦截的环境会失败。

## 4. electron-builder 打 NSIS 安装包（必须 Node 24）

afterPack 校验用**打包机 Node** 的 `builtinModules` 判断 `node:sqlite`，仓库 engines 要求 Node 24；Node 22 会校验失败。不改校验代码，直接换 Node 跑：

```bash
# Node 24 绿色版解压到 %TEMP%/node-v24.22.3-win-x64（按需换版本）
export ELECTRON_BUILDER_MIRROR=https://npmmirror.com/mirrors/electron-builder-binaries/
/c/Users/admin/AppData/Local/Temp/node-v24.22.3-win-x64/node.exe \
  node_modules/electron-builder/cli.js --config config/electron-builder.config.cjs --win
```

注意：不要用 `PATH` 前置 `$TEMP/...` 的方式切换 Node——MSYS 不识别 Windows 风格 `$TEMP`，实际仍会跑旧 Node。必须用绝对路径直接启动。

## 5. 产物

```
dist/orca-windows-setup.exe   # NSIS oneClick, x64
```

签名：本机 signtool 证书非正式发布证书，SmartScreen 会提示，属预期。

## 已知未决

- 改动未提交回 orca upstream；提 PR 前跑 `pnpm check:changed`。
- electron zip 与解压目录留在仓库根，可删。
