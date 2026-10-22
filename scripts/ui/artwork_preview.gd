extends Node2D

const G = preload("../core/door_geometry.gd")
const E = preload("../core/asset_encoder.gd")
const Crop = preload("../core/crop_geometry.gd")
const Prepared = preload("../core/prepared_texture.gd")

signal finished
var adapter
var accessor
var active = false
var entries = []
var originals = []
var ids = []
var native_ids = []
var level_ref
var elapsed_ms = 0.0
var base_ms = 750.0
var tool_ref
var active_tool

func install(host_adapter, doors):
	adapter = host_adapter
	accessor = doors
	set_process(false)
	set_process_input(false)

static func duration(settings, baseline):
	if settings.animation_type in ["ascend","descend"]:
		return baseline * 180.0 / (180.0 if settings.swing_degrees == 0 else settings.swing_degrees)
	return baseline

static func pose(transform, pivot, settings, progress, counterpart = false):
	var result = transform
	var amount = settings.swing_degrees
	if settings.animation_type in ["swing","swivel"]:
		var angle = deg2rad(amount) * progress * (-1 if settings.swing_direction == "left" else 1) * (-1 if counterpart else 1)
		result = Transform2D(angle, pivot) * Transform2D(0,-pivot) * transform
	elif settings.animation_type == "slide":
		result.origin -= transform.x * (amount / 90.0) * progress
	return result

func play(selection, baseline):
	cancel()
	if not G.number(baseline) or baseline <= 0 or adapter.exporting():
		return G.failure("PREVIEW","Preview duration must be positive and the exporter idle.")
	var grid = float(adapter.property(adapter.host.World,"TileSize",256))
	var planned = []
	var hidden = []
	for id in selection:
		var node = adapter.resolve_node(id)
		if not is_instance_valid(node) or not accessor.has_component(node):
			continue
		var component = accessor.get_component(node)
		if component.read_only or not component.data.enabled or not adapter.visible_artwork(node):
			continue
		var sprite = adapter.property(node,"Sprite")
		var read = E.read_sprite(sprite)
		if not read.ok:
			return read
		var placement = G.image_transform(sprite.get_rect(),sprite.global_transform,sprite.flip_h,sprite.flip_v,grid)
		if not placement.ok:
			return placement
		var settings = component.data.duplicate(true)
		var tint = sprite.self_modulate
		var ancestor = sprite
		while ancestor is CanvasItem:
			tint *= ancestor.modulate
			ancestor = ancestor.get_parent()
		var record = {"transform":placement.value,"bounds":G.artwork_bounds(placement.value,settings.axis),"texture_axis":settings.axis,
			"hinge_bound_index":0 if settings.hinge_endpoint == "begin" else 1,"hinge_offset_grid":{"a":settings.hinge_offset_a/256.0,"b":settings.hinge_offset_b/256.0}}
		var cut = Crop.from_record(record,read.value.image.get_width(),read.value.image.get_height())
		if not cut.ok:
			return cut
		var recipe = Prepared.plan(record,cut.value)
		recipe["crop"] = cut.value
		var image = Prepared.pixels(read.value.image,recipe,{"r":tint.r,"g":tint.g,"b":tint.b,"a":tint.a})
		var texture = ImageTexture.new()
		texture.create_from_image(image,Texture.FLAG_FILTER)
		var transform = G.matrix(recipe.transform)
		transform.x *= grid
		transform.y *= grid
		transform.origin *= grid
		planned.append({"texture":texture,"transform":transform,"settings":settings,"duration_ms":duration(settings,baseline),"node":weakref(node),"sprite":weakref(sprite),"source_transform":sprite.global_transform})
		hidden.append({"ref":weakref(sprite),"visible":sprite.visible})
		var shadow = adapter.property(node,"shadow")
		if shadow is CanvasItem:
			hidden.append({"ref":weakref(shadow),"visible":shadow.visible})
	if planned.empty():
		return G.failure("PREVIEW","Select a visible declared animated door to play its artwork.")
	var tool = adapter.host.Editor.Tools.get("SelectTool")
	if not is_instance_valid(tool) or not tool.has_method("EnableTransformBox"):
		return G.failure("PREVIEW","Native selection visuals cannot be temporarily hidden on this host.")
	# Keep the native selection dictionary intact. Only suppress its rendering.
	tool_ref = weakref(tool)
	tool.EnableTransformBox(false)
	for entry in planned:
		var node = entry.node.get_ref()
		entry["highlighted"] = adapter.property(node,"isHighlighted",false)
		if node.has_method("Highlight"):
			node.Highlight(false)
		if node.has_method("Select"):
			entry["selected_visual"] = adapter.property(node,"isSelected",false)
			node.Select(false)
	originals = hidden
	for entry in originals:
		entry.ref.get_ref().hide()
	entries = planned
	ids = selection.duplicate()
	ids.sort()
	native_ids = adapter.selected_assets()
	native_ids.sort()
	level_ref = weakref(adapter.current_level())
	active_tool = adapter.property(adapter.host.Editor,"ActiveTool")
	base_ms = baseline
	elapsed_ms = 0
	active = true
	show()
	set_process(true)
	set_process_input(true)
	update()
	return G.success(true)

