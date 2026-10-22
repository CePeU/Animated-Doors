extends Reference

const Geometry = preload("door_geometry.gd")
const ANIMATION_TYPES = ["swing", "slide", "swivel", "ascend", "descend"]
const DOOR_STATES = ["closed", "open", "locked"]
const EDIT_FIELDS = ["hinge_endpoint", "swing_direction", "axis", "door_type", "animation_type", "door_state", "double_door", "swing_degrees", "hinge_offset_a", "hinge_offset_b"]

var data = {}
var read_only = false
var issue = ""
var opaque_data

func _init(values = {}, kind = "door"):
	opaque_data = values.duplicate(true) if values is Dictionary or values is Array else values
	if not values is Dictionary:
		read_only = true
		issue = "Invalid Animated Doors component; original data is preserved."
		return
	data = values.duplicate(true)
	if not _valid(kind):
		read_only = true
		issue = "Unsupported or invalid Animated Doors %s settings; saved data will be preserved." % kind

func _valid(kind):
	if not data.get("schema_version", 6) in [1, 2, 3, 4, 5, 6]:
		return false
	data["schema_version"] = 6
	if kind == "map":
		if not data.has("preview_animation_duration_ms"):
			data["preview_animation_duration_ms"] = 750
		if not Geometry.number(data.preview_animation_duration_ms) or data.preview_animation_duration_ms <= 0:
			return false
		if not data.has("list_layer_id"):
			data.list_layer_id = 2147483647
		# Keep a legacy source_layer_id as opaque migration information. It no
		# longer decides whether a declared asset is exported.
		var layer = data.list_layer_id
		if not (typeof(layer) == TYPE_INT or typeof(layer) == TYPE_REAL) or float(layer) != int(layer):
			return false
		if not data.has("defaults"):
			data.defaults = defaults()
		return data.defaults is Dictionary and _valid_door(data.defaults, true)
	return _valid_door(data)

static func defaults():
	return {"enabled": false, "hinge_endpoint": "begin", "swing_direction": "right", "axis": "width", "door_type": 1, "animation_type": "swing", "animation_texture": "", "door_state": "closed", "double_door": false, "swing_degrees": 90, "hinge_offset_a": 0, "hinge_offset_b": 0}

func _valid_door(values, automatic_axis = false):
	for key in defaults():
		if not values.has(key):
			values[key] = defaults()[key]
	var axes = ["width", "height", "longer", "shorter", "visible"] if automatic_axis else ["width", "height"]
	if not values.door_state in DOOR_STATES:
		return false
	if not values.door_type in [1, 2, -1] or not values.animation_type in ANIMATION_TYPES or not values.animation_texture is String or typeof(values.double_door) != TYPE_BOOL:
		return false
	for key in ["swing_degrees", "hinge_offset_a", "hinge_offset_b"]:
		if not Geometry.number(values[key]) or values[key] < 0:
			return false
		if key == "swing_degrees" and (values[key] != int(values[key]) or values[key] > 180):
			return false
	return typeof(values.enabled) == TYPE_BOOL and values.hinge_endpoint in ["begin", "end"] and values.swing_direction in ["left", "right"] and values.axis in axes

func serialize(_node):
	if read_only:
		return opaque_data.duplicate(true) if opaque_data is Dictionary or opaque_data is Array else opaque_data
	if data.has("enabled") and not data.enabled:
		return {"schema_version": 6, "enabled": false}
	var filename = texture_name(_node)
	if not filename.empty() and data.has("animation_texture"):
		data.animation_texture = filename
	return data.duplicate(true)

static func texture_name(node):
	if not is_instance_valid(node):
		return ""
	var sprite = node.get("Sprite")
	if not is_instance_valid(sprite) or not is_instance_valid(sprite.texture):
		return ""
	var texture = sprite.texture
	if texture is AtlasTexture:
		texture = texture.atlas
	return texture.resource_path.replace("\\", "/").get_file() if is_instance_valid(texture) else ""

func component_node_removed(_node):
	pass
