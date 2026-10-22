extends Reference

const L = preload("../ui/localization.gd")
const Style = preload("../ui/overlay_style.gd")
const ColorSetting = preload("../ui/color_setting.gd")
const Crop = preload("crop_geometry.gd")
const Templates = preload("crop_templates.gd")
var crop_templates

const Component = preload("door_component.gd")
const Adapter = preload("host_adapter.gd")
const Factory = preload("component_factory.gd")
const Panel = preload("../ui/door_panel.gd")
const Overlay = preload("../ui/door_overlay.gd")
const Transaction = preload("export_transaction.gd")
const Contract = preload("export_contract.gd")
const Writer = preload("output_writer.gd")
const Geometry = preload("door_geometry.gd")
const Matcher = preload("portal_matcher.gd")
const ArtworkPreview = preload("../ui/artwork_preview.gd")
var artwork_preview

const ContextMenu = preload("../ui/door_context_menu.gd")
const SaveDialog = preload("../ui/export_file_dialog.gd")
const ClipboardBridge = preload("clipboard_bridge.gd")
const ExportControls = preload("../ui/export_controls.gd")
const LevelBatch = preload("level_export_batch.gd")

var host
var adapter
var map_accessor
var map_component
var doors
var levels
var level_ui
var panel
var tool_panel
var overlay
var timer
var format_options
var native_button
var animated_button
var overwrite_dialog
var overwrite_pending = false
var file_dialog
var busy_dialog
var busy_label
var transaction = Transaction.new()
var generation = 0
var elapsed = 0.0
var preview = true
var stopped = false
var original_native_visible = true
var overriding_button = false
var requested_format = "png"
var finish_frames = 0
var started_native = false
var cleanup_error = ""
var opaque_components = {}
var context_menu
var application_preferences
var editing_ids = []
var editing_active = false
var list_filter = 0
var selection_from_list = false
var native_selection_signature = ""
var all_overlay
var selection_overlay
var show_all_doors = false
var shortcut_registered = false
var standalone
var clipboard_bridge
var export_controls
var requested_spec = {}
var syncing_export = false
var amount_dialog
var amount_spin
var amount_ids = []
var amount_level
var settings_root
var localized_formats = {}
var mod_root = ""
var preference_defaults = {}
var native_export_idle_ticks = 0
var level_batch = {}
var native_export_defaults
const EXPORT_PREFERENCES = {
	"export_include_image": true, "export_bake": false, "export_embed": false,
	"export_levels": false, "export_multi_file": false, "export_overwrite": false, "export_background": "png", "export_asset_format": "original"
}
const EXPORTS = {
	"Universal VTT (Animated Doors)": {"key": "png", "image": "png", "extension": "dd2vtt", "raster": false, "embed": true},
	"Universal VTT (Animated Doors, WebP)": {"key": "webp", "image": "webp", "extension": "dd2vtt", "raster": false, "embed": true},
	"Universal VTT (Animated Doors, asset references)": {"key": "references", "image": "png", "extension": "dd2vtt", "raster": false, "embed": false},
	"PNG (without Animated Doors)": {"key": "raster_png", "image": "png", "extension": "png", "raster": true, "embed": false},
	"JPG (without Animated Doors)": {"key": "raster_jpg", "image": "jpg", "extension": "jpg", "raster": true, "embed": false},
	"WebP (without Animated Doors)": {"key": "raster_webp", "image": "webp", "extension": "webp", "raster": true, "embed": false},
	"Universal VTT (Animated Doors, JPG)": {"key": "jpg", "image": "jpg", "extension": "dd2vtt", "raster": false, "embed": true}
}

func _format_spec(key):
	for spec in EXPORTS.values():
		if spec.key == key:
			return spec
	return {}

func initialize(global_dictionary, entrypoint):
	host = global_dictionary
	adapter = Adapter.new(host)
	crop_templates = Templates.new(Engine.get_meta("AnimatedDoors.crop_templates_path") if Engine.has_meta("AnimatedDoors.crop_templates_path") else "")
	generation = OS.get_ticks_usec()
	var capabilities = adapter.probe_capabilities()
	# Settings remain usable if a host export interface cannot be verified.
	if not capabilities.ok:
		cleanup_error = capabilities.message
	var builder = host.API.ModConfigApi.create_config()
	mod_root = host.get("Root", get_script().resource_path.get_base_dir().plus_file("../.."))
	_build_settings(builder)
	settings_root = builder.get_root()
	var preferences = preload("preference_startup.gd").build(builder,adapter.dungeondraft_version())
	application_preferences = preferences
	for field in Component.EDIT_FIELDS:
		preference_defaults[field] = preferences.get(field)
	L.configure(preferences.language, mod_root)
	var defaults = {"enabled": false, "hinge_endpoint": preferences.hinge_endpoint, "swing_direction": preferences.swing_direction, "axis": "width", "list_layer_id": 2147483647}
	for field in Component.EDIT_FIELDS:
		defaults[field] = preferences.get(field)
	var components = host.API.ComponentsApi
	var persisted = host.ModMapData.get("CreepyCre._Lib", {}).get("ComponentsApi", {}).get("save_data", {}).get("AnimatedDoors", {})
	if persisted is Dictionary:
		for identifier in persisted:
			if not identifier in ["door", "map_settings", "level_elevation"]:
				opaque_components[identifier] = persisted[identifier].duplicate(true) if persisted[identifier] is Array or persisted[identifier] is Dictionary else persisted[identifier]
	if not opaque_components.empty():
		# Preserve opaque component identifiers after _Lib serializes registered
		# components. This is not a second store for this version's settings.
		host.API.ModSignalingApi.connect("save_begin", self, "_preserve_opaque_components")
	map_accessor = components.register("map_settings", Factory.new("map", null, defaults), components.FLAG_WORLD, false)
	map_component = map_accessor.get_component(host.World)
	# Load saved declarations but do not create a settings record for every
	# decorative object. Unassigned assets acquire one only when edited.
	doors = components.register("door", Factory.new("door", map_component), components.FLAG_PORTAL_FREE | components.FLAG_PROP, true)
	levels = components.register("level_elevation", Factory.new("level"), components.FLAG_LEVEL, true)
	level_ui = preload("../ui/level_elevations.gd").new(self)
	if map_component.read_only:
		return Geometry.failure("MAP_SETTINGS", map_component.issue)
	var icon_path = host.Root.plus_file("icons/swingdoor.png") if host.has("Root") else "res://ui/icons/misc/layer.png"
	tool_panel = host.Editor.Toolset.CreateModTool(entrypoint, "Settings", "AnimatedDoors", "Animated Doors", icon_path)
	panel = Panel.new()
	tool_panel.Align.add_child(panel)
	panel.connect("edit_requested", self, "_edit")
	panel.connect("default_requested", self, "_defaults")
	panel.connect("layer_requested", self, "_layer")
	panel.connect("selection_changed", self, "_list_selection")
	panel.connect("preview_changed", self, "_preview")
	panel.connect("artwork_preview_requested",self,"_play_artwork")
	panel.connect("preview_duration_changed",self,"_preview_duration_changed")
	panel.connect("apply_defaults_requested", self, "_apply_defaults")
	panel.connect("diagnostics_requested", self, "_diagnostics")
	panel.connect("reset_crop_requested", self, "_reset_crop")
	panel.connect("editing_changed", self, "_editing_changed")
	panel.connect("filter_changed", self, "_filter_changed")
	panel.connect("asset_activated", self, "_activate_asset")
	panel.connect("show_all_changed", self, "_show_all_changed")
	panel.connect("asset_toggle_requested", self, "_toggle_asset")
	context_menu = ContextMenu.new()
	host.Editor.add_child(context_menu)
	context_menu.connect("action_requested", self, "_context_action")
	context_menu.connect("show_all_requested", self, "_toggle_show_all")
	context_menu.connect("artwork_preview_requested",self,"_play_artwork")
	if not context_menu.install(adapter, doors, application_preferences.context_menu_enabled == true):
		panel.set_status("Selection menu unavailable on this host. See diagnostic report.")
	preferences.get("_context_menu_enabled").connect("updated", self, "_context_menu_enabled_changed")
	context_menu.shortcut_registered = shortcut_registered
	_update_menu_orders()
	for entry in ContextMenu.settings_entries():
		preferences.get("_" + entry[1]).connect("updated", self, "_menu_order_changed")
	artwork_preview = ArtworkPreview.new()
	artwork_preview.name = "AnimatedDoorsArtworkPreview"
	host.WorldUI.add_child(artwork_preview)
	artwork_preview.install(adapter,doors)
	if host.Editor.has_signal("OnSaveBegin"):
		host.Editor.connect("OnSaveBegin",self,"_stop_artwork")
	host.API.ModSignalingApi.connect("save_begin",self,"_stop_artwork")
	overlay = Overlay.new()
	overlay.name = "AnimatedDoorsPreview"
	overlay.visible = false
	host.WorldUI.add_child(overlay)
	all_overlay = Overlay.new()
	all_overlay.name = "AnimatedDoorsAllHighlights"
	all_overlay.hide()
	host.WorldUI.add_child(all_overlay)
	selection_overlay = Overlay.new()
	selection_overlay.name = "AnimatedDoorsListHighlight"
	selection_overlay.hide()
	selection_overlay.z_index = 1
	host.WorldUI.add_child(selection_overlay)
	preferences.get("_language").connect("updated", self, "_language_changed")
	for field in Component.EDIT_FIELDS:
		preferences.get("_" + field).connect("updated", self, "_default_preference_changed")
	for key in Style.DEFAULTS:
		preferences.get("_color_" + key).connect("updated", self, "_colors_changed")
	_colors_changed(null)
	_apply_startup_preferences()
	if standalone != null:
		standalone.attach(panel)
		standalone.flush()
	clipboard_bridge = ClipboardBridge.new()
	host.Editor.add_child(clipboard_bridge)
	clipboard_bridge.install(self)
	if not host.Editor.owner.is_connected("tree_exiting", self, "shutdown"):
		host.Editor.owner.connect("tree_exiting", self, "shutdown")
	timer = Timer.new()
	timer.wait_time = 0.1
	timer.connect("timeout", self, "_tick")
	host.Editor.add_child(timer)
	timer.start()
	if is_instance_valid(adapter.export_window) and adapter.export_window.find_node("ExportModeOptions", true, false) != null and adapter.export_window.find_node("OkayButton", true, false) != null:
		_install_export_controls()
	if not capabilities.ok:
		panel.set_status(cleanup_error)
	_refresh()
	_localize_controls()
	if not crop_templates.issue.empty():
		panel.set_status(crop_templates.issue)
	return Geometry.success(true)

