extends Reference

const Geometry = preload("door_geometry.gd")
const Matcher = preload("portal_matcher.gd")
const Encoder = preload("asset_encoder.gd")
const Prepared = preload("prepared_texture.gd")
const VERSION = "0.15.8"
const Metadata = preload("asset_metadata.gd")
const Crop = preload("crop_geometry.gd")
const Component = preload("door_component.gd")

static func portal_snapshots(snapshots):
	var output = []
	for snapshot in snapshots:
		if snapshot.get("source_kind", "portal") == "portal":
			output.append(snapshot)
	return output

static func assemble(native, snapshots, assets, level_id, mime, embed_assets = true):
	var portals = portal_snapshots(snapshots)
	var result = Matcher.associate(portals, native.get("portals", []))
	if not result.ok:
		return result
	var output = native.duplicate(true)
	mark_unanimated_portals(output)
	var instances = {}
	var sources = assets
	assets = {}
	var preparation_cache = {}
	var native_index = 0
	for snapshot in snapshots:
		var is_object = snapshot.get("source_kind", "portal") == "object"
		var portal = {} if is_object else output.portals[result.value[native_index]]
		if not is_object:
			native_index += 1
		var bounds = snapshot.get("bounds", portal.get("bounds"))
		var hinge = Geometry.hinge_index(bounds, snapshot.hinge)
		if not hinge.ok:
			return hinge
		var identity = str(instances.size() + 1)
		if not is_object:
			portal["animated"] = true
			portal["animated_door_id"] = identity
		var settings = Component.defaults()
		for key in snapshot.get("settings", {}):
			settings[key] = snapshot.settings[key]
		var paths = sources[snapshot.asset_id].get("source_paths", [])
		var source_path = snapshot.get("source_path", paths[0] if not paths.empty() else "")
		var filename = source_path.replace("\\", "/").get_file()
		var ppi = native.resolution.pixels_per_grid
		instances[identity] = {"source": "object" if is_object else "portal", "animated":true, "bounds": bounds.duplicate(true), "asset": snapshot.asset_id, "hinge_bound_index": hinge.value, "door_type": settings.door_type, "animation": {"type": settings.animation_type, "texture": filename, "double": settings.double_door, "direction": -1 if snapshot.direction == "left" else 1}, "swing_degrees": settings.swing_degrees, "hinge_offset": {"a": int(round(settings.hinge_offset_a * ppi / 256.0)), "b": int(round(settings.hinge_offset_b * ppi / 256.0)), "unit": "image_pixels"}, "transform": snapshot.transform.duplicate(true), "tint": snapshot.tint.duplicate()}
		instances[identity]["hinge_offset_grid"] = {"a": settings.hinge_offset_a / 256.0, "b": settings.hinge_offset_b / 256.0, "unit": "grid"}
		if snapshot.has("asset_render"):
			instances[identity]["asset_render"] = snapshot.asset_render.duplicate(true)
		var format = sources[snapshot.asset_id].get("format", "png")
		instances[identity]["format"] = format
		instances[identity]["original_format"] = source_path.get_extension().to_lower()
		instances[identity]["hash"] = snapshot.asset_id
		instances[identity]["texture_axis"] = settings.axis
		instances[identity]["closed"] = settings.door_state != "open"
		instances[identity]["locked"] = settings.door_state == "locked"
		instances[identity].animation.texture = filename.get_basename()
		var input = snapshot.duplicate()
		input["source_path"] = source_path
		var prepared = Prepared.attach(instances[identity], input, assets, preparation_cache, sources)
		if not prepared.ok:
			return prepared
	Metadata.finalize(assets, instances)
	var exported_assets = assets
	var encoded_size = 0
	for id in exported_assets:
		var asset = exported_assets[id]
		encoded_size += asset.data.length()
		if encoded_size > 268435456:
			return Geometry.failure("MEMORY_LIMIT", "Finished assets exceed the 256 MiB Base64 budget.")
		if embed_assets:
			asset["image"] = asset.data
		asset.erase("data")
	output["animated_doors"] = {"schema_version": 10, "exporter": {"id": "AnimatedDoors", "version": VERSION}, "coordinate_space": "uvtt_grid", "coordinate_basis": "map_global", "source_level_id": str(level_id), "image_mime_type": mime, "asset_mode": "embedded" if embed_assets else "reference", "assets": exported_assets, "instances": instances}
	return Geometry.success(output)

