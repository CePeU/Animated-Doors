extends VBoxContainer

const L = preload("localization.gd")

signal edit_requested(field, value)
signal default_requested(field, value)
signal layer_requested(id)
signal selection_changed(ids)
signal preview_changed(enabled)
signal artwork_preview_requested
signal preview_duration_changed(value)
signal apply_defaults_requested
signal reset_crop_requested
signal diagnostics_requested
signal editing_changed(active)
signal filter_changed(mode)
signal asset_activated(id)
signal show_all_changed(active)
signal asset_toggle_requested(id, field)

var layers
var door_list
var enabled
var hinge
var swing
var axis
var status
var syncing = false
var rows_signature = ""
var layers_signature = ""
var settings_signature = ""
var editing_toggle
var filter_mode
var preview_play
var preview_duration
var preview_toggle
var apply_button
var editing_active = false
var show_all_toggle
const Component = preload("../core/door_component.gd")
var extra_controls = {}
var default_controls = {}
var crop_reset
var amount_reset
const CHOICES = {"door_type": [1, 2, -1], "animation_type": ["swing", "slide", "swivel", "ascend", "descend"], "door_state": ["closed", "open", "locked"]}
const LABELS = {"door_type": ["Door", "Secret door", "Window"], "animation_type": ["swing", "slide", "swivel", "ascend", "descend"], "door_state": ["Closed", "Open", "Locked"]}
const AXIS_MODES = ["width", "height", "longer", "shorter", "visible"]
var defaults_group

func _init():
	rect_min_size = Vector2(260, 400)
	add_label("Animated Doors")
	editing_toggle = CheckBox.new()
	editing_toggle.text = "Enable animated door editing"
	add_child(editing_toggle)
	editing_toggle.connect("toggled", self, "_editing")
	var defaults_start = get_child_count()
	var default_hinge = option(["Default hinge A", "Default hinge B"])
	default_hinge.name = "DefaultHinge"
	default_hinge.connect("item_selected", self, "_default_hinge")
	var default_swing = option(["Default swing right", "Default swing left"])
	default_swing.name = "DefaultSwing"
	default_swing.connect("item_selected", self, "_default_swing")
	var default_axis = option(["Default axis: image width", "Default axis: image height", "Default axis: the longer side", "Default axis: the shorter side", "Default axis: visible artwork"])
	default_axis.name = "DefaultAxis"
	default_axis.connect("item_selected", self, "_default_axis")
	for field in ["door_type", "animation_type", "door_state", "double_door", "swing_degrees", "hinge_offset_a", "hinge_offset_b"]:
		default_controls[field] = extra_control(field, true)
	defaults_group = preload("settings_group.gd").new("Defaults when declaring a door", false)
	for child in get_children().slice(defaults_start, get_child_count() - 1):
		remove_child(child)
		defaults_group.content.add_child(child)
	add_child(defaults_group)
	enabled = CheckBox.new()
	enabled.text = "Declared animated door"
	add_child(enabled)
	enabled.connect("toggled", self, "_enabled")
	hinge = option(["Hinge A (triangle)", "Hinge B (circle)"])
	hinge.connect("item_selected", self, "_hinge")
	swing = option(["Swing right", "Swing left"])
	swing.connect("item_selected", self, "_swing")
	axis = option(["Door axis: image width", "Door axis: image height"])
	axis.connect("item_selected", self, "_axis")
	for field in ["door_type", "animation_type", "door_state", "double_door", "swing_degrees", "hinge_offset_a", "hinge_offset_b"]:
		extra_controls[field] = extra_control(field, false)
	crop_reset = button("Reset crop template", "_reset_crop")
	preview_toggle = CheckBox.new()
	preview_toggle.text = "Preview swing"
	preview_toggle.pressed = true
	var preview_row = HBoxContainer.new()
	add_child(preview_row)
	preview_row.add_child(preview_toggle)
	preview_play = Button.new()
	preview_play.text = "Play animation"
	preview_row.add_child(preview_play)
	preview_play.connect("pressed",self,"_play_artwork")
	var duration_row = HBoxContainer.new()
	add_child(duration_row)
	var duration_label = Label.new()
	duration_label.text = "Preview duration (ms)"
	duration_row.add_child(duration_label)
	preview_duration = SpinBox.new()
	preview_duration.min_value = 1
	preview_duration.max_value = 60000
	preview_duration.allow_greater = true
	preview_duration.step = 1
	preview_duration.value = 750
	preview_duration.hint_tooltip = "Time for one preview operation; saved with this map. Ascend/descend use duration × 180 / amount (zero uses 180)."
	duration_row.add_child(preview_duration)
	preview_duration.connect("value_changed",self,"_preview_duration")
	preview_toggle.connect("toggled", self, "_preview")
	show_all_toggle = CheckBox.new()
	show_all_toggle.text = "Show all animated doors"
	add_child(show_all_toggle)
	show_all_toggle.connect("toggled", self, "_show_all")
	layers = OptionButton.new()
	add_child(layers)
	layers.connect("item_selected", self, "_layer_selected")
	filter_mode = option(["Declared doors", "All objects and portals", "Undeclared objects and portals"])
	filter_mode.connect("item_selected", self, "_filter")
	door_list = ItemList.new()
	door_list.select_mode = ItemList.SELECT_MULTI
	door_list.rect_min_size.y = 400
	door_list.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(door_list)
	door_list.connect("multi_selected", self, "_selection_changed")
	door_list.connect("item_activated", self, "_activated")
	door_list.connect("gui_input", self, "_list_input")
	apply_button = button("Apply defaults to selected doors", "_apply_defaults")
	button("Write diagnostic report", "_diagnostics")
	status = add_label("")
	status.hide()

