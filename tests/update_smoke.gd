extends SceneTree

const UpdateManager = preload("res://scripts/update/update_manager.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	if not UpdateManager.is_remote_newer("1.1.3", "v1.1.4"):
		_fail("new patch version was not detected")
		return
	if UpdateManager.is_remote_newer("1.1.4", "1.1.4") or UpdateManager.is_remote_newer("1.2.0", "1.1.9"):
		_fail("same or older release was treated as an update")
		return
	if not UpdateManager.is_remote_newer("1.9.9", "1.10.0"):
		_fail("multi-digit version component comparison failed")
		return
	var release := {
		"assets": [
			{"name": "medieval_dice-debug.apk", "browser_download_url": "https://example.test/game.apk", "fallback_download_url": "https://example.test/fallback.apk"},
			{"name": "medieval_dice-windows-x86_64.zip", "browser_download_url": "https://example.test/game.zip"},
		]
	}
	if UpdateManager.get_asset_url(release, "Android") != "https://example.test/game.apk":
		_fail("Android release asset selection failed")
		return
	if UpdateManager.get_asset_url(release, "Windows") != "https://example.test/game.zip":
		_fail("Windows release asset selection failed")
		return
	if UpdateManager.get_asset_fallback_url(release, "Android") != "https://example.test/fallback.apk":
		_fail("Android fallback release asset selection failed")
		return
	if UpdateManager.get_asset_url(release, "Linux") != "":
		_fail("unsupported platform unexpectedly selected an update asset")
		return
	var updater_script := UpdateManager._windows_updater_script()
	if not updater_script.contains("Wait-Process") or not updater_script.contains("Copy-Item") or not updater_script.contains("Start-Process"):
		_fail("Windows updater script is missing the wait, replace, or restart step")
		return
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var main = current_scene
	if main.update_button == null or main.update_button.text != "检查更新":
		_fail("main menu update button was not created")
		return
	if main.update_button.anchor_left != 1.0 or main.update_button.anchor_top != 0.0:
		_fail("update button is not anchored to the top-right corner")
		return
	main._on_update_busy_changed(true)
	main._on_update_status_changed("正在下载 v1.1.4：50%")
	if not main.update_button.disabled or main.update_status_label.text != "正在下载 v1.1.4：50%":
		_fail("update progress UI did not enter the busy state")
		return
	main._on_update_busy_changed(false)
	if main.update_button.disabled or main.update_button.text != "检查更新":
		_fail("update UI did not return to the idle state")
		return
	if DisplayServer.get_name() != "headless":
		await process_frame
		var image := root.get_texture().get_image()
		var error := image.save_png("res://build/update-menu-smoke.png")
		if error != OK:
			_fail("update menu smoke capture failed: %s" % error)
			return
	print("update manager and main menu update UI smoke test passed")
	quit(0)


func _fail(message: String) -> void:
	printerr(message)
	quit(1)
