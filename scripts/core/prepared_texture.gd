extends Reference

const G = preload("door_geometry.gd")
const E = preload("asset_encoder.gd")
const M = preload("portal_matcher.gd")
const PROFILE = "door-x-hinge-left-v1"
const TARGET = "v14-door-2"
const Metadata = preload("asset_metadata.gd")
const Crop = preload("crop_geometry.gd")

# A discrete pixel-axis permutation. World rotation and scale never enter the
# image cache key. The affine transform remains available to any other reader.
static func plan(record, crop = null):
	if crop != null:
		record = Crop.placed(record, crop)
	var t = record.transform
	var a = G.vector(record.bounds[record.hinge_bound_index])
	var b = G.vector(record.bounds[1 - record.hinge_bound_index])
	var along = (b - a).normalized()
	var normal = Vector2(-along.y, along.x)
	var swap = record.texture_axis == "height"
	var horizontal = G.vector(t.axis_y if swap else t.axis_x)
	var vertical = G.vector(t.axis_x if swap else t.axis_y)
	var sx = -1 if horizontal.dot(along) < 0 else 1
	var sy = -1 if vertical.dot(normal) < 0 else 1
	var origin = G.vector(t.origin)
	if sx < 0:
		origin += horizontal
	if sy < 0:
		origin += vertical
	var x = horizontal * sx
	var y = vertical * sy
	var reason = ""
	if abs(x.dot(y)) > 0.00001 * x.length() * y.length():
		reason = "SHEAR"

	return {"swap_axes": swap, "flip_x": sx < 0, "flip_y": sy < 0,
		"bounds": [G.json_point(a), G.json_point(b)], "length_grid": x.length(), "thickness_grid": y.length(),
		"transform": {"origin": G.json_point(origin), "axis_x": G.json_point(x), "axis_y": G.json_point(y)}, "reason": reason}

static func pixels(source, recipe, tint):
	var input = Image.new()
	input.copy_from(source.get_rect(Rect2(recipe.crop.x, recipe.crop.y, recipe.crop.width, recipe.crop.height)) if recipe.has("crop") else source)
	input.convert(Image.FORMAT_RGBA8)
	var width = input.get_height() if recipe.swap_axes else input.get_width()
	var height = input.get_width() if recipe.swap_axes else input.get_height()
	var output = Image.new()
	output.create(width, height, false, Image.FORMAT_RGBA8)
	input.lock()
	output.lock()
	var color = Color(tint.r, tint.g, tint.b, tint.a)
	for y in range(height):
		for x in range(width):
			var u = width - 1 - x if recipe.flip_x else x
			var v = height - 1 - y if recipe.flip_y else y
			output.set_pixel(x, y, input.get_pixel(v, u) * color if recipe.swap_axes else input.get_pixel(u, v) * color)
	input.unlock()
	output.unlock()
	return output

static func attach(record, snapshot, assets, cache, sources = {}):
	var source = sources.get(record.asset, {})
	var image = snapshot.get("pixels")
	if image == null:
		image = Image.new()
		var bytes = Marshalls.base64_to_raw(source.get("data", ""))
		var error = image.load_png_from_buffer(bytes) if source.get("format", "png") == "png" else (image.load_jpg_from_buffer(bytes) if source.format in ["jpg","jpeg"] else image.load_webp_from_buffer(bytes))
		if error != OK:
			return G.failure("PREPARED_IMAGE", "Cannot decode the source artwork")
	var cut = Crop.from_record(record, image.get_width(), image.get_height())
	if not cut.ok:
		return cut
	var p = plan(record, cut.value)
	p["crop"] = cut.value
	var origin = Metadata.origin(record, snapshot, image, p)
	var recipe = origin.transformations
	var path = snapshot.get("source_path", origin.pack_info[0].path)
	var format = snapshot.get("asset_format", source.get("format", "png"))
	var key = JSON.print([E.pixel_hash(image),p.crop,p.swap_axes,p.flip_x,p.flip_y,record.tint,format,path.get_extension().to_lower(),origin.file_hash])
	if not cache.has(key):
		var prepared = pixels(image, p, record.tint)
		var unchanged = snapshot.get("full_frame", false) and not recipe.orientation.applied and recipe.crop.code == "X" and not recipe.tint.applied and not recipe.recolor.applied
		var encoded = E.final_image(prepared, path, format, snapshot.get("original_bytes", PoolByteArray()), unchanged)
		if not encoded.ok:
			return encoded
		cache[key] = {"encoded":encoded.value,"image":prepared}
	var item = cache[key]
	var id = item.encoded.id
	if not assets.has(id):
		assets[id] = item.encoded.asset.duplicate(true)
		assets[id].erase("source_paths")
		assets[id]["hash"] = id
		assets[id]["source_origin"] = []
	Metadata.merge_origin(assets[id], origin)
	var axis = "x" if record.texture_axis == "width" else "y"
	var hinge = "A" if record.hinge_bound_index == 0 else "B"
	var source_geometry = {"axis":axis,"hinge_endpoint":hinge,"original_width":origin.width,"original_height":origin.height,"isSquareAsset":origin.width == origin.height,"isHorizontalAsset":origin.width > origin.height}
	record["source_geometry"] = source_geometry.duplicate(true)
	record.asset = id
	record.transform = p.transform
	record.bounds = p.bounds
	record.hinge_bound_index = 0
	record.texture_axis = "x"
	for field in ["tint","asset_render","hinge_offset","hinge_offset_grid","format","original_format","hash","provenance","prepared"]:
		record.erase(field)
	record.animation.erase("texture")
	var animation = record.animation.duplicate(true)
	animation["flip"] = false
	animation["strength"] = record.swing_degrees / 90.0
	animation["duration"] = 750
	if animation.type == "slide":
		animation.direction = 1
	var target = {"profile":TARGET,"problematic_import":not p.reason.empty(),"problematic_import_reason":p.reason,"asset":id,"texture_grid_size":item.image.get_height()/p.thickness_grid,
		"grid_unit_length":p.length_grid,"grid_unit_thickness":p.thickness_grid,"c_grid":[p.bounds[0].x,p.bounds[0].y,p.bounds[1].x,p.bounds[1].y],
		"source_endpoint_order":[0,1] if hinge == "A" else [1,0],"source_hinge":hinge,"source_geometry":source_geometry,
		"image_operations":{"orientation":recipe.orientation.duplicate(true)},"animation":animation,"door_type":record.door_type,
		"closed":record.closed,"locked":record.locked,"ds":1 if not record.closed else (2 if record.locked else 0)}
	record["targets"] = {"foundry":target}
	return G.success(true)
