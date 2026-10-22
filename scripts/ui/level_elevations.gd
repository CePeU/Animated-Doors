extends Reference

const A = preload("../core/host_adapter.gd")
const L = preload("localization.gd")
const EXPORT_BUTTON_ID = 0xAD01
var owner_ref
var tree
var layer
var rows = {}
var forwarding = false
var elevation_icons = {}
var export_icons = {}
var drop_marker = {}
var old_drop_color
var had_drop_color = false

class InputLayer:
	extends Control
	var owner_ref
	func _process(_delta):
		var owner = owner_ref.get_ref()
		if owner != null:
			owner.layout()
	func _draw():
		var owner = owner_ref.get_ref()
		if owner != null:
			owner.draw_drop_marker(self)
	func _notification(what):
		if what == NOTIFICATION_DRAG_END and owner_ref != null:
			var owner = owner_ref.get_ref()
			if owner != null:
				owner.clear_drop_marker()
	func get_drag_data_fw(position, _from):
		var owner = owner_ref.get_ref()
		if owner == null:
			return null
		var item = owner.tree.get_item_at_position(position)
		if item != null and item.has_meta("ad_elevation_row"):
			return null
		return owner.tree.GetDragData(position)
	func can_drop_data_fw(position, data, _from):
		var owner = owner_ref.get_ref()
		return owner != null and owner.can_drop(position, data)
	func drop_data_fw(position, data, _from):
		var owner = owner_ref.get_ref()
		if owner != null:
			owner.clear_drop_marker()
			owner.tree.DropData(owner.drop_position(position), data)
			owner.refresh()

func _init(controller):
	owner_ref = weakref(controller)

func refresh():
	var controller = owner_ref.get_ref()
	if controller == null or controller.stopped:
		return
	if not is_instance_valid(tree):
		var tool = controller.host.Editor.Tools.get("LevelSettings")
		var controls = A.property(tool, "Controls", {})
		var candidate = controls.get("Level") if controls is Dictionary else null
		if candidate is Tree:
			install(candidate)
	if not is_instance_valid(tree):
		return
	var root = tree.get_root()
	for key in rows.keys():
		var header = rows[key].item.get_ref()
		var detail = rows[key].detail.get_ref()
		# Native reordering rebuilds the headers and may retain detached items.
		if root == null or header == null or detail == null or header.get_parent() != root:
			if header != null:
				header.set_disable_folding(rows[key].old_folding)
				var index = export_button_index(header)
				if index >= 0:
					header.erase_button(0, index)
			if is_instance_valid(rows[key].control):
				rows[key].control.hide()
				rows[key].control.queue_free()
			if detail != null:
				detail.free()
			rows.erase(key)
	if root == null:
		return
	var item = root.get_children()
	while item != null:
		if item.has_meta("meta"):
			var level = item.get_meta("meta")
			if is_instance_valid(level):
				var key = item.get_instance_id()
				if not rows.has(key):
					_add_row(item, level)
				var component = controller.levels.get_component(level)
				_refresh_export_button(item, component, controller.transaction.state == "IDLE")
				for field in ["bottom", "top"]:
					var spin = rows[key][field]
					spin.editable = not component.read_only and controller.transaction.state == "IDLE"
					spin.hint_tooltip = L.text("Bottom elevation" if field == "bottom" else "Top elevation")
					if not component.read_only and spin.value != component.data[field]:
						spin.set_block_signals(true)
						spin.value = component.data[field]
						spin.set_block_signals(false)
		item = item.get_next()
	layout()

