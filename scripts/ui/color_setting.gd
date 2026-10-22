extends HBoxContainer

# The hidden backend ColorPickerButton retains its original persistence API.
# This editor is shared by _Lib and standalone settings.
const L = preload("localization.gd")
var storage
var hex = LineEdit.new()
var choose = Button.new()
var swatch = ColorRect.new()
var dialog = ConfirmationDialog.new()
var picker = ColorPicker.new()
var last_color = Color.transparent

func _init(backend):
	storage = backend
	hex.placeholder_text = "#RRGGBB or #AARRGGBB"
	hex.hint_tooltip = "Enter 6 hex digits, or 8 with alpha first. Save global settings to keep changes."
	hex.size_flags_horizontal = SIZE_EXPAND_FILL
	hex.rect_min_size.x = 145
	add_child(hex)
	swatch.rect_min_size = Vector2(28, 24)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(swatch)
	choose.text = "Choose color..."
	add_child(choose)
	dialog.window_title = "Choose color"
	dialog.get_ok().text = "Apply"
	dialog.popup_exclusive = true
	dialog.add_child(picker)
	add_child(dialog)
	hex.connect("text_changed", self, "_typed")
	hex.connect("focus_exited", self, "refresh")
	choose.connect("pressed", self, "_open")
	dialog.connect("confirmed", self, "_apply")
	refresh()

func _process(_delta):
	# Backend load/cancel may change the picker without emitting color_changed.
	if _backend_color() != last_color and not hex.has_focus():
		refresh()

func _backend_color():
	return storage.get_picker().color

func refresh():
	last_color = _backend_color()
	hex.text = "#" + last_color.to_html()
	swatch.color = last_color
	hex.self_modulate = Color.white

func _typed(value):
	var digits = value.strip_edges().trim_prefix("#")
	var valid = digits.length() in [6, 8]
	for character in digits.to_lower():
		valid = valid and character in "0123456789abcdef"
	hex.self_modulate = Color.white if valid else Color(1, 0.5, 0.5)
	if valid:
		# Match Godot 3's native picker: RGB, or ARGB with alpha first.
		_set_color(Color(digits))

func _set_color(value):
	storage.color = value
	storage.get_picker().color = value
	storage.emit_signal("color_changed", value)
	last_color = value
	swatch.color = value

func _open():
	picker.color = _backend_color()
	L.apply_tree(dialog)
	dialog.popup_centered()

func _apply():
	_set_color(picker.color)
	refresh()

func _on_preferences_about_to_show():
	refresh()
