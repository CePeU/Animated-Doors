extends Node2D

static func vertical_movement(axis, texture_axis, kind):
	var normal = Vector2(-axis.y, axis.x)
	var up = normal if texture_axis == "height" else -normal
	return up if kind == "ascend" else -up

const Style = preload("overlay_style.gd")
var colors = Style.DEFAULTS.duplicate()

func set_colors(values):
	colors = values.duplicate()
	update()

var begin_point = Vector2.ZERO
var end_point = Vector2.ZERO
var endpoint = "begin"
var direction = "right"
var preview = false
var items = []

func show_door(a, b, hinge, swing, enabled, settings = {}, offset_scale = 1.0):
	begin_point = a
	end_point = b
	endpoint = hinge
	direction = swing
	preview = enabled
	show_many([{"a": a, "b": b, "hinge": hinge, "swing": swing, "preview": enabled, "settings": settings.duplicate(true), "offset_scale": offset_scale}])

func show_many(entries):
	items = entries
	visible = not items.empty()
	update()

func _draw():
	var zoom = get_global_transform_with_canvas().get_scale().length() / sqrt(2.0)
	var radius = 7.0 / max(zoom, 0.01)
	for item in items:
		var outline = item.get("outline", [])
		var typed = item.duplicate()
		typed["selected"] = false
		var color = outline_color(typed)
		for i in range(outline.size()):
			var a = to_local(outline[i])
			var b = to_local(outline[(i + 1) % outline.size()])
			draw_line(a, b, color, radius * 0.35, true)
			if item.get("selected", false):
				draw_line(_expanded_corner(outline, i, radius), _expanded_corner(outline, (i + 1) % outline.size(), radius), colors.selection, radius * 0.35, true)
	# Finish every guide before any endpoint icon, including overlapping doors.
	for markers_only in [false, true]:
		for item in items:
			if item.has("a"):
				_draw_door(item, radius, markers_only)

func _expanded_corner(outline, index, amount):
	var at = to_local(outline[index])
	var previous = to_local(outline[(index + outline.size() - 1) % outline.size()])
	var next = to_local(outline[(index + 1) % outline.size()])
	return at + ((at - previous).normalized() + (at - next).normalized()).normalized() * amount

func outline_color(item):
	if item.get("selected", false):
		return colors.selection
	if not item.get("declared", false):
		return Color(0.3, 0.75, 1.0)
	return colors.get({1: "door", 2: "secret", -1: "window"}.get(item.get("door_type", 1), "door"))

func _triangle(at, direction_vector, radius):
	var along = direction_vector.normalized() * radius
	var normal = Vector2(-along.y, along.x)
	draw_colored_polygon(PoolVector2Array([at + along, at - along + normal, at - along - normal]), colors.triangle)

func _arc(pivot, tip, angle, radius, color):
	var last = tip
	for i in range(1, 33):
		var next = pivot + (tip - pivot).rotated(angle * i / 32.0)
		draw_line(last, next, color, radius * 0.2, true)
		last = next
	draw_line(pivot, last, color, radius * 0.3, true)

func preview_color(state):
	return colors.get({"locked": "locked_swing", "open": "open_swing"}.get(state, "swing"))

func _draw_door(item, radius, markers_only):
	var a = to_local(item.a)
	var b = to_local(item.b)
	var settings = item.get("settings", {})
	var preview_color = preview_color(settings.get("door_state", "closed"))
	var kind = settings.get("animation_type", "swing")
	var double_door = settings.get("double_door", false)
	var axis = (b - a).normalized()
	var normal = Vector2(-axis.y, axis.x)
	var pixel_scale = item.get("offset_scale", 1.0)
	var offset_a = settings.get("hinge_offset_a", 0) * pixel_scale
	var offset_b = settings.get("hinge_offset_b", 0) * pixel_scale
	var inner_a = to_local(item.a + (item.b - item.a).normalized() * offset_a)
	var inner_b = to_local(item.b - (item.b - item.a).normalized() * offset_b)
	var midpoint = (inner_a + inner_b) * 0.5
	var hinge = inner_a if item.hinge == "begin" else inner_b
	var free_end = inner_b if item.hinge == "begin" else inner_a
	if markers_only:
		if kind == "swing":
			if item.hinge == "begin":
				_triangle(a, axis, radius)
			if item.hinge != "begin":
				draw_circle(b, radius, colors.circle)
		elif kind == "slide":
			_triangle(a, -axis, radius)
			draw_circle(b, radius, colors.circle)
			draw_circle(a if item.hinge == "begin" else b, radius * 0.35, colors.hinge)
		else:
			var inward = kind in ["swivel", "descend"]
			_triangle(a, axis if inward else -axis, radius)
			_triangle(b, -axis if inward else axis, radius)
			draw_circle(a if item.hinge == "begin" else b, radius * 0.35, colors.hinge)
			if kind == "swivel":
				draw_circle(midpoint, radius * 0.7, colors.pivot)
			elif kind in ["ascend", "descend"]:
				draw_rect(Rect2(midpoint - Vector2.ONE * radius * 0.7, Vector2.ONE * radius * 1.4), colors.square)
		return
	if item.preview:
		var amount = settings.get("swing_degrees", 90)
		var angle = deg2rad(amount) * (-1 if item.swing == "left" else 1)
		if kind == "swing":
			if double_door:
				_arc(inner_a, midpoint, angle, radius, preview_color)
				_arc(inner_b, midpoint, -angle, radius, preview_color)
			else:
				_arc(hinge, free_end, angle, radius, preview_color)
		elif kind == "swivel":
			_arc(midpoint, inner_a, angle, radius, preview_color)
			_arc(midpoint, inner_b, angle, radius, preview_color)
		elif kind == "slide":
			# Opening slides toward the hinge, independently of swing handedness.
			var shift = (hinge - free_end) * (amount / 90.0)
			if double_door:
				var half_shift = (inner_a - midpoint) * (amount / 90.0)
				draw_line(inner_a + half_shift, midpoint + half_shift, preview_color, radius * 0.3, true)
				draw_line(midpoint - half_shift, inner_b - half_shift, preview_color, radius * 0.3, true)
			else:
				draw_line(inner_a + shift, inner_b + shift, preview_color, radius * 0.3, true)
		elif kind in ["ascend", "descend"]:
			# Separate movement guide; preserve the configurable central marker.
			var movement = vertical_movement(axis, settings.get("axis", "width"), kind)
			var tip = midpoint + movement * radius * 5
			draw_line(midpoint + movement * radius * 2, tip, preview_color, radius * 0.3, true)
			draw_line(tip, tip - movement * radius + axis * radius, preview_color, radius * 0.3, true)
			draw_line(tip, tip - movement * radius - axis * radius, preview_color, radius * 0.3, true)
	draw_line(inner_a, inner_b, colors.axis, radius / 7.0, true)
	for entry in [[inner_a, offset_a], [inner_b, offset_b]]:
		if entry[1] > 0:
			draw_line(entry[0] - normal * radius * 2, entry[0] + normal * radius * 2, colors.offset, radius / 7.0, true)
	if double_door:
		# Two small plus signs identify two leaves for every animation type,
		# including vertical types and when the preview is disabled.
		for fraction in [0.25, 0.75]:
			var at = inner_a.linear_interpolate(inner_b, fraction)
			draw_line(at - normal * radius * 0.65, at + normal * radius * 0.65, colors.axis, radius * 0.2, true)
			draw_line(at - axis * radius * 0.65, at + axis * radius * 0.65, colors.axis, radius * 0.2, true)
