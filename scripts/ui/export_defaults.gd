extends Reference

const PATH = "user://animated_doors_export_defaults.cfg"
const L = preload("localization.gd")
const LABELS = {
	"ExportModeOptions": "Export mode", "ImageQualitySlider": "Image quality",
	"GridPPISpinBox": "Grid PPI", "GridLayerSlider": "Grid layer",
	"SourceLevelOptions": "Source level", "OverlayLevelOptions": "Overlay level",
	"CameraFilterOptions": "Camera filter", "GridPresetOptions": "Grid preset",
	"GridPresetsOptions": "Grid preset", "ImageQualitySpinBox": "Image quality",
	"GridCheckButton": "Grid", "LightingCheckButton": "Lighting",
	"SourceLightingCheckButton": "Source lighting", "OverlayLightingCheckButton": "Overlay lighting",
	"SourceBrightnessSlider": "Source brightness", "SourceBrightnessSpinBox": "Source brightness",
	"SourceFocusSlider": "Source focus", "SourceFocusSpinBox": "Source focus",
	"OverlayOpacitySlider": "Overlay opacity", "OverlayOpacitySpinBox": "Overlay opacity",
	"ShowFolderOnFinish": "Show folder after export", "GridLayerRow": "Grid layer"
}
var window
var dialog
var rows
var entries = {}
var unavailable = {}
var settings = ConfigFile.new()

func _init(export_window):
	window = export_window
	settings.load(PATH)
	dialog = AcceptDialog.new()
	dialog.window_title = "Export defaults"
	dialog.rect_min_size = Vector2(520, 520)
	var scroll = ScrollContainer.new()
	scroll.rect_min_size = Vector2(490, 460)
	scroll.scroll_horizontal_enabled = false
	dialog.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	# Global settings must open this dialog even when Export itself is hidden.
	var parent = window.get_parent() if window.get_parent() != null else window
	parent.add_child(dialog)
	dialog.connect("confirmed", self, "save")

func control_key(node):
	var parts = []
	while node != window:
		var part = str(node.name)
		if part.begins_with("@"):
			var ordinal = 0
			for sibling in node.get_parent().get_children():
				if sibling == node:
					break
				if sibling.get_class() == node.get_class():
					ordinal += 1
			part = node.get_class() + str(ordinal)
		parts.push_front(part)
		node = node.get_parent()
	return PoolStringArray(parts).join("/")

func controls(node, result):
	for child in node.get_children():
		if child is WindowDialog or child.name == "AnimatedDoorsExportControls":
			continue
		if child is OptionButton or child is SpinBox or child is Slider or child is CheckBox or child is CheckButton:
			result[control_key(child)] = child
		else:
			controls(child, result)

func value(control):
	if control is OptionButton:
		if control.has_meta("ad_default_values") and control.selected >= 0:
			return control.get_item_metadata(control.selected)
		return control.get_item_text(control.selected) if control.selected >= 0 else ""
	if control is Range:
		return control.value
	return control.pressed

func assign(control, stored, notify = false):
	if control is OptionButton:
		if not stored is String:
			return
		for i in range(control.get_item_count()):
			var canonical = control.get_item_metadata(i) if control.has_meta("ad_default_values") else null
			if (canonical if canonical is String else control.get_item_text(i)) == stored:
				control.select(i)
				if notify:
					control.emit_signal("item_selected", i)
				return
	elif control is Range and (stored is int or stored is float):
		control.value = clamp(stored, control.min_value, control.max_value)
	elif (control is CheckBox or control is CheckButton) and stored is bool:
		control.pressed = stored

func apply():
	var live = {}
	controls(window, live)
	for key in live:
		if settings.has_section_key("controls", key):
			assign(live[key], settings.get_value("controls", key), true)

func open():
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	entries.clear()
	unavailable.clear()
	var live = {}
	controls(window, live)
	for key in live:
		var original = live[key]
		var label = Label.new()
		var label_key = str(original.get_parent().name) if str(original.name).begins_with("@") else str(original.name)
		label.text = LABELS.get(label_key, label_key.capitalize())
		rows.add_child(label)
		var copy
		if original is OptionButton:
			copy = OptionButton.new()
			copy.set_meta("ad_default_values", true)
			for i in range(original.get_item_count()):
				var title = original.get_item_text(i)
				copy.add_item(title)
				copy.set_item_metadata(i, title)
				# Custom module formats and map level names are user-owned strings.
				if str(original.name) == "ExportModeOptions":
					copy.set_item_text(i, L.text(title))
			copy.set_meta("ad_skip_items", true)
		elif original is Range:
			copy = SpinBox.new()
			copy.min_value = original.min_value
			copy.max_value = original.max_value
			copy.step = original.step
		else:
			copy = CheckButton.new()
			copy.text = original.text
		assign(copy, value(original))
		assign(copy, settings.get_value("controls", key, value(original)))
		if copy is OptionButton and settings.has_section_key("controls", key) and value(copy) != settings.get_value("controls", key):
			unavailable[key] = value(copy)
		rows.add_child(copy)
		entries[key] = copy
	L.apply_tree(dialog)
	dialog.popup_centered()

func save():
	# Retain defaults belonging to modules that are currently unloaded.
	for key in entries:
		if unavailable.has(key) and value(entries[key]) == unavailable[key]:
			continue
		settings.set_value("controls", key, value(entries[key]))
	if settings.save(PATH) != OK:
		dialog.dialog_text = "Could not save global settings."
		dialog.popup_centered()
