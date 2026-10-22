extends VBoxContainer

signal options_changed
var source
var formats = OptionButton.new()
var bake = CheckButton.new()
var embed = CheckButton.new()
var include_image = CheckButton.new()
var levels = CheckButton.new()
var multi_file = CheckButton.new()
var background = OptionButton.new()
var background_row = HBoxContainer.new()
var asset_row = HBoxContainer.new()
var asset_format = OptionButton.new()
const ASSET_FORMATS = ["original", "png", "webp"]
var active = false
var excluded_labels = []
var source_signature = ""
var legacy_spec = {}
var native_row
var native_row_visible = true
var format_heading = Label.new()
var export_dialog
var dialog_content
var original_dialog_minimum = Vector2.ZERO
var applied_dialog_minimum = Vector2.ZERO
var dialog_fit_queued = false

func _init():
	name = "AnimatedDoorsExportControls"
	size_flags_horizontal = SIZE_EXPAND_FILL
	formats.set_meta("ad_skip_items", true)
	add_child(format_heading)
	add_child(formats)
	multi_file.text = "Multi file"
	multi_file.hint_tooltip = "Export each enabled level to a separate file in the selected format."
	add_child(multi_file)
	include_image.text = "Include map image"
	include_image.pressed = true
	add_child(include_image)
	var background_label = Label.new()
	background_label.text = "Export mode"
	background_row.add_child(background_label)
	for label in ["UVTT background: PNG", "UVTT background: JPG", "UVTT background: WebP"]:
		background.add_item(label)
	background.size_flags_horizontal = SIZE_EXPAND_FILL
	background_row.add_child(background)
	add_child(background_row)
	bake.text = "Include animated doors in map image"
	bake.hint_tooltip = "Bake door artwork into the background. UVTT is exported without animation data."
	add_child(bake)
	embed.text = "Embed door assets in UVTT (Base64)"
	embed.hint_tooltip = "Off: export asset paths and hashes. On: include the door image files."
	add_child(embed)
	var asset_label = Label.new()
	asset_label.text = "Door asset format"
	asset_row.add_child(asset_label)
	for label in ["Original format", "PNG", "WebP"]:
		asset_format.add_item(label)
	asset_row.add_child(asset_format)
	add_child(asset_row)
	levels.text = "Export levels"
	add_child(levels)
	formats.connect("item_selected", self, "_selected")
	bake.connect("toggled", self, "_changed")
	embed.connect("toggled", self, "_changed")
	include_image.connect("toggled", self, "_changed")
	levels.connect("toggled", self, "_changed")
	multi_file.connect("toggled", self, "_changed")
	background.connect("item_selected", self, "_changed")
	asset_format.connect("item_selected", self, "_changed")
	hide()

func install(native_formats, legacy_labels):
	source = native_formats
	excluded_labels = legacy_labels
	var anchor = source
	if source.get_parent() is HBoxContainer:
		native_row = source.get_parent()
		native_row_visible = native_row.visible
		anchor = native_row
		for child in native_row.get_children():
			if child is Label:
				format_heading.text = child.text
				break
	anchor.get_parent().add_child(self)
	anchor.get_parent().move_child(self, anchor.get_index() + 1)
	var ancestor = get_parent()
	while ancestor != null and not ancestor is WindowDialog:
		dialog_content = ancestor
		ancestor = ancestor.get_parent()
	if ancestor is WindowDialog and dialog_content is Container:
		export_dialog = ancestor
		original_dialog_minimum = export_dialog.rect_min_size
		applied_dialog_minimum = original_dialog_minimum
		dialog_content.connect("minimum_size_changed", self, "_queue_dialog_fit")
		export_dialog.connect("about_to_show", self, "_queue_dialog_fit")
		_queue_dialog_fit()
	else:
		dialog_content = null

func _queue_dialog_fit():
	if not dialog_fit_queued:
		dialog_fit_queued = true
		call_deferred("_fit_dialog")

func _fit_dialog():
	dialog_fit_queued = false
	if not is_instance_valid(export_dialog) or not is_instance_valid(dialog_content):
		return
	# A WindowDialog is not a Container: its children's minimum sizes do not
	# enlarge its background. The native stretched MarginContainer can overflow
	# after mod controls, longer translations or larger fonts are added.
	var required = dialog_content.get_combined_minimum_size()
	required += Vector2(dialog_content.margin_left - dialog_content.margin_right, dialog_content.margin_top - dialog_content.margin_bottom)
	required.x = max(original_dialog_minimum.x, required.x)
	required.y = max(original_dialog_minimum.y, required.y)
	var previous_size = export_dialog.rect_size
	# Retain a minimum imposed by another mod after our previous update.
	if export_dialog.rect_min_size != applied_dialog_minimum:
		original_dialog_minimum = export_dialog.rect_min_size
		required.x = max(original_dialog_minimum.x, required.x)
		required.y = max(original_dialog_minimum.y, required.y)
	applied_dialog_minimum = required
	export_dialog.rect_min_size = required
	export_dialog.rect_size = Vector2(max(previous_size.x, required.x), max(previous_size.y, required.y))
	if export_dialog.visible:
		var position = export_dialog.rect_position - (export_dialog.rect_size - previous_size) * 0.5
		var available = export_dialog.get_viewport_rect().size
		position.x = clamp(position.x, 0, max(0, available.x - export_dialog.rect_size.x))
		position.y = clamp(position.y, 0, max(0, available.y - export_dialog.rect_size.y))
		export_dialog.rect_position = position