static func mark_unanimated_portals(data):
	for portal in data.get("portals", []):
		portal["animated"] = false
		portal.erase("animated_door_id")

static func non_animated_count(data):
	var count = 0
	for portal in data.get("portals", []):
		if not portal.get("animated", false):
			count += 1
	return count

static func export_counts(data):
	var counts = {"animated": data.get("animated_doors", {}).get("instances", {}).size(), "normal": non_animated_count(data)}
	for child in data.get("Levels", {}).values():
		if not child is Dictionary:
			continue
		var more = export_counts(child)
		counts.animated += more.animated
		counts.normal += more.normal
	return counts

static func _positive(value):
	return Geometry.number(value) and value > 0

static func _dimensions(value):
	return value is Dictionary and _positive(value.get("width")) and _positive(value.get("height")) and value.width == int(value.width) and value.height == int(value.height) and max(value.width,value.height) <= Encoder.MAX_DIMENSION and value.width * value.height <= Encoder.MAX_SOURCE_PIXELS

static func _rgba(value):
	if not value is Array or value.size() != 4:
		return false
	for channel in value:
		if not Geometry.number(channel) or channel < 0 or channel > 1:
			return false
	return true

static func _origin(source, asset):
	if not _dimensions(source) or not source.get("format") is String or not source.has("file_hash") or (source.file_hash != null and not _hash_id(source.file_hash)):
		return false
	if source.has("pixel_hash") and (not _hash_id(source.pixel_hash) or source.get("pixel_hash_basis") != "full_texture_rgba8_v1"):
		return false
	if not source.get("pack_info") is Array or source.pack_info.empty() or not source.get("transformations") is Dictionary:
		return false
	for info in source.pack_info:
		if not info is Dictionary or not info.get("path") is String or not Matcher.equivalent(info,Metadata.alias(info.path)):
			return false
	var t = source.transformations
	for key in ["source_frame","crop","tint","recolor","orientation"]:
		if not t.get(key) is Dictionary:
			return false
	var frame = t.source_frame
	var region = frame.get("region")
	if typeof(frame.get("region_enabled")) != TYPE_BOOL or not _dimensions(region):
		return false
	for key in ["x","y"]:
		if not Geometry.number(region.get(key)) or region[key] < 0 or region[key] != int(region[key]):
			return false
	if region.x+region.width>source.width or region.y+region.height>source.height:
		return false
	for key in ["hframes","vframes"]:
		if not _positive(frame.get(key)) or frame[key] != int(frame[key]):
			return false
	if not Geometry.number(frame.get("frame")) or frame.frame != int(frame.frame) or frame.frame < 0 or frame.frame >= frame.hframes * frame.vframes:
		return false
	var width = region.width / frame.hframes
	var height = region.height / frame.vframes
	if width != int(width) or height != int(height):
		return false
	var cut = t.crop
	if not cut.get("axis") in ["x","y"]:
		return false
	for key in ["a_pixels","b_pixels"]:
		if not Geometry.number(cut.get(key)) or cut[key] < 0 or cut[key] != int(cut[key]):
			return false
	var crop_code = "X" if cut.a_pixels == 0 and cut.b_pixels == 0 else "c%s%d-%d" % [cut.axis,cut.a_pixels,cut.b_pixels]
	if cut.get("code") != crop_code:
		return false
	if cut.axis == "x":
		width -= cut.a_pixels + cut.b_pixels
	else:
		height -= cut.a_pixels + cut.b_pixels
	var orientation = t.orientation
	for key in ["swap_axes","flip_x","flip_y","applied"]:
		if typeof(orientation.get(key)) != TYPE_BOOL:
			return false
	if orientation.get("source_axis") != cut.axis or not orientation.get("reference_endpoint") in ["A","B"] or orientation.applied != (orientation.swap_axes or orientation.flip_x or orientation.flip_y):
		return false
	if orientation.swap_axes != (cut.axis == "y") or width <= 0 or height <= 0 or asset.width != (height if orientation.swap_axes else width) or asset.height != (width if orientation.swap_axes else height):
		return false
	if not _rgba(t.tint.get("rgba")) or typeof(t.tint.get("applied")) != TYPE_BOOL or t.tint.applied != (not Matcher.equivalent(t.tint.rgba,[1,1,1,1])) or t.tint.get("code") != Metadata.color_code("t",t.tint.rgba,t.tint.applied):
		return false
	if typeof(t.recolor.get("applied")) != TYPE_BOOL or not t.recolor.get("kind") in ["plain","custom_color"] or t.recolor.applied != (t.recolor.kind == "custom_color"):
		return false
	if t.recolor.applied:
		if not _rgba(t.recolor.get("rgba")) or t.recolor.get("code") != Metadata.color_code("r",t.recolor.rgba,true):
			return false
		for key in ["min_redness","red_tolerance","min_saturation"]:
			if not Geometry.number(t.recolor.get(key)):
				return false
	elif t.recolor.get("code") != "rX":
		return false
	return true

