extends Reference

const E = preload("asset_encoder.gd")
const M = preload("portal_matcher.gd")
const NAMING_FIELDS = ["hash", "asset_name", "file_extension", "short_filename", "readable_filename", "hash_filename"]

static func alias(path):
	var source = E.source_info(path, "", "")
	return {"name": source.name if not source.name.empty() else "door", "path": path, "package_id": source.package_id}

static func color_code(prefix, rgba, applied):
	var bytes = PoolByteArray()
	for channel in rgba:
		bytes.append(int(round(channel*255)))
	return prefix + (bytes.hex_encode().to_upper() if applied else "X")

static func origin(record, snapshot, image, recipe):
	var p = snapshot.get("provenance", {})
	var path = snapshot.get("source_path", p.get("path", ""))
	var render = record.get("asset_render", {})
	var width = int(p.get("source_width", image.get_width()))
	var height = int(p.get("source_height", image.get_height()))
	var frame = snapshot.get("source_frame", {"region_enabled": render.get("region_enabled", false), "region": render.get("region", {"x":0,"y":0,"width":width,"height":height}), "hframes":render.get("hframes",1), "vframes":render.get("vframes",1), "frame":render.get("frame",0)})
	if not frame.region_enabled:
		frame.region = {"x":0,"y":0,"width":width,"height":height}
	var cut = recipe.crop
	var axis = "x" if record.texture_axis == "width" else "y"
	var a = cut.x if axis == "x" else cut.y
	var b = (cut.source_width - cut.width - a) if axis == "x" else (cut.source_height - cut.height - a)
	var rgba = [record.tint.r, record.tint.g, record.tint.b, record.tint.a]
	var tinted = not M.equivalent(rgba,[1,1,1,1])
	var material = render.get("material", {"kind":"plain"})
	var recolor = {"applied": material.get("kind") == "custom_color", "kind":material.get("kind","plain"), "code":"rX"}
	if recolor.applied:
		recolor["rgba"] = material.tint.duplicate()
		recolor.code = color_code("r", material.tint, true)
		for key in ["min_redness", "red_tolerance", "min_saturation"]:
			recolor[key] = material[key]
	var orientation = {"swap_axes":recipe.swap_axes,"flip_x":recipe.flip_x,"flip_y":recipe.flip_y,"applied":recipe.swap_axes or recipe.flip_x or recipe.flip_y,"source_axis":axis,"reference_endpoint":"A" if record.hinge_bound_index == 0 else "B"}
	var result = {"file_hash":p.get("source_hash"),"format":path.get_extension().to_lower(),"width":width,"height":height,"pack_info":[alias(path)],"transformations":{
		"source_frame":frame.duplicate(true), "crop":{"axis":axis,"a_pixels":a,"b_pixels":b,"code":"X" if a == 0 and b == 0 else "c%s%d-%d" % [axis,a,b]},
		"tint":{"applied":tinted,"rgba":rgba,"code":color_code("t",rgba,tinted)},"recolor":recolor,"orientation":orientation}}
	if p.has("source_pixel_hash"):
		result["pixel_hash"] = p.source_pixel_hash
		result["pixel_hash_basis"] = "full_texture_rgba8_v1"
	if result.file_hash == null and path.empty():
		# No file path identifies procedural/unreadable originals. Keep an
		# export-local texture context, rather than equating null identities.
		result["source_context"] = snapshot.get("source_context",snapshot.get("id","unverified"))
	return result

static func merge_origin(asset, candidate):
	var identity = candidate.duplicate(true)
	identity.erase("pack_info")
	for existing in asset.source_origin:
		var compare = existing.duplicate(true)
		compare.erase("pack_info")
		if M.equivalent(compare, identity, 0.0):
			# Unknown file identities may merge repeated paths, never different paths.
			if candidate.file_hash == null and existing.pack_info[0].path != candidate.pack_info[0].path:
				continue
			for item in candidate.pack_info:
				if not item in existing.pack_info:
					existing.pack_info.append(item.duplicate(true))
			return
	asset.source_origin.append(candidate.duplicate(true))

static func naming(id, format, source, info):
	var t = source.transformations
	var stem = "%s_%s_%s_%s_%s" % [info.name, t.crop.code, t.tint.code, t.recolor.code, info.package_id]
	var orientation = t.orientation.reference_endpoint
	var short_name = stem + "_" + orientation
	return {"hash":id.trim_prefix("sha256:"),"asset_name":info.name,"file_extension":format,"short_filename":short_name,"readable_filename":short_name+"."+format,
		"hash_filename":info.name+"_"+id.trim_prefix("sha256:")+"."+format,
		"package_id":info.package_id,"orientation_code":orientation,"crop_code":t.crop.code,"tint_code":t.tint.code,"recolor_code":t.recolor.code}

static func finalize(assets, instances):
	var filenames = {}
	for id in assets:
		var asset = assets[id]
		asset["isOriginal"] = false
		var chosen = null
		var chosen_path = ""
		for source in asset.source_origin:
			asset.isOriginal = asset.isOriginal or source.file_hash == id
			for info in source.pack_info:
				var candidate = naming(id, asset.format, source, info)
				if chosen == null or candidate.package_id > chosen.package_id or (candidate.package_id == chosen.package_id and (candidate.readable_filename < chosen.readable_filename or (candidate.readable_filename == chosen.readable_filename and info.path < chosen_path))):
					chosen = candidate
					chosen_path = info.path
		asset["naming"] = chosen
		if not filenames.has(chosen.readable_filename):
			filenames[chosen.readable_filename] = []
		filenames[chosen.readable_filename].append(id)
	for id in assets:
		var asset = assets[id]
		asset["filename_collision"] = filenames[asset.naming.readable_filename].size() > 1
		asset["filename"] = asset.naming.hash_filename if asset.filename_collision else asset.naming.readable_filename
	for record in instances.values():
		var target = record.targets.foundry
		var asset = assets[target.asset]
		target["naming"] = {}
		for field in NAMING_FIELDS:
			target.naming[field] = asset.naming[field]
		target.animation["texture"] = asset.naming.short_filename
		target.animation["texture_hash"] = asset.naming.hash_filename.get_basename()
		target.animation["extension"] = asset.format
		for field in ["isOriginal","format","mime_type","width","height"]:
			target[field] = asset[field]
