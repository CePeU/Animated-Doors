extends Reference

const G = preload("door_geometry.gd")

# Pixel edges in the unrotated Sprite region/frame, before orientation or tint.
# Round both edges inward. The epsilon only cancels floating-point round trips.
static func calculate(width, height, axis, length_grid, a_grid, b_grid):
	if not axis in ["width", "height"] or not G.number(length_grid) or length_grid <= 0:
		return G.failure("CROP", "Cannot determine the placed image length for cropping.")
	for value in [width, height]:
		if not G.number(value) or value <= 0 or value != int(value):
			return G.failure("CROP", "The source image dimensions must be whole pixels.")
	for value in [a_grid, b_grid]:
		if not G.number(value) or value < 0:
			return G.failure("CROP", "Crop offsets must be finite, non-negative numbers.")
	if a_grid + b_grid >= length_grid:
		return G.failure("CROP", "Crop offsets leave no whole image pixels. Reduce the offsets.")
	var size = width if axis == "width" else height
	var start = int(ceil(a_grid * size / length_grid - 0.000001))
	var end = int(floor(size - b_grid * size / length_grid + 0.000001))
	if start < 0 or end > size or start >= end:
		return G.failure("CROP", "Crop offsets leave no whole image pixels. Reduce the offsets.")
	return G.success({"x": start if axis == "width" else 0, "y": start if axis == "height" else 0,
		"width": end - start if axis == "width" else int(width), "height": end - start if axis == "height" else int(height),
		"source_width": int(width), "source_height": int(height), "unit": "source_frame_pixels"})

static func placed(record, crop):
	var result = record.duplicate(true)
	var t = result.transform
	var axis = "axis_x" if record.texture_axis == "width" else "axis_y"
	var size = crop.source_width if record.texture_axis == "width" else crop.source_height
	var start = crop.x if record.texture_axis == "width" else crop.y
	var remaining = crop.width if record.texture_axis == "width" else crop.height
	t.origin = G.json_point(G.vector(t.origin) + G.vector(t[axis]) * (float(start) / size))
	t[axis] = G.json_point(G.vector(t[axis]) * (float(remaining) / size))
	result.bounds = G.artwork_bounds(t, record.texture_axis)
	return result

static func from_record(record, width, height):
	var offset = record.get("hinge_offset_grid", {"a": 0, "b": 0})
	if not offset is Dictionary:
		return G.failure("CROP", "Missing crop offsets in grid units.")
	var axis = record.get("texture_axis", "width")
	var length_grid = G.vector(record.transform.axis_x if axis == "width" else record.transform.axis_y).length()
	return calculate(width, height, axis, length_grid, offset.get("a"), offset.get("b"))

# Inspect dimensions and context only; never read or hash image pixels here.
static func context(sprite, grid_size = 256.0):
	if not sprite is Sprite or sprite.texture == null or sprite.texture is AtlasTexture:
		return G.failure("CROP", "No supported source image is available for cropping.")
	var rect = sprite.region_rect if sprite.region_enabled else Rect2(Vector2.ZERO, sprite.texture.get_size())
	var size = rect.size / Vector2(sprite.hframes, sprite.vframes)
	if rect.position.x != int(rect.position.x) or rect.position.y != int(rect.position.y):
		return G.failure("CROP", "The source region must start at whole image pixels.")
	if size.x <= 0 or size.y <= 0 or size.x != int(size.x) or size.y != int(size.y):
		return G.failure("CROP", "The source frame must contain whole image pixels.")
	if rect.position.x < 0 or rect.position.y < 0 or rect.end.x > sprite.texture.get_width() or rect.end.y > sprite.texture.get_height():
		return G.failure("CROP", "The source region is outside the image.")
	var path = sprite.texture.resource_path.replace("\\", "/")
	var package_id = path.trim_prefix("res://packs/").split("/")[0] if path.begins_with("res://packs/") else ""
	var source = {"package_id": package_id, "path": path, "region_enabled": sprite.region_enabled,
		"region": [rect.position.x, rect.position.y, rect.size.x, rect.size.y] if sprite.region_enabled else [],
		"hframes": sprite.hframes, "vframes": sprite.vframes, "frame": sprite.frame}
	var placement = G.image_transform(sprite.get_rect(), sprite.global_transform, sprite.flip_h, sprite.flip_v, grid_size)
	if not placement.ok:
		return placement
	return G.success({"key": JSON.print(source) if not path.empty() else "", "source": source,
		"width": int(size.x), "height": int(size.y), "transform": placement.value})

static func for_settings(context, settings):
	return from_record({"transform": context.transform, "texture_axis": settings.axis,
		"hinge_offset_grid": {"a": settings.hinge_offset_a / 256.0, "b": settings.hinge_offset_b / 256.0}}, context.width, context.height)

static func offsets(context, axis, crop):
	var size = context.width if axis == "width" else context.height
	var length_grid = G.vector(context.transform.axis_x if axis == "width" else context.transform.axis_y).length()
	var start = crop.x if axis == "width" else crop.y
	var end = start + (crop.width if axis == "width" else crop.height)
	return {"hinge_offset_a": start * length_grid * 256.0 / size, "hinge_offset_b": (size - end) * length_grid * 256.0 / size}
