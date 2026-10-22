extends PopupMenu

const Host = preload("context_menu_host.gd")

const L = preload("localization.gd")

signal action_requested(action, ids)
signal show_all_requested
signal artwork_preview_requested

var adapter
var content_control
var selected_ids = []
var press_position = Vector2.ZERO
var right_pressed = false
var editing_active = false
var door_accessor
var hosted_ids = []
var hosted_level
var provider_blocks = []
var menu_orders = {}
var command_state = {}
var shortcut_registered = false
var preview_active = true
var compatibility_level
var menu_enabled = true
var host_capability = -1
var checked_handler
var probe_requested = false
var patch_blocker
const PROPERTY_LABELS = {3: "Hinge A (triangle)", 4: "Hinge B (circle)", 5: "Swing left", 6: "Swing right", 7: "Axis: image width", 8: "Axis: image height", 9: "Preview swing"}
const FIELDS = {3: ["hinge_endpoint", "begin"], 4: ["hinge_endpoint", "end"], 5: ["swing_direction", "left"], 6: ["swing_direction", "right"], 7: ["axis", "width"], 8: ["axis", "height"], 20: ["animation_type", "swing"], 21: ["animation_type", "slide"], 22: ["animation_type", "swivel"], 23: ["animation_type", "ascend"], 24: ["animation_type", "descend"], 30: ["door_type", 2], 31: ["door_type", -1], 32: ["door_type", 1], 40: ["double_door", true], 50: ["door_state", "closed"], 51: ["door_state", "open"], 52: ["door_state", "locked"]}
const TOP_IDS = [1, 2, 100, 10, 11]
const LABELS = {1: "Declare Animated Door", 2: "Remove Animated Door assignment", 10: "Toggle Hinge", 11: "Toggle Swing", 20: "swing", 21: "slide", 22: "swivel", 23: "ascend", 24: "descend", 30: "Hidden door", 31: "Window", 32: "Door", 40: "Double door", 41: "Door extension...", 100: "Animated Doors", 101: "Swing Type", 102: "Door Type", 103: "Door State", 50: "Closed", 51: "Open", 52: "Locked"}

static func settings_entries():
	var result = [[1, "menu_declare_order", "Declare Animated Door", 4], [2, "menu_remove_order", "Remove Animated Door", 3], [100, "menu_submenu_order", "Animated Doors", 5], [10, "menu_toggle_hinge_order", "Toggle Hinge", 6], [11, "menu_toggle_swing_order", "Toggle Swing", 7]]
	var children = [101, 102, 3, 4, 5, 6, 8, 7, 40, 41, 9, 20, 21, 22, 23, 24, 30, 31, 32, 103, 50, 51, 52]
	for i in range(children.size()):
		var id = children[i]
		result.append([id, "menu_item_" + str(id) + "_order", PROPERTY_LABELS.get(id, LABELS.get(id, "")), 2000 + (i + 1) * 10])
	return result

static func settings_group(id):
	if id in TOP_IDS:
		return "Main menu"
	if id in [20, 21, 22, 23, 24]:
		return "Swing Type"
	if id in [30, 31, 32]:
		return "Door Type"
	if id in [50, 51, 52]:
		return "Door State"
	return "Animated Doors"

func order_for(id):
	if menu_orders.has(id):
		return menu_orders[id]
	for entry in settings_entries():
		if entry[0] == id:
			return entry[3]
	return 0

func _sort_ids(a, b):
	return order_for(a) < order_for(b) or (order_for(a) == order_for(b) and a < b)

func _visible_ids(ids):
	var result = []
	for id in ids:
		if order_for(id) != 0:
			result.append(id)
	result.sort_custom(self, "_sort_ids")
	return result

const OVERVIEW_ACTION = "animated_doors_show_all"
const PREVIEW_ACTION = "animated_doors_play_preview"

const HOST_KEY = "_up_rcm_host"
const PROVIDERS_KEY = "_up_rcm_providers"

func install(host_adapter, accessor = null, enabled = true):
	menu_enabled = enabled
	adapter = host_adapter
	door_accessor = accessor
	content_control = adapter.property(adapter.host.Editor, "content")
	if not content_control is Control:
		return false
	# Capture a plain right-click only for eligible editing selections.
	# The live patch API still owns its shared menu when available.
	set_process_input(menu_enabled)
	set_process(menu_enabled)
	set_process_unhandled_key_input(true)
	connect("id_pressed", self, "_pressed")
	update_commands([])
	_register_provider()
	return true

