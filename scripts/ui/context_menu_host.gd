extends Reference

# Both released patch APIs advertise version 1. Inspect the running handler,
# never the installed filename/version (which may differ from loaded code).
static func live_info(world):
	var info = Engine.get_meta("_up_rcm_host") if Engine.has_meta("_up_rcm_host") else {}
	return info if info is Dictionary and info.get("world") == world and is_instance_valid(world) else {}

static func handler(host):
	var api = host.get("API", {})
	if api.has("ModRegistry"):
		var info = api.ModRegistry.get_mod_info("Moulk.BugFixes")
		if info != null and is_instance_valid(info.mod):
			var instance = info.mod.get("right_click_util")
			if is_instance_valid(instance) and instance.get("_g") is Dictionary and instance.get("_g").get("World") == host.World:
				return instance
	# Without _Lib the host becomes reachable through its own popup signal.
	var layer = Engine.get_meta("rcu_popup_layer") if Engine.has_meta("rcu_popup_layer") else null
	if is_instance_valid(layer) and layer is Node:
		for popup in layer.get_children():
			if popup is PopupMenu:
				for connection in popup.get_signal_connection_list("id_pressed"):
					var target = connection.target
					if is_instance_valid(target) and target.has_method("_normalize_items"):
						var globals = target.get("_g")
						if globals is Dictionary and globals.get("World") == host.World:
							return target
	return null

static func present(host):
	if not live_info(host.World).empty():
		return true
	var api = host.get("API", {})
	if api.has("ModRegistry") and api.ModRegistry.get_mod_info("Moulk.BugFixes") != null:
		return true
	# The patch publishes its settings service independently of _Lib.
	var service = host.get("ModMapData", {}).get("_mod_settings")
	return is_instance_valid(service) and service is Object and service.has_method("get") and service.get("_g") is Dictionary and service.get("_g").get("World") == host.World

static func supports_nested(instance):
	# A pure normalization probe verifies behavior, including the old mandatory
	# boolean argument and the hotfix's optional integer depth argument.
	if not is_instance_valid(instance) or not instance.has_method("_normalize_items"):
		return false
	var items = [{"label":"probe", "submenu":[{"label":"category", "submenu":[{"label":"leaf", "action_id":"probe"}]}]}]
	var args = [items, instance]
	for method in instance.get_method_list():
		if method.name == "_normalize_items" and method.args.size() > 2 and method.default_args.empty():
			args.append(true)
	var normalized = instance.callv("_normalize_items", args)
	return normalized is Array and normalized.size() == 1 and normalized[0].get("submenu", []).size() == 1 and normalized[0].submenu[0].get("submenu", []).size() == 1

static func hide_popup():
	var layer = Engine.get_meta("rcu_popup_layer") if Engine.has_meta("rcu_popup_layer") else null
	if is_instance_valid(layer) and layer is Node:
		for popup in layer.get_children():
			if popup is PopupMenu:
				popup.hide()