func extra_control(field, defaults):
	var control
	var prefix = "Default " if defaults else ""
	if CHOICES.has(field):
		var labels = []
		for label in LABELS[field]:
			labels.append(prefix + label)
		control = option(labels)
		control.connect("item_selected", self, "_extra_choice", [field, defaults])
	elif field == "double_door":
		control = CheckBox.new()
		control.text = prefix + "Double door"
		add_child(control)
		control.connect("toggled", self, "_extra_value", [field, defaults])
	else:
		var row = HBoxContainer.new()
		add_child(row)
		var label = Label.new()
		label.text = prefix + ("Door extension" if field == "swing_degrees" else ("Hinge A (triangle) offset" if field == "hinge_offset_a" else "Hinge B (circle) offset"))
		row.add_child(label)
		control = SpinBox.new()
		control.min_value = 0
		control.max_value = 180 if field == "swing_degrees" else 1048576
		control.step = 1 if field == "swing_degrees" else 0.001
		if field != "swing_degrees":
			control.add_child(preload("pixel_step.gd").new(control))
		control.size_flags_horizontal = SIZE_EXPAND_FILL
		control.value = 90 if field == "swing_degrees" else 0
		control.hint_tooltip = "Amount: 0-180; 90 is normal strength. Changes affect only the selected doors." if field == "swing_degrees" else "Crop inward in map pixels at 256 pixels/grid. Whole source pixels are retained without resizing."
		row.add_child(control)
		control.connect("value_changed", self, "_extra_value", [field, defaults])
		if field == "swing_degrees":
			var reset = Button.new()
			reset.text = "90"
			reset.hint_tooltip = "Reset Door extension to 90"
			reset.connect("pressed", self, "_reset_amount", [defaults])
			row.add_child(reset)
			if not defaults:
				amount_reset = reset
	return control

func _extra_choice(index, field, defaults):
	if index < CHOICES[field].size():
		_extra_value(CHOICES[field][index], field, defaults)

func _extra_value(value, field, defaults):
	if not syncing:
		emit_signal("default_requested" if defaults else "edit_requested", field, value)

func _reset_amount(defaults):
	_extra_value(90, "swing_degrees", defaults)