func _build_settings(builder):
	var group = load(mod_root.plus_file("scripts/ui/settings_group.gd"))
	builder.add_node(group.new("General settings", true)).enter()
	var language_label = Label.new()
	language_label.text = "Language"
	builder.add_node(language_label)
	builder.option_button("language", 2, [{"label": "English", "meta": "en"}, {"label": "Deutsch", "meta": "de"}, {"label": "Dungeondraft (automatic)", "meta": "auto"}])
	builder.check_box("editing_enabled", true, "Enable animated door editing on startup")
	builder.check_box("context_menu_enabled", true, "Enable Animated Doors right-click menu")
	var compatibility_label = Label.new()
	compatibility_label.text = "Export dialog compatibility"
	builder.add_node(compatibility_label)
	builder.line_edit("export_dialog_compatibility", adapter.dungeondraft_version(), false).with("placeholder_text", adapter.dungeondraft_version()).with("hint_tooltip", "Enter the exact current Dungeondraft version to enable the compact export dialog. Empty or different: use legacy export formats.")
	if host.API.has("InputMapApi"):
		host.API.InputMapApi.add_actions({"Show all animated doors": [ContextMenu.OVERVIEW_ACTION, "Shift+D"],"Play animated door preview":[ContextMenu.PREVIEW_ACTION,"Ctrl+Shift+D"]})
		builder.shortcuts("shortcuts", {"Show all animated doors": ContextMenu.OVERVIEW_ACTION,"Play animated door preview":ContextMenu.PREVIEW_ACTION})
		shortcut_registered = true
	builder.exit()
	builder.add_node(group.new("Export defaults")).enter()
	var native_defaults_button = Button.new()
	native_defaults_button.text = "Additional export defaults"
	native_defaults_button.connect("pressed", self, "_open_export_defaults")
	builder.add_node(native_defaults_button)
	for entry in [["export_overwrite", "Overwrite existing level files without asking"], ["export_multi_file", "Multi file"], ["export_include_image", "Include map image"], ["export_bake", "Include animated doors in map image"], ["export_embed", "Embed door assets in UVTT (Base64)"], ["export_levels", "Export levels"]]:
		var label = Label.new()
		label.text = entry[1]
		builder.add_node(label)
		builder.option_button(entry[0], 0 if EXPORT_PREFERENCES[entry[0]] else 1, [{"label": "ON", "meta": true}, {"label": "OFF", "meta": false}])
	for entry in [["export_background", ["png", "jpg", "webp"]], ["export_asset_format", ["original", "png", "webp"]]]:
		var label = Label.new()
		label.text = "Export mode" if entry[0] == "export_background" else "Door asset format"
		builder.add_node(label)
		var choices = []
		for value in entry[1]:
			choices.append({"label": ("Original format" if value == "original" else value.to_upper()), "meta": value})
		builder.option_button(entry[0], 0, choices)
	builder.exit()
	builder.add_node(group.new("Panel defaults")).enter()
	builder.option_button("hinge_endpoint", 0, [{"label": "Hinge A", "meta": "begin"}, {"label": "Hinge B", "meta": "end"}])
	builder.option_button("swing_direction", 0, [{"label": "Swing right", "meta": "right"}, {"label": "Swing left", "meta": "left"}])
	builder.option_button("axis", 4, [{"label": "Default axis: image width", "meta": "width"}, {"label": "Default axis: image height", "meta": "height"}, {"label": "Default axis: the longer side", "meta": "longer"}, {"label": "Default axis: the shorter side", "meta": "shorter"}, {"label": "Default axis: visible artwork", "meta": "visible"}])
	builder.option_button("axis_fallback", 1, [{"label": "Axis fallback: image width", "meta": "width"}, {"label": "Axis fallback: image height", "meta": "height"}])
	for field in ["door_type", "animation_type", "door_state"]:
		var options = []
		for i in range(Panel.CHOICES[field].size()):
			options.append({"label": "Default " + Panel.LABELS[field][i], "meta": Panel.CHOICES[field][i]})
		builder.option_button(field, 0, options)
	builder.check_box("double_door", false, "Default Double door")
	for field in ["swing_degrees", "hinge_offset_a", "hinge_offset_b"]:
		var label = Label.new()
		label.text = "Default " + ("Door extension" if field == "swing_degrees" else ("Hinge A (triangle) offset" if field == "hinge_offset_a" else "Hinge B (circle) offset"))
		builder.add_node(label)
		builder.spin_box(field, Component.defaults()[field]).with("min_value", 0).with("max_value", 180 if field == "swing_degrees" else 1048576).with("step", 1 if field == "swing_degrees" else 0.001)
		if field != "swing_degrees":
			var spin = builder.get_current()
			spin.add_child(preload("../ui/pixel_step.gd").new(spin))
	builder.exit()
	builder.add_node(group.new("Overlay colors")).enter()
	for key in Style.DEFAULTS:
		var label = Label.new()
		label.text = Style.LABELS[key]
		builder.add_node(label)
		builder.color_picker_button("color_" + key, Style.DEFAULTS[key])
		# Both builders expose the actual newly added control, including _Lib
		# when it is nested in a wrapped scene or a flattened settings group.
		var storage = builder.get_current()
		storage.hide()
		builder.add_node(ColorSetting.new(storage))
	builder.exit()
	builder.add_node(group.new("Menu order")).enter()
	for section in ["Main menu", "Animated Doors", "Swing Type", "Door Type", "Door State"]:
		builder.add_node(group.new(section)).enter()
		for entry in ContextMenu.settings_entries():
			if ContextMenu.settings_group(entry[0]) != section:
				continue
			var label = Label.new()
			label.text = "Menu order: " + entry[2]
			builder.add_node(label)
			builder.spin_box(entry[1], entry[3]).with("min_value", -2147483648).with("max_value", 2147483647).with("step", 1).with("hint_tooltip", "Lower values appear first within the same menu; 0 hides this entry.")
		builder.exit()
	builder.exit()