static func validate(data, verify_images = true):
	if not data is Dictionary or not data.get("animated_doors") is Dictionary:
		return _bad("animated_doors","Missing extension")
	var ext = data.animated_doors
	if ext.get("schema_version") != 10:
		return _bad("schema_version","Expected schema 10; obsolete custom schemas are not supported")
	var children = _validate_levels(data, ext.get("image_mime_type"), verify_images, false)
	if not children.ok:
		return children
	var native = _validate_envelope(data,ext.get("image_mime_type"),verify_images)
	if not native.ok:
		return native
	if ext.get("coordinate_space") != "uvtt_grid" or ext.get("coordinate_basis") != "map_global" or not ext.get("source_level_id") is String or not ext.get("asset_mode") in ["embedded","reference"]:
		return _bad("animated_doors","Invalid coordinate/export metadata")
	if not ext.get("exporter") is Dictionary or ext.exporter.get("id") != "AnimatedDoors" or not ext.exporter.get("version") is String or not ext.get("assets") is Dictionary or not ext.get("instances") is Dictionary or ext.has("sources"):
		return _bad("animated_doors","Missing tables or invalid exporter")
	var size = 0
	for id in ext.assets:
		var asset = ext.assets[id]
		if not _hash_id(id) or not _dimensions(asset) or asset.get("hash") != id or not asset.get("format") in ["png","webp"] or asset.get("mime_type") != "image/"+asset.format or asset.get("encoding") != "base64" or typeof(asset.get("isOriginal")) != TYPE_BOOL:
			return _bad(id,"Invalid finished image descriptors")
		for obsolete in ["source_paths","origins","data"]:
			if asset.has(obsolete):
				return _bad(id,"Obsolete asset property: "+obsolete)
		if not asset.get("source_origin") is Array or asset.source_origin.empty():
			return _bad(id,"Missing source origins")
		for source in asset.source_origin:
			if not _origin(source,asset):
				return _bad(id,"Invalid source identity or resolved transformations")
		if ext.asset_mode == "reference":
			if asset.has("image"):
				return _bad(id,"Reference image payload must be omitted")
		else:
			if not asset.get("image") is String or asset.image.empty():
				return _bad(id,"Missing image payload")
			size += asset.image.length()
			if size > 268435456:
				return _bad(id,"Encoded image budget exceeded")
			if verify_images:
				var bytes = Marshalls.base64_to_raw(asset.image)
				if bytes.size() > Encoder.MAX_ASSET_BYTES or Encoder.hash_bytes(bytes) != id or Marshalls.raw_to_base64(bytes) != asset.image:
					return _bad(id,"Corrupt image bytes or incorrect final hash")
				var image = Image.new()
				var error = image.load_png_from_buffer(bytes) if asset.format == "png" else image.load_webp_from_buffer(bytes)
				if error != OK or image.get_width() != asset.width or image.get_height() != asset.height:
					return _bad(id,"Payload dimensions/format disagree")
	var expected_assets = ext.assets.duplicate(true)
	Metadata.finalize(expected_assets,{})
	for id in ext.assets:
		for field in ["isOriginal","naming","filename","filename_collision"]:
			if not Matcher.equivalent(ext.assets[id].get(field),expected_assets[id][field]):
				return _bad(id,"Inconsistent canonical "+field)
	var used = {}
	var linked = {}
	for id in ext.instances:
		if not ext.instances[id] is Dictionary:
			return _bad(id,"Expected an instance object")
	for portal in data.portals:
		if portal.has("animated") and typeof(portal.animated) != TYPE_BOOL:
			return _bad("portals","Animated marker must be Boolean")
		if portal.get("animated",false):
			var id = portal.get("animated_door_id")
			if not id is String or linked.has(id) or not ext.instances.has(id) or ext.instances[id].get("source") != "portal":
				return _bad("portals","Missing/duplicate animation link")
			linked[id] = true
		elif portal.has("animated_door_id"):
			return _bad("portals","Nonanimated portal has animation link")
	for id in ext.instances:
		var r = ext.instances[id]
		if not id is String or id.empty() or not r is Dictionary or typeof(r.get("animated")) != TYPE_BOOL or r.animated != true or not r.get("source") in ["portal","object"] or not ext.assets.has(r.get("asset")):
			return _bad(id,"Invalid animated instance")
		if (r.source == "portal") != linked.has(id):
			return _bad(id,"Incorrect native portal link")
		for obsolete in ["prepared","provenance","source_ref","origin_ref","tint","asset_render","hinge_offset","hinge_offset_grid"]:
			if r.has(obsolete):
				return _bad(id,"Obsolete instance property: "+obsolete)
		if not r.get("transform") is Dictionary or not r.get("bounds") is Array or r.bounds.size()!=2 or r.get("hinge_bound_index") != 0 or r.get("texture_axis") != "x":
			return _bad(id,"Invalid finished-image geometry")
		for key in ["origin","axis_x","axis_y"]:
			if not Geometry.point(r.transform.get(key)):
				return _bad(id,"Nonfinite transform")
		var x = Geometry.vector(r.transform.axis_x)
		var y = Geometry.vector(r.transform.axis_y)
		if abs(x.cross(y)) < 0.000000000001:
			return _bad(id,"Singular transform")
		var bounds = Geometry.artwork_bounds(r.transform)
		for i in range(2):
			if not Geometry.near(r.bounds[i],bounds[i]):
				return _bad(id,"Bounds do not describe the finished artwork")
		if typeof(r.get("closed")) != TYPE_BOOL or typeof(r.get("locked")) != TYPE_BOOL or (r.locked and not r.closed):
			return _bad(id,"Invalid Boolean door state")
		if not Geometry.number(r.get("door_type")) or not r.door_type in [1,2,-1] or not Geometry.number(r.get("swing_degrees")) or r.swing_degrees != int(r.swing_degrees) or r.swing_degrees<0 or r.swing_degrees>180:
			return _bad(id,"Invalid door type/amount")
		var animation = r.get("animation")
		if not animation is Dictionary or not animation.get("type") in Component.ANIMATION_TYPES or typeof(animation.get("double")) != TYPE_BOOL or not Geometry.number(animation.get("direction")) or not animation.direction in [-1,1] or animation.has("texture"):
			return _bad(id,"Invalid portable animation")
		if not r.get("targets") is Dictionary or not r.targets.get("foundry") is Dictionary:
			return _bad(id,"Missing compiled target")
		var f = r.targets.foundry
		var asset = ext.assets[r.asset]
		used[r.asset] = true
		if f.get("profile") != Prepared.TARGET or f.get("asset") != r.asset or f.has("supported") or f.has("reason"):
			return _bad(id,"Invalid target profile/image")
		var shear = abs(x.dot(y)) > 0.00001*x.length()*y.length()
		if typeof(f.get("problematic_import")) != TYPE_BOOL or f.problematic_import != shear or f.get("problematic_import_reason") != ("SHEAR" if shear else ""):
			return _bad(id,"Incorrect nonfatal target diagnostic")
		for pair in [["grid_unit_length",x.length()],["grid_unit_thickness",y.length()],["texture_grid_size",asset.height/y.length()]]:
			if not _positive(f.get(pair[0])) or abs(f[pair[0]]-pair[1])>0.00001*max(1.0,pair[1]):
				return _bad(id,"Incorrect final target "+pair[0])
		if not Matcher.equivalent(f.get("c_grid"),[r.bounds[0].x,r.bounds[0].y,r.bounds[1].x,r.bounds[1].y],0.00001):
			return _bad(id,"Incorrect target endpoints")
		if not shear and abs(Geometry.vector(r.bounds[0]).distance_to(Geometry.vector(r.bounds[1]))-f.grid_unit_length)>0.00001*max(1.0,f.grid_unit_length):
			return _bad(id,"Target length does not match endpoints")
		for field in ["isOriginal","format","mime_type","width","height"]:
			if f.get(field) != asset[field]:
				return _bad(id,"Target descriptor differs from asset")
		for field in Metadata.NAMING_FIELDS:
			if not f.get("naming") is Dictionary or f.naming.get(field) != asset.naming[field]:
				return _bad(id,"Target canonical name differs from asset")
		if typeof(f.get("closed")) != TYPE_BOOL or typeof(f.get("locked")) != TYPE_BOOL or not Geometry.number(f.get("ds")) or f.closed != r.closed or f.locked != r.locked or f.ds != (1 if not r.closed else (2 if r.locked else 0)) or f.get("door_type") != r.door_type:
			return _bad(id,"Target state/type disagree")
		var compiled = animation.duplicate(true)
		compiled["flip"] = false
		compiled["duration"] = 750
		compiled["strength"] = r.swing_degrees/90.0
		compiled["texture"] = asset.naming.short_filename
		compiled["texture_hash"] = asset.naming.hash_filename.get_basename()
		compiled["extension"] = asset.format
		if compiled.type == "slide":
			compiled.direction = 1
		if not Matcher.equivalent(f.get("animation"),compiled,0.00001):
			return _bad(id,"Target animation disagrees")
		var g = r.get("source_geometry")
		if not g is Dictionary or not g.get("axis") in ["x","y"] or not g.get("hinge_endpoint") in ["A","B"] or not _positive(g.get("original_width")) or not _positive(g.get("original_height")):
			return _bad(id,"Missing original layout facts")
		if typeof(g.get("isSquareAsset"))!=TYPE_BOOL or typeof(g.get("isHorizontalAsset"))!=TYPE_BOOL or g.isSquareAsset != (g.original_width == g.original_height) or g.isHorizontalAsset != (g.original_width > g.original_height):
			return _bad(id,"Shape must describe full original texture")
		if not Matcher.equivalent(f.get("source_geometry"),g) or f.get("source_hinge")!=g.hinge_endpoint or not Matcher.equivalent(f.get("source_endpoint_order"),[0,1] if g.hinge_endpoint=="A" else [1,0]):
			return _bad(id,"Incorrect source endpoint diagnostics")
		if not f.get("image_operations") is Dictionary or f.image_operations.size()!=1:
			return _bad(id,"Target contains image recipes instead of concise orientation")
		var matched = false
		for source in asset.source_origin:
			var orientation = source.transformations.orientation
			matched = matched or (source.width==g.original_width and source.height==g.original_height and orientation.source_axis==g.axis and orientation.reference_endpoint==g.hinge_endpoint and Matcher.equivalent(orientation,f.image_operations.get("orientation")))
		if not matched:
			return _bad(id,"Target facts do not match any actual derivation")
	if used.size()!=ext.assets.size():
		return _bad("assets","Unused image payload")
	return Geometry.success(true)

