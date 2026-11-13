# orca-patches

个人维护的 [stablyai/orca](https://github.com/stablyai/orca) 本地补丁集。每次 upstream main 更新后：拉新代码 → 打 patch → 编译出安装包。

## 补丁清单

| Patch | 内容 |
|---|---|
| `001-claude-model-picker-support.patch` | Claude catalog probe 读取账号目录 `settings.json` 的 `modelPicker`，让 GUI 模型列表与 CLI `/model` 一致（`replaceBuiltInOptions` 过滤、自定义 label、alias 行 effort 合并）。新增 `claude-model-picker-settings.ts` 及其测试。 |
| `002-windows-rc-toolkit-env.patch` | `native/windows-cli-launcher/build.rs`、`native/windows-agent-hook/build.rs` 支持用环境变量 `ORCA_WINDOWS_RC_TOOLKIT` 显式指定 Windows SDK 的 rc.exe 目录，跳过 winresource 的注册表查询（本机 reg.exe 被安全策略拦截时必需）。缺省行为不变。 |

## 用法

```bash
cd /d/work/orca
git pull origin main

/d/work/orca-patches/apply-patches.sh /d/work/orca
```

脚本行为：
- 能干净应用的 patch 直接应用；
- 已应用的（反向校验通过）跳过；
- 应用失败的（upstream 改了相关代码导致冲突）报 CONFLICT 并以 exit 2 退出——此时需要手动把对应 patch 重新对 upstream 生成。

然后按 `BUILD.md` 编译打包。

## 维护新补丁

在 orca 仓库做完改动后：

```bash
cd /d/work/orca
# 未跟踪的新文件先登记，让 git diff 能包含它们
git add -N <new-file.ts>

git diff -- src/main/claude/model-catalog/ > /d/work/orca-patches/patches/00X-xxx.patch
```

命名保持 `NNN-短描述.patch`，脚本按文件名顺序应用。
