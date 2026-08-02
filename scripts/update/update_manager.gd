class_name AppUpdateManager
extends Node

signal status_changed(message: String)
signal busy_changed(busy: bool)

const PRIMARY_RELEASE_API := "http://121.196.201.193:9080/updates/latest.json"
const GITHUB_RELEASE_API := "https://api.github.com/repos/wuyuxing2005/KINGDOMCOM_GAMBLE_GAME/releases/latest"
const ANDROID_ASSET := "medieval_dice-debug.apk"
const WINDOWS_ASSET := "medieval_dice-windows-x86_64.zip"

var current_version := str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
var latest_version := ""
var latest_release_url := ""
var download_url := ""
var fallback_download_url := ""
var download_path := ""
var check_request: HTTPRequest
var download_request: HTTPRequest
var busy := false
var checking_github := false
var downloading_from_github := false


func _ready() -> void:
	check_request = HTTPRequest.new()
	check_request.timeout = 20.0
	check_request.request_completed.connect(_on_check_completed)
	add_child(check_request)
	download_request = HTTPRequest.new()
	download_request.timeout = 300.0
	download_request.request_completed.connect(_on_download_completed)
	add_child(download_request)
	set_process(false)


func _process(_delta: float) -> void:
	if not busy or download_request == null:
		return
	var total := download_request.get_body_size()
	if total > 0:
		var percent := int(float(download_request.get_downloaded_bytes()) / float(total) * 100.0)
		status_changed.emit("正在下载 v%s：%d%%" % [latest_version, percent])


func check_and_install() -> void:
	if busy:
		return
	_set_busy(true)
	checking_github = false
	downloading_from_github = false
	status_changed.emit("正在检查更新…")
	_request_release(PRIMARY_RELEASE_API)


func _request_release(url: String) -> void:
	var headers := PackedStringArray([
		"User-Agent: MedievalDiceUpdater/%s" % current_version,
	])
	if checking_github:
		headers.append("Accept: application/vnd.github+json")
		headers.append("X-GitHub-Api-Version: 2022-11-28")
	var error := check_request.request(url, headers)
	if error != OK:
		if not checking_github:
			_start_github_check()
		else:
			_fail("无法开始检查更新：%s" % error_string(error))


func _start_github_check() -> void:
	checking_github = true
	status_changed.emit("国内更新源不可用，正在尝试 GitHub…")
	_request_release(GITHUB_RELEASE_API)


func _on_check_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		if not checking_github:
			_start_github_check()
		else:
			_fail("检查更新失败，请确认网络连接")
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		_fail("更新信息格式无效")
		return
	latest_version = str(parsed.get("tag_name", "")).trim_prefix("v")
	latest_release_url = str(parsed.get("html_url", ""))
	if latest_version.is_empty():
		_fail("未找到有效的版本号")
		return
	if not is_remote_newer(current_version, latest_version):
		status_changed.emit("当前已是最新版 v%s" % current_version)
		_set_busy(false)
		return
	download_url = get_asset_url(parsed, OS.get_name())
	fallback_download_url = get_asset_fallback_url(parsed, OS.get_name())
	if download_url.is_empty():
		_fail("最新版没有当前平台的安装包")
		return
	_start_download()


func _start_download() -> void:
	var update_dir := ProjectSettings.globalize_path("user://updates")
	var error := DirAccess.make_dir_recursive_absolute(update_dir)
	if error != OK:
		_fail("无法创建更新目录：%s" % error_string(error))
		return
	download_path = update_dir.path_join(ANDROID_ASSET if OS.get_name() == "Android" else WINDOWS_ASSET)
	download_request.download_file = download_path
	set_process(true)
	status_changed.emit("正在下载 v%s：0%%" % latest_version)
	error = _request_download()
	if error != OK:
		set_process(false)
		_fail("无法开始下载安装包：%s" % error_string(error))


func _request_download() -> Error:
	return download_request.request(download_url, PackedStringArray(["User-Agent: MedievalDiceUpdater/%s" % current_version]))


func _on_download_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	set_process(false)
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		if not downloading_from_github and not fallback_download_url.is_empty():
			downloading_from_github = true
			download_url = fallback_download_url
			status_changed.emit("国内下载失败，正在尝试 GitHub…")
			set_process(true)
			var error := _request_download()
			if error != OK:
				set_process(false)
				_fail("无法开始 GitHub 下载：%s" % error_string(error))
			return
		_fail("更新包下载失败")
		return
	if OS.get_name() == "Android":
		_install_android()
	elif OS.get_name() == "Windows":
		_install_windows()
	else:
		_fail("当前平台暂不支持自动安装")