static func _validate_envelope(data, mime, verify_images):
	if not data is Dictionary:
		return _bad("root", "Expected an object")
	var has_level_metadata = data.has("level_name") or data.has("bottom") or data.has("top")
	if has_level_metadata and (not data.get("level_name") is String or not preload("level_elevation.gd").integer(data.get("bottom")) or not preload("level_elevation.gd").integer(data.get("top")) or data.top < data.bottom):
		return _bad("level", "Expected a level name and ordered integer bottom/top values")
	for key in ["format", "resolution", "line_of_sight", "objects_line_of_sight", "portals", "environment", "lights", "image"]:
		if not data.has(key):
			return _bad(key, "Missing required field")
	# The native C# exporter supplies Single(0.3), which becomes a slightly
	# different double in GDScript. Preserve the value and accept float rounding.
	if not Geometry.number(data.format) or abs(float(data.format) - 0.3) > 0.000001 or not data.portals is Array or not data.resolution is Dictionary:
		return _bad("root", "Invalid native field types")
	for key in ["line_of_sight", "objects_line_of_sight", "lights"]:
		if not data[key] is Array:
			return _bad(key, "Expected an array")
	if not data.environment is Dictionary or not data.image is String:
		return _bad("image/environment", "Missing native image or environment")
	var resolution = data.resolution
	if not Geometry.point(resolution.get("map_origin")) or not Geometry.point(resolution.get("map_size")):
		return _bad("resolution", "Invalid origin or size")
	if not Geometry.number(resolution.get("pixels_per_grid")) or resolution.pixels_per_grid <= 0 or resolution.map_size.x <= 0 or resolution.map_size.y <= 0:
		return _bad("resolution", "Nonpositive resolution")
	if not mime in ["image/png","image/jpg","image/jpeg","image/webp"]:
		return _bad("image_mime_type", "Unsupported UVTT background")
	for portal in data.portals:
		if not portal is Dictionary or not portal.get("bounds") is Array or portal.bounds.size() != 2:
			return _bad("portals", "Expected native portal geometry")
		for point in portal.bounds:
			if not Geometry.point(point):
				return _bad("portals", "Invalid bounds")
	if verify_images and not data.image.empty():
		var bytes = Marshalls.base64_to_raw(data.image)
		if Marshalls.raw_to_base64(bytes) != data.image:
			return _bad("image", "Invalid Base64")
		var image = Image.new()
		var error = image.load_png_from_buffer(bytes) if mime == "image/png" else (image.load_jpg_from_buffer(bytes) if mime in ["image/jpg", "image/jpeg"] else image.load_webp_from_buffer(bytes))
		if error != OK:
			return _bad("image", "Background cannot be decoded")
		var expected = Geometry.vector(resolution.map_size) * resolution.pixels_per_grid
		if abs(image.get_width()-expected.x)>1.0 or abs(image.get_height()-expected.y)>1.0:
			return _bad("resolution", "Background dimensions disagree with grid resolution")
	return Geometry.success(true)