func _list_input(event):
	if not event is InputEventMouseButton or event.button_index != BUTTON_RIGHT or not event.pressed:
		return
	if not editing_active or event.alt or event.meta or (event.shift and event.control):
		return
	var index = door_list.get_item_at_position(event.position, true)
	if index < 0:
		return
	var field = "hinge_endpoint" if event.shift else ("swing_direction" if event.control else "enabled")
	emit_signal("asset_toggle_requested", door_list.get_item_metadata(index), field)
	door_list.accept_event()

func set_status(message):
	status.text = L.text(message)
	status.visible = not message.empty()

func add_label(text):
	var label = Label.new()
	label.text = text
	label.autowrap = true
	label.rect_min_size.x = 250
	add_child(label)
	return label

func option(items):
	var control = OptionButton.new()
	for text in items:
		control.add_item(text)
	add_child(control)
	return control

func button(text, method):
	var control = Button.new()
	control.text = text
	add_child(control)
	control.connect("pressed", self, method)
	return control

func selected_ids():
	var ids = []
	for index in door_list.get_selected_items():
		ids.append(door_list.get_item_metadata(index))
	return ids

func populate(rows, available_layers, layer_id, defaults):
	var selected = selected_ids()
	syncing = true
	var next_layers = JSON.print([available_layers, layer_id])
	if next_layers != layers_signature:
		layers_signature = next_layers
		layers.clear()
		var keys = available_layers.keys()
		keys.sort()
		for key in keys:
			layers.add_item("All layers" if key == 2147483647 else "%s: %s" % [key, available_layers[key]])
			var index = layers.get_item_count() - 1
			layers.set_item_metadata(index, key)
			if int(key) == int(layer_id):
				layers.select(index)
		if not available_layers.has(int(layer_id)):
			layers.add_item(L.text("Missing layer: %s") % str(layer_id))
			layers.set_item_metadata(layers.get_item_count() - 1, layer_id)
			layers.select(layers.get_item_count() - 1)
	var next_rows = JSON.print(rows)
	if next_rows != rows_signature:
		rows_signature = next_rows
		var scroll = door_list.get_v_scroll().value
		door_list.clear()
		for row in rows:
			door_list.add_item(row.label)
			var index = door_list.get_item_count() - 1
			door_list.set_item_metadata(index, row.id)
			door_list.set_item_custom_fg_color(index, Color(1.0, 0.85, 0.25) if row.get("declared", false) else Color(0.45, 0.75, 1.0))
			if row.id in selected:
				door_list.select(index, false)
		door_list.get_v_scroll().value = scroll
	find_node("DefaultHinge", true, false).select(0 if defaults.hinge_endpoint == "begin" else 1)
	find_node("DefaultSwing", true, false).select(0 if defaults.swing_direction == "right" else 1)
	find_node("DefaultAxis", true, false).select(AXIS_MODES.find(defaults.axis))
	for field in default_controls:
		show_extra(default_controls[field], field, defaults.get(field, Component.defaults()[field]), false, true)
	syncing = false
	L.apply_tree(self)

func show_settings(values):
	var next_settings = JSON.print([values, editing_active])
	if next_settings == settings_signature:
		return
	settings_signature = next_settings
	syncing = true
	var has_selection = not values.empty() and editing_active
	var all_declared = has_selection
	for value in values:
		all_declared = all_declared and value.enabled
	enabled.disabled = not has_selection
	hinge.disabled = not all_declared
	swing.disabled = not all_declared
	axis.disabled = not all_declared
	for field in extra_controls:
		var mixed = false
		var first_value = values[0].get(field, Component.defaults()[field]) if has_selection else Component.defaults()[field]
		for value in values:
			mixed = mixed or value.get(field, Component.defaults()[field]) != first_value
		show_extra(extra_controls[field], field, first_value, mixed, all_declared)
	crop_reset.disabled = not all_declared
	amount_reset.disabled = not all_declared
	preview_toggle.disabled = not all_declared
	apply_button.disabled = not all_declared
	if not has_selection:
		enabled.pressed = false
	if has_selection:
		var first = values[0]
		var mixed = []
		for field in ["enabled", "hinge_endpoint", "swing_direction", "axis"]:
			for value in values:
				if value[field] != first[field] and not field in mixed:
					mixed.append(field)
		enabled.text = "Declared animated door (mixed)" if "enabled" in mixed else "Declared animated door"
		enabled.pressed = first.enabled
		show_choice(hinge, "hinge_endpoint" in mixed, 0 if first.hinge_endpoint == "begin" else 1)
		show_choice(swing, "swing_direction" in mixed, 0 if first.swing_direction == "right" else 1)
		show_choice(axis, "axis" in mixed, 0 if first.axis == "width" else 1)
	syncing = false
	L.apply_tree(self)