func _colors_changed(_value):
	var palette = Style.palette(application_preferences)
	for drawing in [overlay, all_overlay, selection_overlay]:
		if is_instance_valid(drawing):
			drawing.set_colors(palette)

func _default_preference_changed(_value):
	var after = map_component.data.duplicate(true)
	var changed = false
	for field in Component.EDIT_FIELDS:
		var value = application_preferences.get(field)
		if value != preference_defaults[field]:
			preference_defaults[field] = value
			after.defaults[field] = value
			changed = true
	if changed and not Component.new(after, "map").read_only:
		_record([{"kind": "world", "before": map_component.data.duplicate(true), "after": after}])

func _language_changed(_value):
	L.configure(application_preferences.language, mod_root)
	panel.settings_signature = ""
	panel.layers_signature = ""
	panel.rows_signature = ""
	context_menu.hide()
	context_menu.update_commands(editing_ids)
	_refresh()
	_sync_export_button()
	_localize_controls()

func _localize_controls():
	for control in [settings_root, panel, export_controls, animated_button, overwrite_dialog, file_dialog, busy_dialog, amount_dialog]:
		L.apply_tree(control)
	if native_export_defaults != null:
		L.apply_tree(native_export_defaults.dialog)

func _localize_export_entries():
	if not is_instance_valid(format_options):
		return
	for index in range(format_options.get_item_count()):
		var label = format_options.get_item_text(index)
		if EXPORTS.has(label):
			localized_formats[index] = {"source": label, "translated": label}
		if not localized_formats.has(index):
			continue
		var saved = localized_formats[index]
		if not label in [saved.source, saved.translated]:
			localized_formats.erase(index)
			continue
		saved.translated = L.text(saved.source)
		format_options.set_item_text(index, saved.translated)
	if is_instance_valid(export_controls):
		export_controls.excluded_labels = EXPORTS.keys()
		for key in EXPORTS:
			export_controls.excluded_labels.append(L.text(key))

func _apply_startup_preferences():
	# Startup preferences apply to the default dropdown even on saved maps;
	# individual door records are never modified by these preferences.
	map_component.data.defaults.axis = application_preferences.axis
	editing_active = application_preferences.editing_enabled == true
	panel.editing_active = editing_active
	panel.editing_toggle.set_block_signals(true)
	panel.editing_toggle.pressed = editing_active
	panel.editing_toggle.set_block_signals(false)
	context_menu.set_editing(editing_active)

func _resolved_axis(node):
	var fallback = application_preferences.axis_fallback if application_preferences != null else "width"
	return adapter.default_axis(node, map_component.data.defaults.axis, fallback)

func _context_menu_enabled_changed(_value):
	context_menu.set_menu_enabled(application_preferences.context_menu_enabled == true)

func _menu_order_changed(_value):
	_update_menu_orders()

func _update_menu_orders():
	var orders = {}
	for entry in ContextMenu.settings_entries():
		orders[entry[0]] = int(application_preferences.get(entry[1]))
	context_menu.configure_orders(orders)

func _install_export_controls():
	var win = adapter.export_window
	format_options = win.find_node("ExportModeOptions", true, false)
	native_button = win.find_node("OkayButton", true, false)
	original_native_visible = native_button.visible
	animated_button = Button.new()
	animated_button.text = "Export Animated Doors"
	animated_button.visible = false
	native_button.get_parent().add_child(animated_button)
	native_button.get_parent().move_child(animated_button, native_button.get_index() + 1)
	animated_button.connect("pressed", self, "_choose_file")
	format_options.connect("item_selected", self, "_format_changed")
	win.connect("about_to_show", self, "_export_dialog_opened")
	native_button.connect("pressed", self, "_export_dialog_opened")
	export_controls = ExportControls.new()
	export_controls.install(format_options, EXPORTS.keys())
	native_export_defaults = preload("../ui/export_defaults.gd").new(win)
	win.connect("about_to_show", native_export_defaults, "apply")
	_export_preferences_changed(null)
	for key in EXPORT_PREFERENCES:
		application_preferences.get("_" + key).connect("updated", self, "_export_preferences_changed")
	export_controls.connect("options_changed", self, "_sync_export_button")
	file_dialog = SaveDialog.new()
	file_dialog.mode = FileDialog.MODE_SAVE_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = PoolStringArray(["*.dd2vtt ; Universal VTT with Animated Doors"])
	file_dialog.window_title = "Export Animated Doors"
	win.add_child(file_dialog)
	file_dialog.connect("file_selected", self, "_file_selected")
	overwrite_dialog = ConfirmationDialog.new()
	overwrite_dialog.window_title = "Overwrite level export files"
	overwrite_dialog.popup_exclusive = true
	win.add_child(overwrite_dialog)
	overwrite_dialog.connect("confirmed", self, "_overwrite_confirmed")
	overwrite_dialog.connect("popup_hide", self, "_overwrite_closed")
	busy_dialog = PopupPanel.new()
	busy_dialog.popup_exclusive = true
	busy_dialog.rect_min_size = Vector2(440, 100)
	var content = VBoxContainer.new()
	busy_dialog.add_child(content)
	busy_label = Label.new()
	busy_label.text = L.text("Preparing animated doors...")
	content.add_child(busy_label)
	var cancel = Button.new()
	cancel.text = "Discard result when rendering finishes"
	content.add_child(cancel)
	cancel.connect("pressed", self, "_cancel")
	win.add_child(busy_dialog)

func _request_level_overwrite(spec):
	if application_preferences.export_overwrite == true:
		return false
	var existing = []
	for target in level_batch.paths:
		if File.new().file_exists(target):
			existing.append(target)
	if existing.empty():
		return false
	requested_spec = spec.duplicate(true)
	overwrite_pending = true
	overwrite_dialog.dialog_text = L.text("Overwrite these existing level export files?") + "\n\n" + PoolStringArray(existing).join("\n")
	overwrite_dialog.popup_centered(Vector2(700, 300))
	return true

func _overwrite_confirmed():
	if not overwrite_pending or level_batch.empty():
		return
	overwrite_pending = false
	_file_selected(level_batch.path)

func _overwrite_closed():
	# ConfirmationDialog may hide before emitting confirmed.
	call_deferred("_cancel_pending_overwrite")

func _cancel_pending_overwrite():
	if overwrite_pending:
		_cleanup()

