extends SceneTree

const UpdateManager = preload("res://scripts/update/update_manager.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var request := HTTPRequest.new()
	root.add_child(request)
	var error := request.request(UpdateManager.PRIMARY_RELEASE_API, PackedStringArray(["User-Agent: MedievalDiceUpdateSmoke/1.1.5-test"]))
	if error != OK:
		_fail("could not start ECS update metadata request: %s" % error_string(error))
		return
	var response: Array = await request.request_completed
	if int(response[0]) != HTTPRequest.RESULT_SUCCESS or int(response[1]) != 200:
		_fail("ECS update metadata request failed: result=%s status=%s" % [response[0], response[1]])
		return
	var release = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
	if not release is Dictionary or str(release.get("tag_name", "")) != "v1.1.6":
		_fail("ECS update metadata did not return v1.1.6")
		return
	if not UpdateManager.is_remote_newer("1.1.5-test", str(release.get("tag_name", ""))):
		_fail("v1.1.5-test did not detect v1.1.6 as newer")
		return
	var android_url := UpdateManager.get_asset_url(release, "Android")
	var windows_url := UpdateManager.get_asset_url(release, "Windows")
	if not android_url.begins_with("http://121.196.201.193:9080/updates/") or not windows_url.begins_with("http://121.196.201.193:9080/updates/"):
		_fail("ECS metadata did not select the domestic download URLs")
		return
	if not UpdateManager.get_asset_fallback_url(release, "Android").begins_with("https://github.com/"):
		_fail("ECS metadata did not include the GitHub fallback URL")
		return
	print("ECS update metadata and v1.1.5-test to v1.1.6 detection passed")
	quit(0)


func _fail(message: String) -> void:
	printerr(message)
	quit(1)