func _register_provider():
	var entries = Engine.get_meta(PROVIDERS_KEY) if Engine.has_meta(PROVIDERS_KEY) else []
	var kept = []
	if entries is Array:
		for entry in entries:
			if not entry is Dictionary or not (str(entry.get("id", "")) == "AnimatedDoors" or str(entry.get("id", "")).begins_with("AnimatedDoors.")):
				kept.append(entry)
	provider_blocks.clear()
	for index in range(TOP_IDS.size() if menu_enabled and host_capability != 0 else 0):
		var id = TOP_IDS[index]
		if order_for(id) == 0:
			continue
		var block = MenuBlock.new(self, id)
		provider_blocks.append(block)
		kept.append({"id": "AnimatedDoors." + str(index), "provider": block, "world": adapter.host.World, "order": int(order_for(id))})
	Engine.set_meta(PROVIDERS_KEY, kept)

func configure_orders(orders):
	var configured = orders.duplicate()
	if orders is Array:
		configured = {1: orders[0], 2: orders[1], 100: orders[2]}
	if menu_orders != configured:
		menu_orders = configured
		_register_provider()
		update_commands(selected_ids)

class MenuBlock:
	extends Reference
	var owner_ref
	var index
	func _init(menu, item_index):
		owner_ref = weakref(menu)
		index = item_index
	func get_context_items(raw):
		var menu = owner_ref.get_ref()
		if menu == null:
			return []
		var items = menu.get_context_items(raw)
		for item in items:
			if item.get("_menu_id") == index:
				return [item]
		return []
	func on_context_action(action, raw):
		var menu = owner_ref.get_ref()
		if menu != null:
			menu.on_context_action(action, raw)

func hosted():
	var info = Host.live_info(adapter.host.World)
	return menu_enabled and info.get("version") == 1 and host_capability != 0

func _refresh_host():
	var instance = Host.handler(adapter.host)
	if checked_handler != null and not is_instance_valid(checked_handler.get_ref()):
		checked_handler = null
		host_capability = -1
		_clear_fallback()
		_release_blocker()
		_register_provider()
	if is_instance_valid(instance) and (checked_handler == null or checked_handler.get_ref() != instance):
		checked_handler = weakref(instance)
		host_capability = 1 if Host.supports_nested(instance) else 0
		# Prefer a newly loaded capable host over the automatic fallback.
		_register_provider()
		if host_capability == 1:
			_clear_fallback()
			_release_blocker()

func _process(_delta):
	if not menu_enabled:
		return
	_refresh_host()
	if is_instance_valid(patch_blocker) and not Input.is_mouse_button_pressed(BUTTON_RIGHT) and not right_pressed and not visible:
		_release_blocker()
	if probe_requested and host_capability == 0:
		probe_requested = false
		Host.hide_popup()
		var current = adapter.selected_assets()
		current.sort()
		var original = hosted_ids.duplicate()
		original.sort()
		if editing_active and menu_enabled and not adapter.exporting() and hosted_level == adapter.current_level() and not original.empty() and current == original:
			update_commands(hosted_ids)
			compatibility_level = weakref(hosted_level)
			_block_patch()
			rect_position = content_control.get_global_mouse_position()
			popup()

func set_menu_enabled(enabled):
	if not enabled and not hosted_ids.empty():
		Host.hide_popup()
	menu_enabled = enabled
	right_pressed = false
	probe_requested = false
	set_process_input(enabled)
	set_process(enabled)
	_clear_fallback()
	_release_blocker()
	_register_provider()

func _clear_fallback():
	hide()
	clear()
	for child in get_children():
		if child is PopupMenu:
			child.free()

func _block_patch():
	if not is_instance_valid(patch_blocker):
		patch_blocker = Control.new()
		patch_blocker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		patch_blocker.set_meta("_up_block_all", true)
		get_parent().add_child(patch_blocker)
		var windows = Engine.get_meta("_up_block_windows") if Engine.has_meta("_up_block_windows") else []
		windows = windows.duplicate() if windows is Array else []
		windows.append(weakref(patch_blocker))
		Engine.set_meta("_up_block_windows", windows)

func _release_blocker():
	if not is_instance_valid(patch_blocker):
		return
	var windows = Engine.get_meta("_up_block_windows") if Engine.has_meta("_up_block_windows") else []
	var kept = []
	if windows is Array:
		for ref in windows:
			if not ref is WeakRef or ref.get_ref() != patch_blocker:
				kept.append(ref)
	Engine.set_meta("_up_block_windows", kept)
	patch_blocker.free()
	patch_blocker = null