func _export_preferences_changed(_value):
	if not is_instance_valid(export_controls):
		return
	export_controls.include_image.pressed = application_preferences.export_include_image
	export_controls.bake.pressed = application_preferences.export_bake
	export_controls.embed.pressed = application_preferences.export_embed
	export_controls.levels.pressed = application_preferences.export_levels
	export_controls.multi_file.pressed = application_preferences.export_multi_file
	export_controls.background.select(max(0, ["png", "jpg", "webp"].find(application_preferences.export_background)))
	export_controls.asset_format.select(max(0, ExportControls.ASSET_FORMATS.find(application_preferences.export_asset_format)))

func _export_dialog_opened():
	_stop_artwork()
	# Native exports bypass _file_selected; suppress before their file dialog.
	_hide_overlays()
	adapter.suspend_export_selection()
	native_export_idle_ticks = 0
	_sync_export_button()

func _open_export_defaults():
	if native_export_defaults != null:
		native_export_defaults.open()

func _guard_native_export():
	if adapter.exporting() or (is_instance_valid(adapter.export_window) and adapter.export_window.visible):
		_stop_artwork()
	var visible = is_instance_valid(adapter.export_window) and adapter.export_window.visible
	if visible or adapter.exporting() or transaction.state != "IDLE":
		native_export_idle_ticks = 0
		if not adapter.export_selection_active:
			adapter.suspend_export_selection()
		_hide_overlays()
	elif adapter.export_selection_active:
		native_export_idle_ticks += 1
		if native_export_idle_ticks >= 2:
			adapter.restore_export_selection()

func _format_changed(_index):
	_sync_export_button()
	_hide_overlays()

func _hide_overlays():
	for drawing in [overlay, selection_overlay, all_overlay]:
		if is_instance_valid(drawing):
			drawing.hide()

func _selected_format():
	if is_instance_valid(export_controls) and export_controls.active:
		return export_controls.spec().get("key", "")
	if not is_instance_valid(format_options) or format_options.selected < 0:
		return ""
	var label = localized_formats.get(format_options.selected, {}).get("source", format_options.get_item_text(format_options.selected))
	return EXPORTS[label].key if EXPORTS.has(label) else ""

func _sync_export_button():
	if not is_instance_valid(native_button) or syncing_export:
		return
	syncing_export = true
	_localize_export_entries()
	if is_instance_valid(export_controls) and transaction.state == "IDLE" and not adapter.exporting() and not file_dialog.visible:
		var configured = str(application_preferences.export_dialog_compatibility)
		export_controls.set_active(format_options.get_item_count() >= 4 and adapter.integrated_export_allowed(configured))
	if is_instance_valid(export_controls) and export_controls.active:
		var spec = export_controls.spec()
		var quality = adapter.export_window.find_node("ImageQuality", true, false)
		if quality != null and not spec.empty():
			quality.visible = spec.image != "png"
		animated_button.text = "Export"
	else:
		animated_button.text = "Export Animated Doors"
	var active = not _selected_format().empty()
	if is_instance_valid(export_controls):
		var legacy_spec = _format_spec(_selected_format())
		export_controls.set_legacy_spec(legacy_spec if not export_controls.active else {})
		var quality = adapter.export_window.find_node("ImageQuality", true, false)
		var spec = export_controls.spec()
		if quality != null and not spec.empty():
			quality.visible = spec.image != "png" and spec.get("include_image", true)
	if active and not overriding_button:
		original_native_visible = native_button.visible
		native_button.visible = false
		overriding_button = true
	elif not active and overriding_button:
		native_button.visible = original_native_visible
		overriding_button = false
	animated_button.visible = active
	animated_button.disabled = transaction.state != "IDLE" or not level_batch.empty() or not cleanup_error.empty()
	animated_button.hint_tooltip = cleanup_error
	if adapter.export_window.visible:
		_hide_overlays()
	syncing_export = false
	L.apply_tree(animated_button)
	L.apply_tree(export_controls)

func _choose_file():
	if transaction.state != "IDLE" or not level_batch.empty() or adapter.exporting():
		return
	requested_format = _selected_format()
	if requested_format.empty():
		return
	var options = adapter.export_options(export_controls.spec().get("levels", false))
	if not options.ok:
		_message(options.message)
		return
	requested_spec = export_controls.spec().duplicate()
	requested_spec["asset_format"] = export_controls.selected_asset_format()
	requested_format = requested_spec.key
	var spec = requested_spec
	var description = "Map image" if spec.raster else "Universal VTT"
	if not spec.get("bake", false):
		description += " without animated door artwork" if spec.raster else " with Animated Doors"
	file_dialog.filters = PoolStringArray(["*." + spec.extension + " ; " + L.text(description)])
	var basename = file_dialog.saved_filename.get_basename() if not file_dialog.saved_filename.empty() else "animated-map"
	file_dialog.current_file = basename + "." + spec.extension
	L.apply_tree(file_dialog)
	file_dialog.popup_centered_ratio(0.7)

func _file_selected(path):
	if overwrite_pending:
		return
	_stop_artwork()
	if transaction.state != "IDLE" or adapter.exporting():
		_message("Another export is already active.")
		return
	var spec = requested_spec if not requested_spec.empty() else _format_spec(requested_format)
	if spec.empty() or not path.to_lower().ends_with("." + spec.extension):
		_message("Choose a filename matching the selected export format.")
		return
	var formats = Engine.get_meta("AnimatedDoors.formats") if Engine.has_meta("AnimatedDoors.formats") else {}
	if not formats.has(requested_format) or not is_instance_valid(formats[requested_format]):
		_message("The animated export format has not initialized. Reload this map and try again.")
		return
	var options = adapter.export_options(spec.get("levels", false))
	if not options.ok:
		_finish_error(options.message)
		return
	if spec.get("levels", false) and level_batch.empty():
		var prepared_levels = adapter.prepare_levels(levels)
		if not prepared_levels.ok:
			_message(prepared_levels.message)
			return
		level_batch = {"index": 0, "count": prepared_levels.value.size(), "sources": prepared_levels.value, "root": {}, "path": path}
		level_batch["metadata"] = LevelBatch.metadata(spec.get("multi_file", false), adapter.map_name())
		if spec.get("multi_file", false):
			var labels = []
			for index in prepared_levels.value:
				var level = Adapter.property(host.World, "AllLevels", [])[index]
				labels.append(preload("level_elevation.gd").label_info(Adapter.property(level, "Label", level.name)).level_name)
			level_batch["paths"] = LevelBatch.paths(path.get_base_dir(), labels, spec.extension, path.get_file().get_basename())
			level_batch["written_paths"] = []
			if _request_level_overwrite(spec):
				return
	if not level_batch.empty():
		if spec.get("multi_file", false):
			path = level_batch.paths[level_batch.index]
		var source_index = level_batch.sources[level_batch.index]
		adapter.select_export_level(source_index)
		options.value.level_id = str(source_index)
	var level_metadata = _level_metadata(adapter.current_level()) if not spec.raster else Geometry.success({})
	if not level_metadata.ok:
		_finish_error(level_metadata.message)
		return
	busy_dialog.popup_centered()
	options.value["raster_only"] = spec.raster
	options.value["bake"] = spec.get("bake", false)
	options.value["asset_format"] = spec.get("asset_format", "original")
	var collected = adapter.collect(map_component, doors, options.value)
	if not collected.ok:
		_finish_error(collected.message)
		return
	if collected.value.doors.empty() and not spec.raster and not spec.get("integrated", false):
		busy_dialog.hide()
		_message("No visible animated doors: %s candidate assets, %s declared, %s hidden. Enable animated door editing, select an asset with the Select tool, right-click, and choose Declare Animated Door. Layers only filter the list." % [collected.value.statistics.candidates, collected.value.statistics.declared, collected.value.statistics.hidden])
		return
	if not spec.raster:
		var mapping = Matcher.associate(Contract.portal_snapshots(collected.value.doors), collected.value.native.portals)
		if not mapping.ok:
			_finish_error(mapping.message)
			return
	var context = options.value.duplicate()
	context["native"] = collected.value.native
	context["doors"] = collected.value.doors
	context["assets"] = collected.value.assets
	context["format"] = requested_format
	context["spec"] = spec.duplicate()
	context["level_metadata"] = level_metadata.value
	context["final_path"] = path
	context["generation"] = generation
	context["previous_export_mod"] = Adapter.property(host.Exporter, "Mod")
	context["previous_export_quality"] = Adapter.property(host.Exporter, "Quality")
	var render_path = path + ".animated-render-" + str(OS.get_ticks_usec())
	var prepared = transaction.prepare(context, collected.value.visuals, render_path)
	if not prepared.ok:
		_finish_error(prepared.message)
		return
	_hide_overlays()
	var selection_hidden = adapter.suspend_export_selection()
	if not selection_hidden.ok:
		_finish_error(selection_hidden.message)
		return
	Engine.set_meta("AnimatedDoors.export_session", {"controller": self, "token": transaction.id, "path": render_path})
	if not transaction.suppress():
		_finish_error("A door disappeared before rendering.")
		return
	busy_label.text = L.text("Rendering map..." if spec.get("bake", false) else "Rendering map without animated door artwork...")
	started_native = false
	finish_frames = 0
	# Native capture itself waits for frame draws. Start after our visibility
	# changes reached the rendering server; never use a fixed delay as a gate.
	yield (VisualServer, "frame_post_draw")
	if stopped or transaction.state != "CAPTURING":
		return
	if transaction.cancelled:
		_finish_error("Export cancelled before rendering.")
		return
	started_native = true
	adapter.begin_export(formats[requested_format], context.ppi, context.quality, render_path)

