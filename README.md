# 中世纪骰局

这是一个使用 Godot 4.6.1 与 GDScript 制作的横屏骰子游戏，支持玩家对电脑和房间码双人联机。规则层与画面层相互独立；骰子、木桌、羊皮纸和应用图标均为本项目原创素材，没有复制或分发《天国：拯救 2》的资源。

## 打开与运行

1. 使用 Godot 4.6.1 打开本目录中的 `project.godot`。
2. 项目采用 Compatibility 渲染器，主场景为 `scenes/main.tscn`。
3. 按 F6/F5 或点击编辑器右上角运行按钮即可开始。

默认目标为 4000 分，主菜单也可选择 1500、2500 或 6000 分。

主界面右上角提供“检查更新”。点击后会优先通过国内 ECS 更新源检查并下载最新版，国内源不可用时自动回退 GitHub：Android 会打开系统安装确认界面，Windows 会退出游戏、替换程序并自动重新启动。

## 联机对战

联机采用服务器权威模式：客户端只发送选择、继续投掷和停手动作，骰子点数、动作合法性、回合切换及胜负全部由服务器决定。

1. 在主菜单进入“联机对战”，选择“创建房间”或“加入房间”。
2. 创建者进入创建页面后选择目标分数，点击“创建并获取房间码”，再点击显示的房间码复制并发给另一名玩家。
3. 加入者进入加入页面后输入房间码并点击“加入房间”，两人到齐后自动开局。

双方进入房间后由服务器随机决定先手玩家。

联机对局结束后双方可以选择“再来一局”。两人都确认后，由原房主重新选择目标分数；服务器随后清空比分、重新随机先手并开始新局。若一方已经退出，另一方点击重赛时会收到提示。

客户端内置公共联机服务器地址，普通玩家不需要填写或配置服务器。

## 操作

- A/D 或左右方向键：切换当前骰子。
- 空格或 E：选择/取消选择骰子。
- F：提交选中分数并继续掷骰。
- Q：停手，将本回合分数计入总分。
- T：查看规则。
- 设置：打开音乐与显示设置；单人对局暂停，联机对局继续运行。
- Esc：返回主菜单。
- 手机：直接点击骰子，并使用画面右侧按钮操作。

只有能完整分解为得分组合的选择才能提交。当前投掷无得分骰时会爆骰，本回合累计分清零；收起全部可用骰子后再次投掷会获得六枚新骰子。

## 音乐与设置

游戏启动后会循环播放背景音乐，切换主菜单、游戏界面或设置界面时不会中断。主界面和游戏内均提供“设置”入口，可调整音乐音量。单人游戏打开设置时会暂停并保留当前对局；联机游戏打开设置时服务器对局和画面状态继续运行。两种模式均可返回游戏，或返回主界面并结束本局。

Windows 版设置页还提供“无边框全屏”开关；Android 版不显示此选项。

## 自动测试

在 PowerShell 中执行：

```powershell
& "D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\shaizi_game" --script "res://tests/test_runner.gd"
```

测试覆盖计分组合、非法混选、爆骰、热骰、状态切换、AI 决策和全部 46,656 种六骰结果。

双客户端联机测试：

```powershell
& "D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\shaizi_game" --script "res://tests/network_smoke.gd"
```

该测试会在本机启动临时服务器和两个客户端，验证创建房间、加入房间、权威掷骰、选择同步和停手结算。

## Windows 导出

工程已配置 `Windows Desktop` Release 导出预设，目标架构为 x86_64，游戏资源嵌入单个 EXE。命令行导出：

```powershell
& "D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\shaizi_game" --export-release "Windows Desktop" "D:\shaizi_game\build\windows\medieval_dice.exe"
```

已导出的程序位于 `build/windows/medieval_dice.exe`，分发压缩包位于 `build/medieval_dice-windows-x86_64.zip`。当前构建未使用商业代码签名证书，Windows 首次运行时可能显示安全提醒。

## Android 导出

工程已配置 Android Gradle 导出，包名为 `com.local.medievaldice`，版本为 `1.1.6`，最低 Android 版本为 7.0（API 24），目标 API 为 35，仅打包 ARM64，并已启用联网与请求系统安装 APK 的权限。

本机工具链位于被 Git 忽略的 `.tools` 目录，包含 JDK 17、Android SDK Platform/Build Tools 35、NDK 28.1 与 CMake 3.10.2。换机后应在 Godot 的“编辑器设置 → 导出 → Android”中重新填写 JDK 和 Android SDK 路径。

命令行导出：

```powershell
& "D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\shaizi_game" --export-debug "Android" "D:\shaizi_game\build\android\medieval_dice-debug.apk"
```

已导出的 Debug APK 位于 `build/android/medieval_dice-debug.apk`，可通过 ADB 安装：

```powershell
& ".tools\android-sdk\platform-tools\adb.exe" install -r "build\android\medieval_dice-debug.apk"
```

## 联机服务器

推荐首发使用一台 Linux x86_64 云服务器：

- 最低：1 vCPU、1 GB 内存、10 GB 可用磁盘、公网 IPv4。
- 建议：2 vCPU、2 GB 内存、20 GB SSD、5 Mbps 或更高公网带宽、Ubuntu 24.04 LTS。
- 测试阶段只需开放 TCP 9080；正式发布建议只开放 80/443，由 Caddy 或 Nginx 将 `wss://` 反向代理到本机 `127.0.0.1:9080`。

这是一款双人回合制游戏，单房间消息量很小，首发不需要游戏专用高频 CPU、数据库或负载均衡。若玩家主要在中国大陆，优先选择距离玩家近的大陆节点；若暂不处理大陆域名备案，可先用香港节点测试，但需要实际测量玩家网络延迟和丢包。

工程已配置 `Linux Server` 导出预设。导出命令：

```powershell
& "D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "D:\shaizi_game" --export-release "Linux Server" "D:\shaizi_game\build\server\medieval_dice_server.x86_64"
```

上传后启动：

```bash
chmod +x /opt/medieval-dice/medieval_dice_server.x86_64
/opt/medieval-dice/medieval_dice_server.x86_64 -- --port=9080
```

`deploy/server/medieval-dice.service` 是 systemd 常驻服务模板，`deploy/server/Caddyfile` 是启用 TLS 的域名反向代理模板。替换其中的安装路径、用户和域名后再启用。

## 素材与许可

- 中文字体：霞鹜文楷 v1.522，SIL Open Font License 1.1。完整许可见 `licenses/LXGW-WenKai-OFL-1.1.txt`。
- 木桌纹理、羊皮纸面板和应用图标：使用 OpenAI imagegen 为本项目生成的原创素材，提示词记录在 `ASSET_SOURCES.md`。
- 骰子网格、凹点和金色选择环：运行时由项目代码程序化生成。