func get_context_items(raw):
	hosted_ids = []
	_refresh_host()
	if not hosted() or not editing_active or adapter.exporting():
		return []
	var ids = adapter.raw_asset_ids(raw)
	if ids.empty():
		return []
	probe_requested = true
	hosted_ids = ids.duplicate()
	hosted_level = adapter.current_level()
	update_commands(ids)
	return _items([1, 2, 10, 11, 100])

func _items(ids):
	var result = []
	for id in _visible_ids(ids):
		var state = command_state.get(id, {"disabled": false, "active": false})
		var item = {"_menu_id": id, "label": L.text(PROPERTY_LABELS.get(id, LABELS.get(id, ""))) + (L.text(" (a)") if state.active else ""), "disabled": state.disabled, "action_id": str(id)}
		if id in [100, 101, 102, 103]:
			var children = {100: [101, 102, 103, 3, 4, 5, 6, 7, 8, 9, 40, 41], 101: [20, 21, 22, 23, 24], 102: [30, 31, 32], 103: [50, 51, 52]}[id]
			item["submenu"] = _items(children)
			if item.submenu.empty():
				continue
		result.append(item)
	return result

func _fill_fallback(menu, items):
	for item in items:
		var id = item._menu_id
		if item.has("submenu"):
			var sub = PopupMenu.new()
			sub.name = "AnimatedDoorsMenu" + str(id)
			menu.add_child(sub)
			sub.connect("id_pressed", self, "_pressed")
			_fill_fallback(sub, item.submenu)
			menu.add_submenu_item(item.label, sub.name, id)
		else:
			menu.add_item(item.label, id)
		menu.set_item_disabled(menu.get_item_count() - 1, item.disabled)


func on_context_action(action_id, raw):
	if not hosted() or not editing_active or adapter.exporting() or not is_instance_valid(hosted_level) or hosted_level != adapter.current_level():
		return
	var ids = adapter.raw_asset_ids(raw)
	var original = hosted_ids.duplicate()
	ids.sort()
	original.sort()
	if ids != original or ids.empty() or not str(action_id).is_valid_integer():
		return
	update_commands(ids)
	_pressed(int(action_id))

func _unhandled_key_input(event):
	if not event is InputEventKey or not event.pressed or event.echo or not (_overview_key(event) or _preview_key(event)):
		return
	if adapter.exporting() or adapter.property(adapter.master, "IsBusy", false) or adapter.property(adapter.host.Editor, "SuppressTool", false):
		return
	var focus = content_control.get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	if is_instance_valid(adapter.export_window) and adapter.export_window.visible:
		return
	# Respect the patch's registered mod dialogs, including exclusive popups.
	var windows = Engine.get_meta("_up_block_windows") if Engine.has_meta("_up_block_windows") else []
	if windows is Array:
		for ref in windows:
			var window = ref.get_ref() if ref is WeakRef else null
			if is_instance_valid(window) and window != patch_blocker and window is Control and window.is_visible_in_tree():
				return
	emit_signal("artwork_preview_requested" if _preview_key(event) else "show_all_requested")
	get_tree().set_input_as_handled()

func _overview_key(event):
	if shortcut_registered:
		# Compare complete combinations: extra modifiers must not trigger the action.
		for binding in InputMap.get_action_list(OVERVIEW_ACTION):
			if binding is InputEventKey and binding.get_scancode_with_modifiers() == event.get_scancode_with_modifiers():
				return true
		return false
	return event.scancode == KEY_D and event.shift and not event.control and not event.alt and not event.meta

func _preview_key(event):
	if shortcut_registered:
		if not InputMap.has_action(PREVIEW_ACTION):
			return false
		for binding in InputMap.get_action_list(PREVIEW_ACTION):
			if binding is InputEventKey and binding.get_scancode_with_modifiers() == event.get_scancode_with_modifiers():
				return true
		return false
	return event.scancode == KEY_D and event.shift and event.control and not event.alt and not event.meta

func set_editing(active):
	editing_active = active
	right_pressed = false
	if not active:
		hide()
		_release_blocker()