# Export entrypoints only read the borrowed file and defer here. All host reads,
# scene changes, texture work, validation and file commit occur on the main thread.
func receive_image(token, bytes, path, ppi):
	if stopped:
		return
	if transaction.accept_image(token, bytes, path, ppi):
		transaction.restore_visuals()

func receive_error(token, message):
	if token == transaction.id:
		transaction.failure = message

func _tick():
	if stopped:
		return
	if level_ui != null:
		level_ui.refresh()
	_guard_native_export()
	if crop_templates != null:
		var saved = crop_templates.tick()
		if not saved.ok:
			panel.set_status(saved.message)
	if application_preferences.language == "auto" and Engine.get_meta(L.META).language != L.host_language():
		_language_changed(null)
	if transaction.state == "CAPTURING":
		if not started_native:
			return
		if adapter.exporting():
			finish_frames = 0
			return
		# The native IsExporting flag is reset only after the final render and
		# viewport restoration. One additional tick lets deferred callbacks drain.
		finish_frames += 1
		if finish_frames < 2:
			return
		if transaction.cancelled:
			_finish_error("Export discarded. The previous destination was preserved.")
		elif not transaction.failure.empty():
			_finish_error(transaction.failure)
		elif not transaction.callback_received:
			_finish_error("Dungeondraft ended rendering without supplying an image.")
		else:
			_complete()
		return
	if transaction.state != "IDLE":
		return
	_sync_export_button()
	elapsed += 0.1
	if elapsed >= 0.5:
		elapsed = 0.0
		_refresh()

func _complete():
	transaction.state = "ASSEMBLING"
	transaction.restore_visuals()
	busy_label.text = L.text("Validating and saving export...")
	var snapshot = transaction.snapshot
	var spec = snapshot.get("spec", _format_spec(snapshot.format))
	if spec.raster:
		transaction.state = "WRITING"
		var written = Writer.new().write_image(snapshot.final_path, transaction.image_bytes, transaction.id, spec.image)
		if not written.ok:
			_finish_error(written.message)
			return
		var notice = "Saved map to " + snapshot.final_path if spec.get("bake", false) else "Saved map without %s animated doors to %s" % [snapshot.doors.size(), snapshot.final_path]
		if not written.value.notice.empty():
			notice += "\n" + written.value.notice
		if _next_level_file():
			return
		notice = _batch_summary(notice)
		_cleanup()
		_message(notice)
		return
	var native = snapshot.native
	for field in snapshot.get("level_metadata", {}):
		native[field] = snapshot.level_metadata[field]
	# exportOrigin/exportSize are initialized by native capture, not by the
	# preceding options dialog. Read them now, after native capture has ended.
	native.resolution = host.Exporter.ExportResolution(snapshot.ppi).duplicate(true)
	native.image = Marshalls.raw_to_base64(transaction.image_bytes) if spec.get("include_image", true) else ""
	if spec.get("bake", false):
		Contract.mark_unanimated_portals(native)
		_commit_document(native, spec)
		return
	var assembled = Contract.assemble(native, snapshot.doors, snapshot.assets, snapshot.level_id, ("image/jpeg" if spec.image == "jpg" else "image/" + spec.image), spec.embed)
	if not assembled.ok:
		_finish_error(assembled.message)
		return
	_commit_document(assembled.value, spec)

func _commit_document(data, spec):
	var path = transaction.snapshot.final_path
	if not level_batch.empty() and spec.get("multi_file", false):
		data["Levels"] = level_batch.metadata.duplicate(true)
	elif not level_batch.empty():
		if level_batch.index == 0:
			level_batch.root = data
			level_batch.root["Levels"] = {}
		else:
			level_batch.root.Levels[str(level_batch.index)] = data
		level_batch.index += 1
		if level_batch.index < level_batch.count:
			_release_capture()
			transaction.cleanup()
			_file_selected(path)
			return
		data = level_batch.root
		for field in level_batch.get("metadata", {}):
			data.Levels[field] = level_batch.metadata[field]
	transaction.state = "WRITING"
	var writer = Writer.new()
	var result = writer.write_native(path, data, transaction.id, ("image/jpeg" if spec.image == "jpg" else "image/" + spec.image)) if spec.get("bake", false) else writer.write(path, data, transaction.id)
	if not result.ok:
		_finish_error(result.message)
		return
	var counts = Contract.export_counts(data)
	var message = L.text("Saved %s animated doors and %s non-animated portals to %s") % [counts.animated, counts.normal, path]
	if not result.value.notice.empty():
		message += "\n" + result.value.notice
	if _next_level_file():
		return
	message = _batch_summary(message)
	_cleanup()
	_message(message)

func _batch_summary(fallback):
	var paths = level_batch.get("written_paths", [])
	if paths.size() < 2:
		return fallback
	return L.text("Export complete. Saved files:") + "\n\n" + PoolStringArray(paths).join("\n")

func _next_level_file():
	if level_batch.empty() or not transaction.snapshot.get("spec", {}).get("multi_file", false):
		return false
	if not level_batch.has("written_paths"):
		level_batch["written_paths"] = []
	level_batch.written_paths.append(transaction.snapshot.final_path)
	level_batch.index += 1
	if level_batch.index >= level_batch.count:
		return false
	var path = level_batch.path
	_release_capture()
	transaction.cleanup()
	_file_selected(path)
	return true

func _cancel():
	transaction.cancelled = true
	busy_label.text = L.text("Waiting for native rendering to finish; result will be discarded.")

func _finish_error(message):
	_cleanup()
	_message(message)

