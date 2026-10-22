extends Reference

const Geometry = preload("door_geometry.gd")
const MAX_DIMENSION = 16384
const MAX_ASSET_BYTES = 67108864
const MAX_SOURCE_PIXELS = 16777216

static func hash_bytes(bytes):
	var hashing = HashingContext.new()
	if hashing.start(HashingContext.HASH_SHA256) != OK or hashing.update(bytes) != OK:
		return ""
	return "sha256:" + hashing.finish().hex_encode()

static func encode_image(source, source_path = "", requested_format = "original"):
	if source == null or source.is_empty():
		return Geometry.failure("MISSING_TEXTURE", "The door texture has no readable pixels.")
	if source.get_width() * source.get_height() > MAX_SOURCE_PIXELS:
		return Geometry.failure("ASSET_TOO_LARGE", "A door source may contain at most 16777216 pixels (64 MiB as RGBA8).")
	var img = Image.new()
	img.copy_from(source)
	if img.is_compressed() and img.decompress() != OK:
		return Geometry.failure("COMPRESSED_TEXTURE", "This texture cannot be decompressed.")
	if img.get_width() > MAX_DIMENSION or img.get_height() > MAX_DIMENSION:
		return Geometry.failure("ASSET_TOO_LARGE", "Door textures must not exceed 16384 pixels per side.")
	img.convert(Image.FORMAT_RGBA8)
	var original_format = source_path.get_extension().to_lower()
	var format = original_format if requested_format == "original" else requested_format
	if requested_format == "original" and not format in ["png", "webp"]:
		format = "png"
	var encoded = encode_pixels(img, format)
	if not encoded.ok:
		return encoded
	var bytes = encoded.value
	if bytes.empty() or bytes.size() > MAX_ASSET_BYTES:
		return Geometry.failure("ASSET_ENCODING", "Door image encoding failed or exceeds the 64 MiB limit.")
	var id = hash_bytes(bytes)
	if id.empty():
		return Geometry.failure("HASH", "Could not hash the embedded image.")
	return Geometry.success({"id": id, "asset": {"mime_type": "image/" + format, "format": format, "encoding": "base64", "width": img.get_width(), "height": img.get_height(), "data": Marshalls.raw_to_base64(bytes), "source_paths": [source_path] if not source_path.empty() else []}})

static func encode_pixels(img, format):
	if format == "png":
		return Geometry.success(img.save_png_to_buffer())
	var method = {"webp": "save_webp"}.get(format, "")
	if method.empty() or not img.has_method(method):
		return Geometry.failure("ASSET_CODEC", "This engine cannot encode door assets as " + format + ". Select PNG in global settings.")
	# Dungeondraft's Godot fork exposes these encoders only as file writers.
	var folder = Engine.get_meta("AnimatedDoors.encoding_temp") if Engine.has_meta("AnimatedDoors.encoding_temp") else "user://"
	var path = folder.plus_file("animated-doors-asset-" + str(OS.get_ticks_usec()) + "-" + str(img.get_instance_id()) + "." + format)
	var directory = Directory.new()
	if directory.file_exists(path):
		return Geometry.failure("ASSET_CODEC", "Temporary asset path already exists.")
	var error = img.call(method, path, 1.0)
	var file = File.new()
	var bytes = PoolByteArray()
	if error == OK and file.open(path, File.READ) == OK:
		if file.get_len() <= MAX_ASSET_BYTES:
			bytes = file.get_buffer(file.get_len())
		file.close()
	if directory.file_exists(path):
		directory.remove(path)
	if bytes.empty():
		return Geometry.failure("ASSET_CODEC", "Could not encode door asset as " + format)
	return Geometry.success(bytes)

static func source_info(path, format, image_hash):
	var normalized = path.replace("\\", "/")
	var package_id = ""
	if normalized.begins_with("res://packs/"):
		package_id = normalized.trim_prefix("res://packs/").split("/")[0]
	return {"name": normalized.get_file().get_basename(), "path": path, "package_id": package_id, "format": format, "original_format": normalized.get_extension().to_lower(), "hash": image_hash}