static func validate_native(data, mime, verify_images = true):
	if not data is Dictionary or data.has("animated_doors"):
		return _bad("root", "Expected native UVTT without animation data")
	var children = _validate_levels(data, mime, verify_images, true)
	if not children.ok:
		return children
	var checked = _validate_envelope(data, mime, verify_images)
	if not checked.ok:
		return checked
	for portal in data.portals:
		if portal.has("animated_door_id") or portal.get("animated",false):
			return _bad("portals", "Baked export cannot contain animation links")
	return Geometry.success(true)

static func _validate_levels(data, mime, verify_images, baked):
	if not data.has("Levels"):
		return Geometry.success(true)
	if not data.Levels is Dictionary:
		return _bad("Levels", "Expected numbered level objects")
	var numbered = data.Levels.duplicate()
	for field in ["multi_file", "map_name", "export_timestamp"]:
		numbered.erase(field)
	if data.Levels.has("multi_file") or data.Levels.has("map_name") or data.Levels.has("export_timestamp"):
		if not data.Levels.get("multi_file") is bool or not data.Levels.get("map_name") is String or not data.Levels.get("export_timestamp") is String or data.Levels.export_timestamp.empty():
			return _bad("Levels", "Invalid level export metadata")
		if data.Levels.multi_file and not numbered.empty():
			return _bad("Levels", "Separate level files cannot contain other maps")
	for i in range(1, numbered.size() + 1):
		var child = data.Levels.get(str(i))
		if not child is Dictionary or child.has("Levels"):
			return _bad("Levels", "Expected consecutive level numbers without nested levels")
		var checked = validate_native(child, mime, verify_images) if baked else validate(child, verify_images)
		if not checked.ok:
			return _bad("Levels/" + str(i), checked.message)
	return Geometry.success(true)

static func _hash_id(value):
	if not value is String or value.length() != 71 or not value.begins_with("sha256:"):
		return false
	for i in range(7, 71):
		if not value.substr(i, 1) in "0123456789abcdef":
			return false
	return true

static func _bad(path, message):
	return Geometry.failure("INVALID_EXPORT", "%s: %s" % [path, message])