func _release_capture():
	if Engine.has_meta("AnimatedDoors.export_session") and Engine.get_meta("AnimatedDoors.export_session").get("controller") == self:
		Engine.remove_meta("AnimatedDoors.export_session")
	# Native code normally deletes its .temp file. Remove our own leftover only
	# after native rendering stopped; final destination is managed by Writer.
	if not adapter.exporting() and not transaction.path.empty():
		var dir = Directory.new()
		var temp = transaction.path + ".temp"
		if dir.file_exists(temp) and dir.remove(temp) != OK:
			print("[Animated Doors] Render temporary file retained: ", temp)
		if transaction.snapshot.has("previous_export_mod"):
			host.Exporter.Mod = transaction.snapshot.previous_export_mod
		if transaction.snapshot.get("previous_export_quality") != null:
			host.Exporter.Quality = transaction.snapshot.previous_export_quality

func _cleanup():
	_release_capture()
	transaction.cleanup()
	adapter.restore_levels()
	level_batch = {}
	overwrite_pending = false
	if not is_instance_valid(adapter.export_window) or not adapter.export_window.visible:
		adapter.restore_export_selection()
	if is_instance_valid(busy_dialog):
		busy_dialog.hide()
	_refresh()
	_sync_export_button()

func _message(message):
	message = L.text(message)
	print("[Animated Doors] ", message)
	if is_instance_valid(panel):
		panel.set_status(message)
	if is_instance_valid(host.Editor) and host.Editor.has_method("Warn"):
		host.Editor.Warn("Animated Doors", message)

func _refresh():
	if not is_instance_valid(panel) or transaction.state != "IDLE":
		return
	if map_component != null:
		panel.set_preview_duration(map_component.data.preview_animation_duration_ms)
	var rows = []
	for portal in adapter.list_assets():
		var declared = is_declared(portal)
		if (list_filter == 0 and not declared) or (list_filter == 2 and declared):
			continue
		if map_component.data.list_layer_id != 2147483647 and adapter.layer_id(portal) != int(map_component.data.list_layer_id):
			continue
		var texture = Adapter.property(portal, "Texture")
		var label = texture.resource_path.get_file().get_basename() if texture != null else L.text("Missing texture")
		rows.append({"id": str(int(portal.get_meta("node_id"))), "declared": declared, "label": L.text("%s | %s | layer %s | %s") % [portal.get_meta("node_id"), L.text("Door" if declared else "Unassigned"), adapter.layer_id(portal), label]})
	var layers = host.API.LayerApi.get_layers(adapter.current_level()).duplicate()
	layers[2147483647] = "All layers"
	panel.populate(rows, layers, map_component.data.list_layer_id, map_component.data.defaults)
	var native_ids = adapter.selected_assets()
	native_ids.sort()
	var signature = JSON.print(native_ids)
	if Adapter.property(host.Editor, "ActiveTool") == host.Editor.Tools.get("SelectTool") and (not selection_from_list or signature != native_selection_signature):
		selection_from_list = false
		_selection(native_ids)
	else:
		_selection(panel.selected_ids())
	native_selection_signature = signature

func is_declared(node):
	if not doors.has_component(node):
		return false
	var component = doors.get_component(node)
	return not component.read_only and component.data.enabled

func _list_selection(ids):
	selection_from_list = true
	var native_ids = adapter.selected_assets()
	native_ids.sort()
	native_selection_signature = JSON.print(native_ids)
	_selection(ids)

func _filter_changed(mode):
	list_filter = mode
	_refresh()

func _editing_changed(active):
	if not active:
		_stop_artwork()
	editing_active = active
	panel.editing_active = active
	panel.editing_toggle.set_block_signals(true)
	panel.editing_toggle.pressed = active
	panel.editing_toggle.set_block_signals(false)
	context_menu.set_editing(active)
	_selection(editing_ids)

func _activate_asset(id):
	var result = adapter.select_asset(id)
	if not result.ok:
		_message(result.message)
		return
	selection_from_list = false
	_selection([id])

func _toggle_show_all():
	_show_all_changed(not show_all_doors)

func _show_all_changed(active):
	show_all_doors = active
	panel.show_all_toggle.set_block_signals(true)
	panel.show_all_toggle.pressed = active
	panel.show_all_toggle.set_block_signals(false)
	_refresh_highlights()

func _highlight_entry(node, draw_door):
	var entry = {"id": str(int(node.get_meta("node_id"))), "outline": adapter.artwork_outline(node), "declared": is_declared(node)}
	if entry.declared:
		entry["door_type"] = doors.get_component(node).data.door_type
	if draw_door and entry.declared:
		var data = doors.get_component(node).data
		var bounds = adapter.artwork_bounds(node, data.axis)
		if bounds.ok:
			entry["a"] = Geometry.vector(bounds.value[0])
			entry["b"] = Geometry.vector(bounds.value[1])
			entry["settings"] = data.duplicate(true)
			# Preview the same inward-rounded pixel boundaries as the exporter.
			var context = _crop_context(node)
			if context.ok:
				var cut = Crop.for_settings(context.value, data)
				if cut.ok:
					var effective = Crop.offsets(context.value, data.axis, cut.value)
					for field in effective:
						entry.settings[field] = effective[field]
			entry["offset_scale"] = float(Adapter.property(host.World, "TileSize", 256)) / 256.0
			entry["hinge"] = data.hinge_endpoint
			entry["swing"] = data.swing_direction
			entry["preview"] = preview
	return entry

func _refresh_highlights():
	if not is_instance_valid(all_overlay) or not is_instance_valid(selection_overlay):
		return
	all_overlay.hide()
	selection_overlay.hide()
	if stopped or (is_instance_valid(artwork_preview) and artwork_preview.active) or transaction.state != "IDLE" or adapter.exporting() or (is_instance_valid(adapter.export_window) and adapter.export_window.visible):
		return
	var all_items = []
	var selected_items = []
	for node in adapter.list_assets():
		if not adapter.visible_artwork(node):
			continue
		if show_all_doors and is_declared(node):
			all_items.append(_highlight_entry(node, true))
		if selection_from_list and tool_panel.is_visible_in_tree() and str(int(node.get_meta("node_id"))) in editing_ids:
			var selected = _highlight_entry(node, false)
			selected["selected"] = true
			selected_items.append(selected)
	all_overlay.show_many(all_items)
	selection_overlay.show_many(selected_items)

func _selection(ids):
	if is_instance_valid(artwork_preview) and artwork_preview.active:
		var ordered = ids.duplicate()
		ordered.sort()
		if ordered != artwork_preview.ids:
			_stop_artwork()
		else:
			_hide_overlays()
			return
	editing_ids = ids.duplicate()
	var values = []
	var eligible = adapter.list_assets()
	for id in ids:
		var node = adapter.resolve_node(id)
		if node != null and node in eligible:
			var component = doors.get_component(node)
			if not component.read_only:
				values.append(component.data)
	panel.show_settings(values)
	overlay.hide()
	var export_window_open = is_instance_valid(adapter.export_window) and adapter.export_window.visible
	var selection_tool_active = Adapter.property(host.Editor, "ActiveTool") == host.Editor.Tools.get("SelectTool")
	if editing_active and (tool_panel.is_visible_in_tree() or selection_tool_active) and transaction.state == "IDLE" and not adapter.exporting() and not export_window_open:
		var entries = []
		for id in ids:
			var node = adapter.resolve_node(id)
			if node != null and node in eligible and is_declared(node) and adapter.visible_artwork(node):
				entries.append(_highlight_entry(node, true))
		overlay.show_many(entries)
	_refresh_highlights()

func _preview(enabled):
	preview = enabled
	context_menu.preview_active = preview
	_selection(editing_ids)

func _edit(field, value):
	if editing_active:
		_edit_ids({field: value}, editing_ids)