func show_extra(control, field, value, mixed, active):
	if control is OptionButton:
		control.disabled = not active
		show_choice(control, mixed, CHOICES[field].find(value), CHOICES[field].size())
	elif control is CheckBox:
		control.disabled = not active
		control.pressed = value
		control.text = ("Default " if control == default_controls.get(field) else "") + "Double door" + (" (mixed)" if mixed else "")
	else:
		control.editable = active
		# Do not overwrite an in-progress typed value during periodic refresh.
		if not control.get_line_edit().has_focus():
			control.value = value
			control.get_line_edit().text = "" if mixed else str(value)
		control.get_line_edit().placeholder_text = "Mixed" if mixed else ""

func show_choice(control, mixed, selected, count = 2):
	# Godot 3.4 OptionButton.select(-1) does not clear the previous selection.
	if control.get_item_count() > count:
		control.remove_item(count)
	if mixed:
		control.add_item("Mixed (choose a value)")
		control.set_item_disabled(count, true)
		control.select(count)
	else:
		control.select(selected)

func _selection_changed(_index, _selected):
	if not syncing:
		emit_signal("selection_changed", selected_ids())

func _layer_selected(index):
	if not syncing:
		emit_signal("layer_requested", layers.get_item_metadata(index))

func _enabled(value):
	if not syncing:
		emit_signal("edit_requested", "enabled", value)

func _hinge(index):
	if not syncing:
		emit_signal("edit_requested", "hinge_endpoint", "begin" if index == 0 else "end")

func _swing(index):
	if not syncing:
		emit_signal("edit_requested", "swing_direction", "right" if index == 0 else "left")

func _default_enabled(value):
	if not syncing:
		emit_signal("default_requested", "enabled", value)

func _axis(index):
	if not syncing:
		emit_signal("edit_requested", "axis", "width" if index == 0 else "height")

func _default_axis(index):
	if not syncing:
		emit_signal("default_requested", "axis", AXIS_MODES[index])

func _show_all(active):
	emit_signal("show_all_changed", active)

func _editing(value):
	editing_active = value
	emit_signal("editing_changed", value)

func _filter(index):
	emit_signal("filter_changed", index)

func _activated(index):
	emit_signal("asset_activated", door_list.get_item_metadata(index))

func _default_hinge(index):
	if not syncing:
		emit_signal("default_requested", "hinge_endpoint", "begin" if index == 0 else "end")

func _default_swing(index):
	if not syncing:
		emit_signal("default_requested", "swing_direction", "right" if index == 0 else "left")

func _preview(value):
	emit_signal("preview_changed", value)

func _apply_defaults():
	emit_signal("apply_defaults_requested")

func _reset_crop():
	emit_signal("reset_crop_requested")

func _diagnostics():
	emit_signal("diagnostics_requested")

func _play_artwork():
	emit_signal("artwork_preview_requested")

func _preview_duration(value):
	if not syncing:
		emit_signal("preview_duration_changed",value)

func set_preview_duration(value):
	preview_duration.set_block_signals(true)
	preview_duration.value = value
	preview_duration.set_block_signals(false)