func _input(event):
	if event is InputEventKey and event.pressed and event.scancode == KEY_ESCAPE:
		cancel()
		get_tree().set_input_as_handled()
	elif (event is InputEventKey and event.pressed and event.control and event.scancode == KEY_S) or (event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT):
		cancel()

func _process(delta):
	if not active:
		return
	var current = adapter.selected_assets()
	current.sort()
	if adapter.exporting() or not is_instance_valid(level_ref.get_ref()) or adapter.current_level()!=level_ref.get_ref() or current!=native_ids or adapter.property(adapter.host.Editor,"ActiveTool")!=active_tool or (is_instance_valid(adapter.export_window) and adapter.export_window.visible):
		cancel()
		return
	var complete = true
	elapsed_ms += delta*1000.0
	for entry in entries:
		var sprite = entry.sprite.get_ref()
		if not is_instance_valid(sprite) or not sprite.is_inside_tree() or sprite.global_transform != entry.source_transform:
			cancel()
			return
		complete = complete and elapsed_ms >= 2*entry.duration_ms
	if complete:
		cancel()
	else:
		update()

func _draw():
	if not active:
		return
	var local = global_transform.affine_inverse()
	for entry in entries:
		var stage = clamp(elapsed_ms/entry.duration_ms,0.0,2.0)
		var progress = stage if stage <= 1 else 2-stage
		var leaves = [entry.transform]
		if entry.settings.double_door:
			var first = entry.transform
			first.x *= 0.5
			var second = entry.transform
			second.origin += second.x
			second.x *= -0.5
			leaves = [first,second]
		for i in range(leaves.size()):
			var leaf = leaves[i]
			var pivot = leaf.origin+leaf.y*0.5
			if entry.settings.animation_type == "swivel":
				pivot += leaf.x*0.5
			draw_set_transform_matrix(local*pose(leaf,pivot,entry.settings,progress,i==1))
			var alpha = 1.0
			if entry.settings.animation_type in ["ascend","descend"]:
				alpha = 1-progress if entry.settings.animation_type == "ascend" else progress
				draw_texture_rect(entry.texture,Rect2(Vector2.ZERO,Vector2.ONE),false,Color(0.08,0.08,0.08,0.55*(1-alpha)))
			draw_texture_rect(entry.texture,Rect2(Vector2.ZERO,Vector2.ONE),false,Color(1,1,1,alpha))
	draw_set_transform_matrix(Transform2D())

func cancel():
	if not active:
		return
	active = false
	for entry in originals:
		var node = entry.ref.get_ref()
		if is_instance_valid(node):
			node.visible = entry.visible
	for entry in entries:
		var node = entry.node.get_ref()
		if is_instance_valid(node):
			if entry.has("selected_visual"):
				var selected = adapter.property(tool_ref.get_ref(),"Selectables",{})
				node.Select(entry.selected_visual and selected.has(node))
			if node.has_method("Highlight"):
				node.Highlight(entry.get("highlighted",false))
	var tool = tool_ref.get_ref() if tool_ref != null else null
	if is_instance_valid(tool) and level_ref.get_ref() == adapter.current_level():
		tool.OnFinishSelection()
	originals.clear()
	entries.clear()
	ids.clear()
	set_process(false)
	set_process_input(false)
	hide()
	update()
	emit_signal("finished")