func install(value):
	tree = value
	rows.clear()
	for state in ["checked", "unchecked"]:
		export_icons[state] = tree.get_icon(state, "CheckBox").duplicate()
	for field in ["bottom", "top"]:
		var image = Image.new()
		var filename = "layers-arrow-down.png" if field == "bottom" else "layers-arrow-up.png"
		var path = get_script().resource_path.get_base_dir().plus_file("../../icons/" + filename).simplify_path()
		if image.load(path) == OK:
			var texture = ImageTexture.new()
			texture.create_from_image(image, Texture.FLAG_FILTER)
			elevation_icons[field] = texture
	layer = InputLayer.new()
	layer.name = "AnimatedDoorsLevelInputs"
	layer.owner_ref = weakref(self)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.rect_clip_content = true
	tree.add_child(layer)
	tree.connect("item_collapsed", self, "_item_collapsed")
	tree.connect("button_pressed", self, "_header_button_pressed")
	# Native DragDropTree.Order only contains the level headers. Never pass a
	# detail row to its linked-list drop handler; map it to its parent's end.
	forwarding = tree.has_method("GetDragData") and tree.has_method("CanDropData") and tree.has_method("DropData")
	if forwarding:
		had_drop_color = tree.has_color_override("drop_position_color")
		old_drop_color = tree.get_color("drop_position_color")
		# Native indicators target individual TreeItems, splitting our two lines.
		# Draw a group boundary instead, while retaining native drop semantics.
		tree.add_color_override("drop_position_color", Color.transparent)
		tree.set_drag_forwarding(layer)

func _add_row(item, level):
	var detail = tree.create_item(item)
	detail.set_meta("ad_elevation_row", true)
	for column in range(tree.columns):
		detail.set_selectable(column, false)
	item.collapsed = false
	var old_folding = item.is_folding_disabled()
	item.set_disable_folding(true)
	var controls = HBoxContainer.new()
	controls.mouse_filter = Control.MOUSE_FILTER_STOP
	controls.add_constant_override("separation", 2)
	layer.add_child(controls)
	var row = {"item": weakref(item), "detail": weakref(detail), "level": weakref(level), "control": controls, "old_folding": old_folding}
	for field in ["bottom", "top"]:
		var icon = TextureRect.new()
		icon.texture = elevation_icons.get(field)
		icon.rect_min_size = Vector2(24, 24)
		icon.expand = true
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.hint_tooltip = L.text("Bottom elevation" if field == "bottom" else "Top elevation")
		controls.add_child(icon)
		var spin = SpinBox.new()
		spin.min_value = -2147483648
		spin.max_value = 2147483647
		spin.step = 1
		spin.rounded = true
		spin.get_line_edit().add_font_override("font", tree.get_font("font"))
		spin.rect_min_size.x = max(64, tree.get_font("font").get_string_size("-9999").x + 22)
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		controls.add_child(spin)
		spin.connect("value_changed", self, "_changed", [weakref(level), field])
		row[field] = spin
	detail.set_custom_minimum_height(int(controls.get_combined_minimum_size().y + 4))
	rows[item.get_instance_id()] = row

func layout():
	if not is_instance_valid(tree) or not is_instance_valid(layer):
		return
	layer.rect_size = tree.rect_size
	for child in tree.get_children():
		if child is VScrollBar and child.visible:
			layer.rect_size.x = min(layer.rect_size.x, child.rect_position.x)
		elif child is HScrollBar and child.visible:
			layer.rect_size.y = min(layer.rect_size.y, child.rect_position.y)
	for row in rows.values():
		var detail = row.detail.get_ref()
		var header = row.item.get_ref()
		if detail == null or header == null or header.get_parent() != tree.get_root():
			row.control.hide()
			continue
		# Tree item rectangles can remain nonempty for folded descendants.
		# The overlay must follow every ancestor's folding state explicitly.
		var ancestor = detail.get_parent()
		var folded = false
		while ancestor != null:
			if ancestor.collapsed:
				folded = true
				break
			ancestor = ancestor.get_parent()
		if folded:
			row.control.hide()
			continue
		# Native DragDropTree adds its hover icon even to non-draggable child rows.
		# Clear it before drawing; the level header keeps its native drag handle.
		if detail.get_icon(0) != null:
			detail.set_icon(0, null)
		var area = item_area(detail)
		row.control.visible = area.size.y > 0
		row.control.rect_position = area.position + Vector2(0, 2)
		row.control.rect_size = Vector2(max(0, min(area.size.x, layer.rect_size.x - area.position.x)), max(0, area.size.y - 4))
	if not drop_marker.empty():
		layer.update()

func _item_collapsed(_item):
	clear_drop_marker()
	layout()

func item_area(item):
	var area = tree.get_item_area_rect(item)
	# Godot 3 reports content rectangles without the Tree background margins,
	# while hit testing and overlay drawing use full control coordinates.
	area.position += tree.get_stylebox("bg").get_offset() - tree.get_scroll()
	return area