static func material_profile(sprite):
	if sprite.normal_map != null:
		return Geometry.failure("UNSUPPORTED_MATERIAL", "Normal-map doors are unsupported; remove this door assignment.")
	# Parent materials affect a Sprite only along use_parent_material links.
	var source = sprite
	while source is CanvasItem and source.use_parent_material:
		source = source.get_parent()
	var material = source.material if source is CanvasItem else null
	if material == null:
		return Geometry.success({"kind": "plain"})
	if material is ShaderMaterial and material.shader != null:
		# Fingerprints of the shaders shipped with Dungeondraft 1.2.0.1.
		# Check code because another mod may replace the same resource path.
		var signature = material.shader.code.replace("\r\n", "\n").sha256_text()
		if signature == "aafe239a9c2c56d829bc331cc61fea0f1710c8b7cd7468cd9b5156a1f15135fb":
			return Geometry.success({"kind": "plain"})
		if signature == "84d58c89b8a2a9652e9d5099a1b4f60e48f0a855800ce8094849d1d3a79470be":
			var tint = material.get_shader_param("tint_r")
			if not tint is Color:
				return Geometry.failure("CUSTOM_COLOR", "The native custom-color material has no readable tint.")
			for channel in [tint.r, tint.g, tint.b, tint.a]:
				if not Geometry.number(channel) or channel < 0 or channel > 1:
					return Geometry.failure("CUSTOM_COLOR", "Custom-color tint must be finite and between zero and one.")
			var profile = {"kind": "custom_color", "tint": [tint.r, tint.g, tint.b, tint.a]}
			var defaults = {"min_redness": 0.1, "red_tolerance": 0.04, "min_saturation": 0.0}
			for key in ["min_redness", "red_tolerance", "min_saturation"]:
				var value = material.get_shader_param(key)
				# Godot 3.4 returns null for uniforms left at shader defaults.
				if value == null:
					value = defaults[key]
				if not Geometry.number(value):
					return Geometry.failure("CUSTOM_COLOR", "Unreadable custom-color parameter: " + key)
				profile[key] = value
			return Geometry.success(profile)
	var path = material.resource_path
	return Geometry.failure("UNSUPPORTED_MATERIAL", "Unsupported active material on %s (%s). Remove this visual effect or remove the door assignment." % [source.name, path if not path.empty() else material.get_class()])

static func bake_custom_color(img, profile):
	img.convert(Image.FORMAT_RGBA8)
	img.lock()
	var tint = Color(profile.tint[0], profile.tint[1], profile.tint[2], profile.tint[3])
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var pixel = img.get_pixel(x, y)
			var average = (pixel.g + pixel.b) * 0.5
			if abs(pixel.g - pixel.b) <= profile.red_tolerance and 1.0 - average >= profile.min_saturation and pixel.r - average > profile.min_redness:
				var color = Color(pixel.r * tint.r, pixel.r * tint.g, pixel.r * tint.b, pixel.a * tint.a)
				var brightness = pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114
				if brightness > 0.333:
					color = color.linear_interpolate(Color(1, 1, 1, color.a), brightness - 0.333)
				img.set_pixel(x, y, color)
	img.unlock()

static func read_sprite(sprite, checked_profile = null):
	var read = sprite_pixels(sprite)
	if not read.ok:
		return read
	var checked = material_profile(sprite) if checked_profile == null else checked_profile
	if not checked.ok:
		return checked
	if checked.value.kind == "custom_color":
		bake_custom_color(read.value.image, checked.value)
	read.value["pixel_hash"] = pixel_hash(read.value.image)
	return read

static func from_sprite(sprite, checked_profile = null, requested_format = "original"):
	var read = read_sprite(sprite, checked_profile)
	if not read.ok:
		return read
	var result = encode_image(read.value.image, sprite.texture.resource_path, requested_format)
	if result.ok:
		result.value["pixels"] = read.value.image
		result.value["pixel_hash"] = read.value.pixel_hash
		result.value["provenance"] = read.value.provenance
	return result

