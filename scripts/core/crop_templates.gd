extends Reference

const G = preload("door_geometry.gd")
const Crop = preload("crop_geometry.gd")
var path = "user://animated_doors_crop_templates.json"
var data = {"version": 1, "assets": {}}
var writable = true
var issue = ""
var dirty_at = -1

func _init(custom_path = ""):
	if not custom_path.empty():
		path = custom_path
	var dir = Directory.new()
	# Recover only our last complete file after an interrupted rename.
	if not dir.file_exists(path) and dir.file_exists(path + ".bak"):
		dir.rename(path + ".bak", path)
	if not dir.file_exists(path):
		return
	var file = File.new()
	if file.open(path, File.READ) != OK:
		_block()
		return
	var parsed = JSON.parse(file.get_as_text()) if file.get_len() <= 4194304 else null
	file.close()
	if parsed == null or parsed.error != OK or not parsed.result is Dictionary or parsed.result.get("version") != 1 or not parsed.result.get("assets") is Dictionary:
		_block()
		return
	data = parsed.result

func _block():
	writable = false
	issue = "Crop template file is unreadable or has an unknown version; it is preserved. Normal defaults will be used."

func lookup(context, axis):
	if not writable:
		return G.failure("CROP_TEMPLATE", issue)
	var item = data.assets.get(context.key, {})
	if not item is Dictionary or not item.get("templates", {}) is Dictionary:
		return G.failure("CROP_TEMPLATE", "Invalid crop template; normal defaults will be used.")
	var crop = item.get("templates", {}).get(axis)
	if crop == null:
		return G.success(null)
	if not crop is Dictionary:
		return G.failure("CROP_TEMPLATE", "Invalid crop template; normal defaults will be used.")
	if crop.get("source_width") != context.width or crop.get("source_height") != context.height:
		return G.failure("CROP_TEMPLATE", "Source image dimensions changed; normal crop defaults will be used.")
	for key in ["x", "y", "width", "height"]:
		if not G.number(crop.get(key)) or crop[key] != int(crop[key]):
			return G.failure("CROP_TEMPLATE", "Invalid crop template; normal defaults will be used.")
	if crop.x < 0 or crop.y < 0 or crop.width <= 0 or crop.height <= 0 or crop.x + crop.width > context.width or crop.y + crop.height > context.height or (axis == "width" and (crop.y != 0 or crop.height != context.height)) or (axis == "height" and (crop.x != 0 or crop.width != context.width)):
		return G.failure("CROP_TEMPLATE", "Invalid crop template; normal defaults will be used.")
	return G.success(Crop.offsets(context, axis, crop))

func remember(context, axis, crop):
	if not writable or context.key.empty():
		return
	if not data.assets.get(context.key) is Dictionary:
		data.assets[context.key] = {"source": context.source, "templates": {}}
	if not data.assets[context.key].get("templates") is Dictionary:
		data.assets[context.key].templates = {}
	data.assets[context.key].templates[axis] = crop.duplicate(true)
	dirty_at = OS.get_ticks_msec()

func reset(context, axis):
	if writable and data.assets.get(context.key) is Dictionary and data.assets[context.key].get("templates") is Dictionary:
		data.assets[context.key].templates.erase(axis)
		if data.assets[context.key].templates.empty():
			data.assets.erase(context.key)
		dirty_at = OS.get_ticks_msec()

func tick():
	if dirty_at >= 0 and OS.get_ticks_msec() - dirty_at >= 500:
		return flush()
	return G.success(true)

func flush():
	if dirty_at < 0 or not writable:
		return G.success(true)
	# Stage and verify before replacing. A backup makes interruptions recoverable.
	var text = JSON.print(data, "  ")
	if text.to_utf8().size() > 4194304:
		return _write_failed()
	var file = File.new()
	if file.open(path + ".tmp", File.WRITE) != OK:
		return _write_failed()
	file.store_string(text)
	file.close()
	if file.open(path + ".tmp", File.READ) != OK:
		return _write_failed()
	var equal = file.get_as_text() == text
	file.close()
	if not equal:
		return _write_failed()
	var dir = Directory.new()
	if dir.file_exists(path + ".bak") and dir.remove(path + ".bak") != OK:
		return _write_failed()
	var existed = dir.file_exists(path)
	if existed and dir.rename(path, path + ".bak") != OK:
		return _write_failed()
	if dir.rename(path + ".tmp", path) != OK:
		if existed:
			dir.rename(path + ".bak", path)
		return _write_failed()
	if existed:
		dir.remove(path + ".bak")
	dirty_at = -1
	return G.success(true)

func _write_failed():
	dirty_at = -1 # Report once; a later edit may retry.
	return G.failure("CROP_TEMPLATE", "Could not save crop templates. Current door settings are unchanged.")