func drop_target(position):
	var item = tree.get_item_at_position(position)
	if item != null and item.has_meta("ad_elevation_row"):
		item = item.get_parent()
	if item == null or not rows.has(item.get_instance_id()):
		return {}
	var area = item_area(item)
	var detail = rows[item.get_instance_id()].detail.get_ref()
	if detail != null and not item.collapsed:
		area = area.merge(item_area(detail))
	return {"item": weakref(item), "after": position.y >= area.position.y + area.size.y * 0.5}

func drop_position(position):
	var target = drop_target(position)
	if not target.empty():
		var area = item_area(target.item.get_ref())
		return Vector2(area.position.x + 1, area.end.y - 1 if target.after else area.position.y + 1)
	return position

func can_drop(position, data):
	var target = drop_target(position)
	var allowed = not target.empty() and data is TreeItem and data.has_meta("meta") and data != target.item.get_ref()
	if allowed:
		allowed = tree.CanDropData(drop_position(position), data)
	drop_marker = target if allowed else {}
	layer.update()
	return allowed

func clear_drop_marker():
	if not drop_marker.empty():
		drop_marker = {}
		if is_instance_valid(layer):
			layer.update()

func drop_marker_y():
	if drop_marker.empty():
		return null
	var item = drop_marker.item.get_ref()
	if item == null or not rows.has(item.get_instance_id()):
		return null
	var boundary = item
	if drop_marker.after and not item.collapsed:
		boundary = rows[item.get_instance_id()].detail.get_ref()
	if boundary == null:
		return null
	var area = item_area(boundary)
	return area.end.y if drop_marker.after else area.position.y

func draw_drop_marker(canvas):
	var y = drop_marker_y()
	if y != null:
		canvas.draw_line(Vector2(0, y), Vector2(layer.rect_size.x, y), old_drop_color, 2)

func export_button_index(item):
	# Godot 3.4 cannot query button IDs. Private texture copies identify only
	# our buttons even when another mod inserts or reorders its own buttons.
	for index in range(item.get_button_count(0)):
		if item.get_button(0, index) in export_icons.values():
			return index
	return -1

func _refresh_export_button(item, component, idle):
	var index = export_button_index(item)
	var enabled = component.data.export_enabled == true
	var icon = export_icons["checked" if enabled else "unchecked"]
	var tooltip = L.text("Included in UVTT export; click to exclude" if enabled else "Excluded from UVTT export; click to include")
	if index >= 0 and (item.get_button(0, index) != icon or item.get_button_tooltip(0, index) != tooltip):
		item.erase_button(0, index)
		index = -1
	if index < 0:
		item.add_button(0, icon, EXPORT_BUTTON_ID, component.read_only or not idle, tooltip)
	else:
		item.set_button_disabled(0, index, component.read_only or not idle)

func _header_button_pressed(item, column, id):
	if column != 0 or id != EXPORT_BUTTON_ID or item == null or not item.has_meta("meta"):
		return
	var controller = owner_ref.get_ref()
	if controller != null:
		var level = item.get_meta("meta")
		var component = controller.levels.get_component(level)
		controller._level_export_changed(level, not component.data.export_enabled)

func _changed(value, level_ref, field):
	var controller = owner_ref.get_ref()
	var level = level_ref.get_ref()
	if controller != null and is_instance_valid(level):
		controller._level_elevation_changed(level, field, value)

func detach():
	if is_instance_valid(tree):
		if tree.is_connected("item_collapsed", self, "_item_collapsed"):
			tree.disconnect("item_collapsed", self, "_item_collapsed")
		if tree.is_connected("button_pressed", self, "_header_button_pressed"):
			tree.disconnect("button_pressed", self, "_header_button_pressed")
		if forwarding:
			tree.set_drag_forwarding(null)
			if had_drop_color:
				tree.add_color_override("drop_position_color", old_drop_color)
			else:
				tree.set("custom_colors/drop_position_color", null)
		for row in rows.values():
			var item = row.item.get_ref()
			var detail = row.detail.get_ref()
			if item != null:
				item.set_disable_folding(row.old_folding)
				var index = export_button_index(item)
				if index >= 0:
					item.erase_button(0, index)
			if detail != null:
				detail.free()
	if is_instance_valid(layer):
		layer.queue_free()
	rows.clear()
	drop_marker = {}
	forwarding = false
	tree = null