static func final_image(image, path, requested_format, original_bytes = PoolByteArray(), unchanged = false):
	var format = path.get_extension().to_lower() if requested_format == "original" else requested_format
	if requested_format == "original" and not format in ["png", "webp"]:
		format = "png"
	if unchanged and not original_bytes.empty() and path.get_extension().to_lower() == format:
		# Verify decoded pixels too: a packed texture can differ from its file.
		var decoded = Image.new()
		var error = decoded.load_png_from_buffer(original_bytes) if format == "png" else decoded.load_webp_from_buffer(original_bytes)
		if error == OK and pixel_hash(decoded) == pixel_hash(image):
			var id = hash_bytes(original_bytes)
			return Geometry.success({"id":id,"asset":{"format":format,"mime_type":"image/"+format,"encoding":"base64","width":image.get_width(),"height":image.get_height(),"data":Marshalls.raw_to_base64(original_bytes)}})
	return encode_image(image, path, format)

static func pixel_hash(image):
	var rgba = Image.new()
	rgba.copy_from(image)
	rgba.convert(Image.FORMAT_RGBA8)
	rgba.clear_mipmaps()
	# Versioned ASCII header, decimal dimensions, LF; then row-major RGBA8.
	var bytes = ("AD-RGBA8-v1\n%d\n%d\n" % [rgba.get_width(), rgba.get_height()]).to_utf8()
	bytes.append_array(rgba.get_data())
	return hash_bytes(bytes)

static func sprite_pixels(sprite):
	if not is_instance_valid(sprite) or not sprite is Sprite or sprite.texture == null:
		return Geometry.failure("MISSING_SPRITE", "A visible Sprite texture is required.")
	# AtlasTexture margins and repeat behavior require separate placement rules.
	if sprite.texture is AtlasTexture:
		return Geometry.failure("ATLAS_TEXTURE", "AtlasTexture doors are unsupported in this build; opt this door out.")
	if sprite.texture.get_width() * sprite.texture.get_height() > MAX_SOURCE_PIXELS:
		return Geometry.failure("ASSET_TOO_LARGE", "Door source texture exceeds the 16777216-pixel readback limit.")
	var original = sprite.texture.get_data()
	if original == null or original.is_empty():
		return Geometry.failure("MISSING_TEXTURE", "The packed texture cannot be read.")
	var img = Image.new()
	img.copy_from(original)
	if img.is_compressed() and img.decompress() != OK:
		return Geometry.failure("COMPRESSED_TEXTURE", "This packed texture cannot be decompressed.")
	var region = sprite.region_rect if sprite.region_enabled else Rect2(Vector2.ZERO, img.get_size())
	if sprite.hframes != 1 or sprite.vframes != 1:
		var size = region.size / Vector2(sprite.hframes, sprite.vframes)
		region = Rect2(region.position + Vector2(sprite.frame_coords) * size, size)
	if not Rect2(Vector2.ZERO, img.get_size()).encloses(region) or region.size.x <= 0 or region.size.y <= 0:
		return Geometry.failure("TEXTURE_REGION", "A repeated or out-of-bounds texture region is unsupported.")
	if region.position != region.position.floor() or region.size != region.size.floor():
		return Geometry.failure("TEXTURE_REGION", "Fractional texture regions are unsupported.")
	var cropped = img.get_rect(region)
	var file_hash = null
	var original_bytes = PoolByteArray()
	var file = File.new()
	if not sprite.texture.resource_path.empty() and file.open(sprite.texture.resource_path, File.READ) == OK:
		if file.get_len() <= MAX_ASSET_BYTES:
			original_bytes = file.get_buffer(file.get_len())
			file_hash = hash_bytes(original_bytes)
		file.close()
	return Geometry.success({"image": cropped, "original_bytes":original_bytes,"full_frame":region == Rect2(Vector2.ZERO,img.get_size()), "source_frame":{"region_enabled":sprite.region_enabled,"region":{"x":(sprite.region_rect.position.x if sprite.region_enabled else 0),"y":(sprite.region_rect.position.y if sprite.region_enabled else 0),"width":(sprite.region_rect.size.x if sprite.region_enabled else img.get_width()),"height":(sprite.region_rect.size.y if sprite.region_enabled else img.get_height())},"hframes":sprite.hframes,"vframes":sprite.vframes,"frame":sprite.frame}, "provenance": {"path": sprite.texture.resource_path, "source_hash": file_hash, "source_hash_basis": "file_bytes" if file_hash != null else "unavailable", "source_pixel_hash": pixel_hash(img), "source_width": img.get_width(), "source_height": img.get_height()}})
