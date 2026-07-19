# 中世纪骰局

这是一个使用 Godot 4.6.1 与 GDScript 制作的横屏骰子游戏。首版为玩家对电脑，规则层与画面层相互独立；骰子、木桌、羊皮纸和应用图标均为本项目原创素材，没有复制或分发《天国：拯救 2》的资源。

## 打开与运行

1. 使用 Godot 4.6.1 打开本目录中的 `project.godot`。
2. 项目采用 Compatibility 渲染器，主场景为 `scenes/main.tscn`。
3. 按 F6/F5 或点击编辑器右上角运行按钮即可开始。

默认目标为 4000 分，主菜单也可选择 1500、2500 或 6000 分。

## 操作

- A/D 或左右方向键：切换当前骰子。
- 空格或 E：选择/取消选择骰子。
- F：提交选中分数并继续掷骰。
- Q：停手，将本回合分数计入总分。
- T：查看规则。
- Esc：返回主菜单。
- 手机：直接点击骰子，并使用画面右侧按钮操作。

只有能完整分解为得分组合的选择才能提交。当前投掷无得分骰时会爆骰，本回合累计分清零；收起全部可用骰子后再次投掷会获得六枚新骰子。

## 自动测试

在 PowerShell 中执行：

```powershell
& "D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\shaizi_game" --script "res://tests/test_runner.gd"
```

测试覆盖计分组合、非法混选、爆骰、热骰、状态切换、AI 决策和全部 46,656 种六骰结果。

## Windows 导出

工程已配置 `Windows Desktop` Release 导出预设，目标架构为 x86_64，游戏资源嵌入单个 EXE。命令行导出：

```powershell
& "D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\shaizi_game" --export-release "Windows Desktop" "D:\shaizi_game\build\windows\medieval_dice.exe"
```

已导出的程序位于 `build/windows/medieval_dice.exe`，分发压缩包位于 `build/medieval_dice-windows-x86_64.zip`。当前构建未使用商业代码签名证书，Windows 首次运行时可能显示安全提醒。

## Android 导出

工程已配置 Android Gradle 导出，包名为 `com.local.medievaldice`，版本为 `1.0.0`，最低 Android 版本为 7.0（API 24），目标 API 为 35，仅打包 ARM64。

本机工具链位于被 Git 忽略的 `.tools` 目录，包含 JDK 17、Android SDK Platform/Build Tools 35、NDK 28.1 与 CMake 3.10.2。换机后应在 Godot 的“编辑器设置 → 导出 → Android”中重新填写 JDK 和 Android SDK 路径。

命令行导出：

```powershell
& "D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\shaizi_game" --export-debug "Android" "D:\shaizi_game\build\android\medieval_dice-debug.apk"
```

已导出的 Debug APK 位于 `build/android/medieval_dice-debug.apk`，可通过 ADB 安装：

```powershell
& ".tools\android-sdk\platform-tools\adb.exe" install -r "build\android\medieval_dice-debug.apk"
```

## 素材与许可

- 中文字体：霞鹜文楷 v1.522，SIL Open Font License 1.1。完整许可见 `licenses/LXGW-WenKai-OFL-1.1.txt`。
- 木桌纹理、羊皮纸面板和应用图标：使用 OpenAI imagegen 为本项目生成的原创素材，提示词记录在 `ASSET_SOURCES.md`。
- 骰子网格、凹点和金色选择环：运行时由项目代码程序化生成。