func _edit_ids(fields, ids):
	_stop_artwork()
	if transaction.state != "IDLE":
		return
	var changes = []
	var templates = []
	var eligible = adapter.list_assets()
	for id in ids:
		var node = adapter.resolve_node(id)
		if node == null or not node in eligible:
			continue
		var component = doors.get_component(node)
		if component.read_only:
			continue
		if not fields.has("enabled") and not component.data.enabled:
			continue
		var after = component.data.duplicate(true)
		var new_declaration = fields.get("enabled", false) and not after.enabled
		if fields.get("enabled", false) and not after.enabled:
			for key in Component.EDIT_FIELDS:
				after[key] = map_component.data.defaults[key]
			after.axis = _resolved_axis(node)
		for field in fields:
			after[field] = fields[field]
		if new_declaration or (fields.has("axis") and after.axis != component.data.axis):
			_load_crop_template(node, after)
			for field in ["hinge_offset_a", "hinge_offset_b"]:
				if fields.has(field):
					after[field] = fields[field]
		if fields.has("enabled") and not fields.enabled:
			after = Component.new().data
		if Component.new(after).read_only:
			_message("Crop offsets must be finite, non-negative numbers.")
			return
		if after.enabled and (new_declaration or fields.has("axis") or fields.has("hinge_offset_a") or fields.has("hinge_offset_b")):
			var context = _crop_context(node)
			var cut = Crop.for_settings(context.value, after) if context.ok else context
			if not cut.ok:
				_message(cut.message)
				return
			if fields.has("hinge_offset_a") or fields.has("hinge_offset_b"):
				templates.append({"context": context.value, "axis": after.axis, "crop": cut.value})
		var filename = Component.texture_name(node)
		if after.enabled and not filename.empty():
			after.animation_texture = filename
		changes.append({"kind": "portal", "id": id, "before": component.data.duplicate(true), "after": after})
	_record(changes)
	for item in templates:
		crop_templates.remember(item.context, item.axis, item.crop)
	if not templates.empty() and not crop_templates.writable:
		panel.set_status(crop_templates.issue)

func _crop_context(node):
	return Crop.context(Adapter.property(node, "Sprite"), float(Adapter.property(adapter.host.World, "TileSize", 256)))

func _load_crop_template(node, settings):
	if crop_templates == null:
		crop_templates = Templates.new(Engine.get_meta("AnimatedDoors.crop_templates_path") if Engine.has_meta("AnimatedDoors.crop_templates_path") else "")
	for field in ["hinge_offset_a", "hinge_offset_b"]:
		settings[field] = map_component.data.defaults[field]
	var context = _crop_context(node)
	if not context.ok:
		panel.set_status(context.message)
		return
	var found = crop_templates.lookup(context.value, settings.axis)
	if not found.ok:
		panel.set_status(found.message)
	elif found.value != null:
		for field in found.value:
			settings[field] = found.value[field]

func _reset_crop():
	if not editing_active or transaction.state != "IDLE":
		return
	for id in editing_ids:
		var node = adapter.resolve_node(id)
		if node == null or not is_declared(node):
			continue
		var context = _crop_context(node)
		if context.ok:
			crop_templates.reset(context.value, doors.get_component(node).data.axis)
	panel.set_status("Crop template reset. Existing door settings are unchanged." if crop_templates.writable else crop_templates.issue)

func _defaults(field, value):
	var after = map_component.data.duplicate(true)
	after.defaults[field] = value
	if Component.new(after, "map").read_only:
		return
	_record([ {"kind": "world", "before": map_component.data.duplicate(true), "after": after}])

func _layer(id):
	var after = map_component.data.duplicate(true)
	after.list_layer_id = int(id)
	_record([ {"kind": "world", "before": map_component.data.duplicate(true), "after": after}])

func _apply_defaults():
	if not editing_active:
		return
	var changes = []
	for id in editing_ids:
		var node = adapter.resolve_node(id)
		if node == null:
			continue
		var component = doors.get_component(node)
		if component.read_only or not component.data.enabled:
			continue
		var after = component.data.duplicate(true)
		for key in Component.EDIT_FIELDS:
			after[key] = map_component.data.defaults[key]
		after.axis = _resolved_axis(node)
		_load_crop_template(node, after)
		var context = _crop_context(node)
		var cut = Crop.for_settings(context.value, after) if context.ok else context
		if not cut.ok:
			_message(cut.message)
			return
		changes.append({"kind": "portal", "id": id, "before": component.data.duplicate(true), "after": after})
	_record(changes)

func _context_action(action, ids):
	if not editing_active or stopped or transaction.state != "IDLE" or adapter.exporting():
		return
	var choices = {1: {"enabled": true}, 2: {"enabled": false}, 3: {"hinge_endpoint": "begin"}, 4: {"hinge_endpoint": "end"}, 5: {"swing_direction": "left"}, 6: {"swing_direction": "right"}, 7: {"axis": "width"}, 8: {"axis": "height"}}
	if ContextMenu.FIELDS.has(action) and action != 40:
		var setting = ContextMenu.FIELDS[action]
		choices[action] = {setting[0]: setting[1]}
	if action in [10, 11, 40]:
		_toggle_ids(ids, "hinge_endpoint" if action == 10 else ("swing_direction" if action == 11 else "double_door"))
	if action == 41:
		_open_amount(ids)
	if choices.has(action):
		_edit_ids(choices[action], ids)
	if action == 9:
		preview = not preview
		context_menu.preview_active = preview
		panel.preview_toggle.set_block_signals(true)
		panel.preview_toggle.pressed = preview
		panel.preview_toggle.set_block_signals(false)
	_selection(ids)

func _toggle_ids(ids, field):
	var changes = []
	for id in ids:
		var node = adapter.resolve_node(id)
		if node == null or not node in adapter.list_assets():
			continue
		var component = doors.get_component(node)
		if component.read_only or not component.data.enabled:
			continue
		var after = component.data.duplicate(true)
		if field == "hinge_endpoint":
			after[field] = "end" if after[field] == "begin" else "begin"
		elif field == "swing_direction":
			after[field] = "left" if after[field] == "right" else "right"
		else:
			after[field] = not after[field]
		changes.append({"kind": "portal", "id": id, "before": component.data.duplicate(true), "after": after})
	_record(changes)

func _open_amount(ids):
	if not is_instance_valid(amount_dialog):
		amount_dialog = ConfirmationDialog.new()
		amount_dialog.window_title = "Door extension (0-180)"
		host.Editor.add_child(amount_dialog)
		var row = HBoxContainer.new()
		amount_dialog.add_child(row)
		amount_spin = SpinBox.new()
		amount_spin.min_value = 0
		amount_spin.max_value = 180
		amount_spin.step = 1
		amount_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(amount_spin)
		var reset = Button.new()
		reset.text = "90"
		reset.connect("pressed", self, "_reset_context_amount")
		row.add_child(reset)
		amount_dialog.connect("confirmed", self, "_confirm_amount")
	amount_ids = ids.duplicate()
	amount_level = adapter.current_level()
	amount_spin.value = map_component.data.defaults.swing_degrees
	if not ids.empty():
		var node = adapter.resolve_node(ids[0])
		if node != null:
			amount_spin.value = doors.get_component(node).data.swing_degrees
	L.apply_tree(amount_dialog)
	amount_dialog.popup_centered(Vector2(330, 110))

func _reset_context_amount():
	amount_spin.value = 90

func _confirm_amount():
	if not stopped and editing_active and transaction.state == "IDLE" and not adapter.exporting() and is_instance_valid(amount_level) and amount_level == adapter.current_level():
		_edit_ids({"swing_degrees": int(amount_spin.value)}, amount_ids)

