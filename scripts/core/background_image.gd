extends Reference

# Read original encoded dimensions: Godot 3 cannot allocate images above 16384
# per side, even when the host's Skia renderer encoded them successfully.
static func dimensions(bytes, mime):
	if mime == "image/png":
		if bytes.size() < 45 or bytes.subarray(0, 7) != PoolByteArray([137,80,78,71,13,10,26,10]) or bytes.subarray(12,15).get_string_from_ascii() != "IHDR":
			return Vector2.ZERO
		if bytes.subarray(bytes.size()-8, bytes.size()-5).get_string_from_ascii() != "IEND":
			return Vector2.ZERO
		return Vector2(_u32(bytes, 16), _u32(bytes, 20))
	if mime in ["image/jpg", "image/jpeg"]:
		if bytes.size() < 4 or bytes[0] != 255 or bytes[1] != 216 or bytes[bytes.size()-2] != 255 or bytes[bytes.size()-1] != 217:
			return Vector2.ZERO
		var offset = 2
		while offset + 3 < bytes.size():
			if bytes[offset] != 255:
				return Vector2.ZERO
			while offset < bytes.size() and bytes[offset] == 255:
				offset += 1
			if offset + 2 >= bytes.size():
				return Vector2.ZERO
			var marker = bytes[offset]
			offset += 1
			var length = int(bytes[offset])*256 + int(bytes[offset+1])
			if length < 2 or offset + length > bytes.size():
				return Vector2.ZERO
			if marker in [192,193,194,195,197,198,199,201,202,203,205,206,207]:
				if length < 8:
					return Vector2.ZERO
				return Vector2(int(bytes[offset+5])*256 + int(bytes[offset+6]), int(bytes[offset+3])*256 + int(bytes[offset+4]))
			if marker in [218,217]:
				return Vector2.ZERO
			offset += length
	return Vector2.ZERO

static func _u32(bytes, offset):
	return int(bytes[offset])*16777216 + int(bytes[offset+1])*65536 + int(bytes[offset+2])*256 + int(bytes[offset+3])

static func inspect(bytes, mime):
	var size = dimensions(bytes, mime)
	if mime in ["image/png", "image/jpg", "image/jpeg"] and (size.x <= 0 or size.y <= 0):
		return Vector2.ZERO
	if size.x > 16384 or size.y > 16384:
		# Header validation only; decoding would exceed Godot's hard limit.
		return size if size.x > 0 and size.y > 0 else Vector2.ZERO
	var image = Image.new()
	var error = ERR_INVALID_DATA
	if mime == "image/png":
		error = image.load_png_from_buffer(bytes)
	elif mime in ["image/jpg", "image/jpeg"]:
		error = image.load_jpg_from_buffer(bytes)
	elif mime == "image/webp":
		error = image.load_webp_from_buffer(bytes)
	return image.get_size() if error == OK else Vector2.ZERO