func _install_android() -> void:
	if not Engine.has_singleton("UpdateInstaller"):
		_fail("Android 更新安装组件不可用")
		return
	status_changed.emit("下载完成，请按系统提示确认安装")
	Engine.get_singleton("UpdateInstaller").installUpdate(download_path)
	_set_busy(false)


func _install_windows() -> void:
	var staging_dir := ProjectSettings.globalize_path("user://updates/staged/%s" % latest_version)
	var error := DirAccess.make_dir_recursive_absolute(staging_dir)
	if error != OK:
		_fail("无法创建更新暂存目录：%s" % error_string(error))
		return
	var reader := ZIPReader.new()
	error = reader.open(download_path)
	if error != OK:
		_fail("无法读取 Windows 更新包")
		return
	for entry in reader.get_files():
		if entry.ends_with("/") or entry.ends_with(".lnk"):
			continue
		var output_path := staging_dir.path_join(entry)
		DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
		var output := FileAccess.open(output_path, FileAccess.WRITE)
		if output == null:
			reader.close()
			_fail("无法解压 Windows 更新包")
			return
		output.store_buffer(reader.read_file(entry))
	reader.close()
	var executable_path := OS.get_executable_path()
	var updater_script := ProjectSettings.globalize_path("user://updates/apply_update.ps1")
	var script := FileAccess.open(updater_script, FileAccess.WRITE)
	if script == null:
		_fail("无法创建 Windows 更新程序")
		return
	script.store_string(_windows_updater_script())
	script.close()
	status_changed.emit("下载完成，正在安装并重新启动…")
	var updater_pid := OS.create_process("powershell.exe", PackedStringArray([
		"-NoProfile",
		"-ExecutionPolicy", "Bypass",
		"-File", updater_script,
		"-RunningProcessId", str(OS.get_process_id()),
		"-Source", staging_dir,
		"-Target", executable_path.get_base_dir(),
		"-ExecutableName", executable_path.get_file(),
	]))
	if updater_pid <= 0:
		_fail("无法启动 Windows 更新程序")
		return
	get_tree().quit()


func _set_busy(value: bool) -> void:
	busy = value
	busy_changed.emit(busy)


func _fail(message: String) -> void:
	status_changed.emit(message)
	_set_busy(false)


static func is_remote_newer(installed: String, remote: String) -> bool:
	var installed_parts := _version_parts(installed)
	var remote_parts := _version_parts(remote)
	for index in range(3):
		if remote_parts[index] != installed_parts[index]:
			return remote_parts[index] > installed_parts[index]
	return false


static func get_asset_url(release: Dictionary, platform_name: String) -> String:
	var expected_name := ANDROID_ASSET if platform_name == "Android" else WINDOWS_ASSET if platform_name == "Windows" else ""
	for asset in release.get("assets", []):
		if asset is Dictionary and str(asset.get("name", "")) == expected_name:
			return str(asset.get("browser_download_url", ""))
	return ""


static func get_asset_fallback_url(release: Dictionary, platform_name: String) -> String:
	var expected_name := ANDROID_ASSET if platform_name == "Android" else WINDOWS_ASSET if platform_name == "Windows" else ""
	for asset in release.get("assets", []):
		if asset is Dictionary and str(asset.get("name", "")) == expected_name:
			return str(asset.get("fallback_download_url", ""))
	return ""


static func _version_parts(version: String) -> Array[int]:
	var clean := version.trim_prefix("v").split("-", false, 1)[0]
	var fields := clean.split(".")
	var parts: Array[int] = [0, 0, 0]
	for index in range(mini(fields.size(), 3)):
		parts[index] = int(fields[index])
	return parts


static func _windows_updater_script() -> String:
	return """param(
    [int]$RunningProcessId,
    [string]$Source,
    [string]$Target,
    [string]$ExecutableName
)
Wait-Process -Id $RunningProcessId -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500
Copy-Item -Path (Join-Path $Source '*') -Destination $Target -Recurse -Force
Start-Process -FilePath (Join-Path $Target $ExecutableName) -WorkingDirectory $Target
"""