func update_commands(ids):
	compatibility_level = null
	selected_ids = ids.duplicate()
	var all_declared = not ids.empty()
	var any_declared = false
	var values = []
	for id in ids:
		var node = adapter.resolve_node(id)
		var declared = false
		if node != null and door_accessor != null and door_accessor.has_component(node):
			var component = door_accessor.get_component(node)
			declared = not component.read_only and component.data.enabled
			if declared:
				values.append(component.data)
		all_declared = all_declared and declared
		any_declared = any_declared or declared
	command_state.clear()
	for entry in settings_entries():
		var action = entry[0]
		var active = all_declared
		for value in values:
			if FIELDS.has(action):
				active = active and value.get(FIELDS[action][0]) == FIELDS[action][1]
		active = active and (FIELDS.has(action) or (action == 9 and preview_active))
		var disabled = not all_declared
		if action == 1:
			disabled = all_declared or ids.empty()
		elif action == 2:
			disabled = not any_declared
		command_state[action] = {"disabled": disabled, "active": active}
	clear()
	for child in get_children():
		if child is PopupMenu:
			child.free()
	if not menu_enabled or hosted():
		return
	_fill_fallback(self, _items([1, 2, 10, 11, 101, 102, 103, 3, 4, 5, 6, 7, 8, 9, 40, 41]))

func _input(event):
	if not menu_enabled or not event is InputEventMouseButton or event.button_index != BUTTON_RIGHT:
		return
	_refresh_host()
	# Test lazily: Unofficial Patch can start after this mod, or on a later map.
	if hosted():
		right_pressed = false
		hide()
		return
	if event.pressed:
		right_pressed = false
		if not editing_active or event.shift or event.alt or event.control or event.meta:
			return
		if not content_control.is_visible_in_tree() or not content_control.get_global_rect().has_point(content_control.get_global_mouse_position()):
			return
		if adapter.exporting() or adapter.property(adapter.master, "IsBusy", false) or adapter.property(adapter.host.Editor, "SuppressTool", false):
			return
		if _blocked_by_dialog():
			return
		if adapter.property(adapter.host.Editor, "ActiveTool") != adapter.host.Editor.Tools.get("SelectTool"):
			return
		var ids = adapter.selected_assets()
		if ids.empty():
			return
		if Host.present(adapter.host):
			_block_patch()
		update_commands(ids)
		compatibility_level = weakref(adapter.current_level())
		right_pressed = true
		press_position = content_control.get_global_mouse_position()
		get_tree().set_input_as_handled()
	elif right_pressed:
		right_pressed = false
		get_tree().set_input_as_handled()
		if content_control.get_global_mouse_position().distance_to(press_position) > 6:
			return
		rect_position = content_control.get_global_mouse_position()
		popup()

func _blocked_by_dialog():
	var focus = content_control.get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return true
	if is_instance_valid(adapter.export_window) and adapter.export_window.visible:
		return true
	var windows = Engine.get_meta("_up_block_windows") if Engine.has_meta("_up_block_windows") else []
	if windows is Array:
		for ref in windows:
			var window = ref.get_ref() if ref is WeakRef else null
			if is_instance_valid(window) and window != patch_blocker and window is Control and window.is_visible_in_tree():
				return true
	return false

func _pressed(action):
	if compatibility_level != null:
		var current_ids = adapter.selected_assets()
		current_ids.sort()
		var original_ids = selected_ids.duplicate()
		original_ids.sort()
		if compatibility_level.get_ref() != adapter.current_level() or current_ids != original_ids or adapter.exporting():
			return
	var ancestors_enabled = order_for(100) != 0 if hosted() and not action in [1, 2, 10, 11] else true
	if action in [20, 21, 22, 23, 24]:
		ancestors_enabled = ancestors_enabled and order_for(101) != 0
	if action in [30, 31, 32]:
		ancestors_enabled = ancestors_enabled and order_for(102) != 0
	if action in [50, 51, 52]:
		ancestors_enabled = ancestors_enabled and order_for(103) != 0
	if menu_enabled and editing_active and ancestors_enabled and order_for(action) != 0 and command_state.has(action) and not command_state[action].disabled:
		emit_signal("action_requested", action, selected_ids.duplicate())

func detach():
	_release_blocker()
	set_process(false)
	set_editing(false)
	set_process_input(false)
	set_process_unhandled_key_input(false)
	var entries = Engine.get_meta(PROVIDERS_KEY) if Engine.has_meta(PROVIDERS_KEY) else []
	if entries is Array:
		var kept = []
		for entry in entries:
			if not entry is Dictionary or not entry.get("provider") in provider_blocks:
				kept.append(entry)
		Engine.set_meta(PROVIDERS_KEY, kept)
	provider_blocks.clear()