func _toggle_asset(id, field):
	if not editing_active or stopped or transaction.state != "IDLE" or adapter.exporting():
		return
	var node = adapter.resolve_node(id)
	if node == null or not node in adapter.list_assets():
		return
	var component = doors.get_component(node)
	if component.read_only:
		return
	var choices = {"enabled": [false, true], "hinge_endpoint": ["begin", "end"], "swing_direction": ["right", "left"]}
	if not choices.has(field) or (field != "enabled" and not component.data.enabled):
		return
	var values = choices[field]
	_edit_ids({field: values[1] if component.data[field] == values[0] else values[0]}, [id])

func _record(changes):
	if transaction.state != "IDLE" or changes.empty():
		return
	var record = SettingsRecord.new(self, generation, changes)
	record.redo()
	host.API.HistoryApi.record(record)

func _level_metadata(level):
	var component = levels.get_component(level)
	if component.read_only:
		return Geometry.failure("LEVEL_SETTINGS", component.issue)
	if component.data.top < component.data.bottom:
		return Geometry.failure("LEVEL_SETTINGS", "Level top must be greater than or equal to bottom.")
	var label = Adapter.property(level, "Label", level.name)
	return Geometry.success({"level_name": preload("level_elevation.gd").label_info(label).level_name, "bottom": int(component.data.bottom), "top": int(component.data.top)})

func _level_elevation_changed(level, field, value):
	if not is_instance_valid(level) or not field in ["bottom", "top"] or not preload("level_elevation.gd").integer(value):
		return
	var component = levels.get_component(level)
	if component.read_only or component.data[field] == value:
		return
	var after = component.data.duplicate(true)
	after[field] = int(value)
	_record([{"kind": "level", "level": weakref(level), "before": component.data.duplicate(true), "after": after}])

func _level_export_changed(level, enabled):
	if not is_instance_valid(level) or not enabled is bool:
		return
	var component = levels.get_component(level)
	if component.read_only or component.data.export_enabled == enabled:
		return
	var after = component.data.duplicate(true)
	after.export_enabled = enabled
	_record([{"kind": "level", "level": weakref(level), "before": component.data.duplicate(true), "after": after}])

func apply_history(changes, side, expected_generation):
	_stop_artwork()
	if stopped or generation != expected_generation:
		return
	for change in changes:
		var component = map_component
		if change.kind == "portal":
			var node = adapter.resolve_node(change.id)
			if node == null:
				continue
			component = doors.get_component(node)
		elif change.kind == "level":
			var level = change.level.get_ref()
			if not is_instance_valid(level):
				continue
			component = levels.get_component(level)
		if not component.read_only:
			component.data = change[side].duplicate(true)
	if standalone != null:
		standalone.flush()
	if level_ui != null:
		level_ui.refresh()
	_refresh()

func _diagnostics():
	var file = File.new()
	var path = "user://animated_doors_diagnostics.json"
	if file.open(path, File.WRITE) != OK:
		_message("Could not write the diagnostic report.")
		return
	file.store_string(JSON.print(adapter.diagnostic_report(doors, map_component), "  "))
	file.close()
	_message("Diagnostic report: " + ProjectSettings.globalize_path(path))

func _preserve_opaque_components():
	var table = host.ModMapData.get("CreepyCre._Lib", {}).get("ComponentsApi", {}).get("save_data", {}).get("AnimatedDoors", {})
	for identifier in opaque_components:
		table[identifier] = opaque_components[identifier]

func shutdown():
	_stop_artwork()
	if level_ui != null:
		level_ui.detach()
	if is_instance_valid(artwork_preview):
		artwork_preview.queue_free()
	if is_instance_valid(host.Editor) and host.Editor.is_connected("OnSaveBegin",self,"_stop_artwork"):
		host.Editor.disconnect("OnSaveBegin",self,"_stop_artwork")
	if host.API.has("ModSignalingApi") and host.API.ModSignalingApi.is_connected("save_begin",self,"_stop_artwork"):
		host.API.ModSignalingApi.disconnect("save_begin",self,"_stop_artwork")
	if stopped:
		return
	stopped = true
	if native_export_defaults != null:
		if is_instance_valid(adapter.export_window) and adapter.export_window.is_connected("about_to_show", native_export_defaults, "apply"):
			adapter.export_window.disconnect("about_to_show", native_export_defaults, "apply")
		if is_instance_valid(native_export_defaults.dialog):
			native_export_defaults.dialog.queue_free()
		native_export_defaults = null
	if crop_templates != null:
		var saved = crop_templates.flush()
		if not saved.ok:
			print("[Animated Doors] ", saved.message)
	if is_instance_valid(clipboard_bridge):
		clipboard_bridge.detach()
		clipboard_bridge.queue_free()
	if is_instance_valid(context_menu):
		context_menu.detach()
		context_menu.queue_free()
	transaction.cleanup()
	adapter.restore_levels()
	level_batch = {}
	overwrite_pending = false
	adapter.restore_export_selection()
	if Engine.has_meta("AnimatedDoors.controller") and Engine.get_meta("AnimatedDoors.controller") == self:
		Engine.remove_meta("AnimatedDoors.controller")
	if Engine.has_meta("AnimatedDoors.export_session") and Engine.get_meta("AnimatedDoors.export_session").get("controller") == self:
		Engine.remove_meta("AnimatedDoors.export_session")
	if is_instance_valid(native_button) and overriding_button:
		native_button.visible = original_native_visible
	if is_instance_valid(format_options) and format_options.is_connected("item_selected", self, "_format_changed"):
		format_options.disconnect("item_selected", self, "_format_changed")
	if is_instance_valid(format_options):
		for index in localized_formats:
			if index < format_options.get_item_count() and format_options.get_item_text(index) == localized_formats[index].translated:
				format_options.set_item_text(index, localized_formats[index].source)
	if is_instance_valid(export_controls):
		export_controls.uninstall()
		format_options.show()
		export_controls.queue_free()
	if is_instance_valid(adapter.export_window) and adapter.export_window.is_connected("about_to_show", self, "_export_dialog_opened"):
		adapter.export_window.disconnect("about_to_show", self, "_export_dialog_opened")
	if is_instance_valid(native_button) and native_button.is_connected("pressed", self, "_export_dialog_opened"):
		native_button.disconnect("pressed", self, "_export_dialog_opened")
	for node in [amount_dialog, timer, overlay, selection_overlay, all_overlay, animated_button, overwrite_dialog, file_dialog, busy_dialog, panel]:
		if is_instance_valid(node):
			node.queue_free()
	if standalone != null:
		standalone.shutdown()
		standalone = null

class SettingsRecord:
	extends Reference
	var owner_ref
	var generation
	var changes
	func _init(controller, session, values):
		owner_ref = weakref(controller)
		generation = session
		changes = values.duplicate(true)
	func undo():
		var controller = owner_ref.get_ref()
		if controller != null:
			controller.apply_history(changes, "before", generation)
	func redo():
		var controller = owner_ref.get_ref()
		if controller != null:
			controller.apply_history(changes, "after", generation)

func _stop_artwork():
	if is_instance_valid(artwork_preview):
		artwork_preview.cancel()

func _play_artwork():
	if not editing_active or transaction.state != "IDLE" or adapter.exporting():
		return
	var selected = adapter.selected_assets()
	if selection_from_list and is_instance_valid(tool_panel) and tool_panel.is_visible_in_tree():
		selected = editing_ids.duplicate()
	elif selected.empty():
		selected = editing_ids.duplicate()
	var played = artwork_preview.play(selected,map_component.data.preview_animation_duration_ms)
	if played.ok:
		_hide_overlays()
	else:
		panel.set_status(played.message)

func _preview_duration_changed(value):
	if map_component.read_only or not Geometry.number(value) or value <= 0:
		return
	var after = map_component.data.duplicate(true)
	after.preview_animation_duration_ms = value
	_record([{"kind":"world","before":map_component.data.duplicate(true),"after":after}])
