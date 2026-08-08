extends SceneTree

const UpdateManager = preload("res://scripts/update/update_manager.gd")
const PREVIOUS_RELEASE_VERSION := "1.1.6"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var request := HTTPRequest.new()
	root.add_child(request)
	var expected_tag := "v%s" % ProjectSettings.get_setting("application/config/version")
	var error := request.request(UpdateManager.PRIMARY_RELEASE_API, PackedStringArray(["User-Agent: MedievalDiceUpdateSmoke/%s" % PREVIOUS_RELEASE_VERSION]))
	if error != OK:
		_fail("could not start ECS update metadata request: %s" % error_string(error))
		return
	var response: Array = await request.request_completed
	if int(response[0]) != HTTPRequest.RESULT_SUCCESS or int(response[1]) != 200:
		_fail("ECS update metadata request failed: result=%s status=%s" % [response[0], response[1]])
		return
	var release = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
	if not release is Dictionary or str(release.get("tag_name", "")) != expected_tag:
		_fail("ECS update metadata did not return %s" % expected_tag)
		return
	if not UpdateManager.is_remote_newer(PREVIOUS_RELEASE_VERSION, str(release.get("tag_name", ""))):
		_fail("v%s did not detect %s as newer" % [PREVIOUS_RELEASE_VERSION, expected_tag])
		return
	var android_url := UpdateManager.get_asset_url(release, "Android")
	var windows_url := UpdateManager.get_asset_url(release, "Windows")
	if not android_url.begins_with("http://121.196.201.193:9080/updates/") or not windows_url.begins_with("http://121.196.201.193:9080/updates/"):
		_fail("ECS metadata did not select the domestic download URLs")
		return
	if not UpdateManager.get_asset_fallback_url(release, "Android").begins_with("https://github.com/"):
		_fail("ECS metadata did not include the GitHub fallback URL")
		return
	print("ECS update metadata and v%s to %s detection passed" % [PREVIOUS_RELEASE_VERSION, expected_tag])
	quit(0)


func _fail(message: String) -> void:
	printerr(message)
	quit(1)