func uninstall():
	if is_instance_valid(native_row):
		native_row.visible = native_row_visible
	if is_instance_valid(dialog_content) and dialog_content.is_connected("minimum_size_changed", self, "_queue_dialog_fit"):
		dialog_content.disconnect("minimum_size_changed", self, "_queue_dialog_fit")
	if is_instance_valid(export_dialog):
		if export_dialog.is_connected("about_to_show", self, "_queue_dialog_fit"):
			export_dialog.disconnect("about_to_show", self, "_queue_dialog_fit")
		if export_dialog.rect_min_size == applied_dialog_minimum:
			export_dialog.rect_min_size = original_dialog_minimum
	export_dialog = null
	dialog_content = null

func set_active(value):
	if active == value:
		if active:
			refresh()
		return
	active = value
	visible = active
	source.visible = not active
	if is_instance_valid(native_row):
		native_row.visible = not active and native_row_visible
	if active:
		refresh()
		if formats.selected >= 0:
			_selected(formats.selected)
	else:
		# Restore native quality-control behavior when leaving the integration.
		source.emit_signal("item_selected", source.selected)

func refresh():
	var labels = []
	for index in range(source.get_item_count()):
		labels.append(source.get_item_text(index))
	var signature = JSON.print(labels)
	if signature != source_signature:
		source_signature = signature
		formats.clear()
		for index in range(labels.size()):
			if labels[index] in excluded_labels:
				continue
			formats.add_item(labels[index])
			formats.set_item_metadata(formats.get_item_count() - 1, index)
	var selected = 0
	for index in range(formats.get_item_count()):
		if formats.get_item_metadata(index) == source.selected:
			selected = index
	formats.select(selected)
	# Translate our copy of the native formats without modifying host controls.
	for index in range(formats.get_item_count()):
		var native_index = int(formats.get_item_metadata(index))
		if native_index in [0, 1, 2, 3]:
			formats.set_item_text(index, preload("localization.gd").text(["PNG", "JPEG", "WebP", "Universal VTT"][native_index]))
	_sync_visibility()

func _selected(index):
	source.select(formats.get_item_metadata(index))
	source.emit_signal("item_selected", source.selected)
	_changed(null)

func _changed(_value):
	_sync_visibility()
	emit_signal("options_changed")

func _sync_visibility():
	visible = active or not legacy_spec.empty()
	formats.visible = active
	format_heading.visible = active and not format_heading.text.empty()
	var supported = (active and source != null and source.selected in [0, 1, 2, 3]) or not legacy_spec.empty()
	var uvtt = supported and ((active and source.selected == 3) or (not active and not legacy_spec.get("raster", true)))
	bake.visible = supported
	include_image.visible = uvtt
	levels.visible = uvtt
	multi_file.visible = supported
	embed.visible = uvtt
	var baked = bake.pressed and (not uvtt or include_image.pressed)
	embed.disabled = baked
	background.visible = uvtt
	background_row.visible = uvtt
	background.disabled = not include_image.pressed
	bake.disabled = uvtt and not include_image.pressed
	asset_row.visible = uvtt
	asset_format.disabled = uvtt and baked

func set_legacy_spec(value):
	legacy_spec = value
	_sync_visibility()

func selected_asset_format():
	return ASSET_FORMATS[asset_format.selected]

func spec():
	if (active and not source.selected in [0, 1, 2, 3]) or (not active and legacy_spec.empty()):
		return {}
	var uvtt = source.selected == 3 if active else not legacy_spec.raster
	var image_format = ["png", "jpg", "webp"][background.selected] if uvtt else (["png", "jpg", "webp"][source.selected] if active else legacy_spec.image)
	var baked = bake.pressed and (not uvtt or include_image.pressed)
	return {"key": image_format if uvtt else "raster_" + image_format, "image": image_format, "extension": "dd2vtt" if uvtt else image_format, "raster": not uvtt, "embed": embed.pressed and not baked, "bake": baked, "include_image": include_image.pressed or not uvtt, "levels": multi_file.pressed or (uvtt and levels.pressed), "multi_file": multi_file.pressed, "integrated": true, "asset_format": selected_asset_format()}
