# Android 更新安装桥接

`UpdateInstallerPlugin` 由 `addons/update_installer.aar` 提供给 Godot Android 自定义构建。它接收已下载 APK 的内部文件路径，在需要时打开“安装未知应用”授权页，然后调用 Android 系统安装界面。

普通 Android 应用不能静默安装 APK，因此最后一步必须由用户在系统界面确认。
