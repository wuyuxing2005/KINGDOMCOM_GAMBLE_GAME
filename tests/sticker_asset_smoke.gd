extends SceneTree

const STICKERS := ["smile", "heart_eyes", "crying", "side_eye", "black_grin", "excited"]

func _initialize() -> void:
	var failures := 0
	for sticker_id in STICKERS:
		var path := "res://assets/chat/stickers/%s.png" % sticker_id
		var texture: Texture2D = load(path)
		var image := texture.get_image() if texture != null else null
		if image == null or image.is_empty():
			printerr("FAIL: 无法读取表情：%s" % sticker_id)
			failures += 1
			continue
		if image.get_size() != Vector2i(256, 256):
			printerr("FAIL: 表情尺寸不是256x256：%s" % sticker_id)
			failures += 1
		if image.get_pixel(0, 0).a > 0.01 or image.get_pixel(255, 255).a > 0.01:
			printerr("FAIL: 表情角落不是透明背景：%s" % sticker_id)
			failures += 1
		var used_rect := image.get_used_rect()
		if maxi(used_rect.size.x, used_rect.size.y) > 210 or maxi(used_rect.size.x, used_rect.size.y) < 200:
			printerr("FAIL: 表情主体尺寸不统一：%s %s" % [sticker_id, used_rect])
			failures += 1
	if failures == 0:
		print("PASS: 六张表情的透明背景、256画布和统一主体尺寸测试通过")
	quit(1 if failures > 0 else 0)
