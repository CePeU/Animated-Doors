extends Reference

const EPSILON = 0.00001

static func success(value):
	return {"ok": true, "value": value}

static func failure(code, message):
	return {"ok": false, "code": code, "message": message}

static func number(value):
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_REAL) and not is_nan(float(value)) and not is_inf(float(value))

static func choose_axis(mode, width, height, fallback = "width"):
	if mode in ["width", "height"]:
		return mode
	var safe_fallback = fallback if fallback in ["width", "height"] else "width"
	if not mode in ["longer", "shorter"] or not number(width) or not number(height) or width <= 0 or height <= 0:
		return safe_fallback
	if abs(width - height) <= EPSILON * max(width, height):
		return safe_fallback
	var width_longer = width > height
	return "width" if (width_longer and mode == "longer") or (not width_longer and mode == "shorter") else "height"

static func point(value):
	return value is Dictionary and number(value.get("x")) and number(value.get("y"))

static func json_point(value: Vector2):
	return {"x": value.x, "y": value.y}

static func vector(value: Dictionary):
	return Vector2(value.x, value.y)

static func near(a, b, epsilon = EPSILON):
	return point(a) and point(b) and vector(a).distance_to(vector(b)) <= epsilon

static func hinge_index(bounds, hinge):
	if not bounds is Array or bounds.size() != 2 or not point(bounds[0]) or not point(bounds[1]):
		return failure("BOUNDS", "A portal must have two numeric bounds.")
	if near(bounds[0], bounds[1]):
		return failure("ZERO_LENGTH", "A door's endpoints must be distinct.")
	for i in range(2):
		if near(bounds[i], hinge):
			return success(i)
	return failure("HINGE_MISMATCH", "The actual hinge is absent from the native portal bounds.")

static func signed_degrees(direction):
	return -90 if direction == "left" else 90

static func rotated_point(value: Vector2, hinge: Vector2, degrees: float):
	return hinge + (value - hinge).rotated(deg2rad(degrees))

static func image_transform(rect: Rect2, world_transform: Transform2D, flip_h: bool, flip_v: bool, grid_size: float):
	if grid_size <= 0 or rect.size.x <= 0 or rect.size.y <= 0:
		return failure("IMAGE_GEOMETRY", "Image dimensions and grid size must be positive.")
	var start = rect.position
	var dx = Vector2(rect.size.x, 0)
	var dy = Vector2(0, rect.size.y)
	if flip_h:
		start += dx
		dx = -dx
	if flip_v:
		start += dy
		dy = -dy
	var origin = world_transform.xform(start) / grid_size
	var axis_x = world_transform.basis_xform(dx) / grid_size
	var axis_y = world_transform.basis_xform(dy) / grid_size
	if not point(json_point(origin)) or not point(json_point(axis_x)) or not point(json_point(axis_y)):
		return failure("IMAGE_GEOMETRY", "The door transform contains a non-finite value.")
	if abs(axis_x.cross(axis_y)) < 0.000000000001:
		return failure("SINGULAR_TRANSFORM", "The door image has zero area.")
	return success({"origin": json_point(origin), "axis_x": json_point(axis_x), "axis_y": json_point(axis_y)})

static func matrix(data):
	return Transform2D(vector(data.axis_x), vector(data.axis_y), vector(data.origin))

static func artwork_bounds(transform, axis = "width"):
	var placement = matrix(transform)
	var a = Vector2(0, 0.5) if axis == "width" else Vector2(0.5, 0)
	var b = Vector2(1, 0.5) if axis == "width" else Vector2(0.5, 1)
	return [json_point(placement.xform(a)), json_point(placement.xform(b))]

static func to_pixels(p: Vector2, origin: Vector2, ppi: float, basis: String):
	return (p - origin if basis == "map_global" else p) * ppi
