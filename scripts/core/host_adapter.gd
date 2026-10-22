extends Reference

const Geometry = preload("door_geometry.gd")
const Encoder = preload("asset_encoder.gd")
var host
var api
var export_window
var master
var export_level
var saved_source_index = -1

func _init(global_dictionary):
	host = global_dictionary
	api = host.API
	master = host.Editor.owner
	export_window = host.Editor.Windows.get("Export")

static func property(object, name, fallback = null):
	if not is_instance_valid(object):
		return fallback
	# Godot 3's Mono bridge resolves fields (including static fields) through
	# Object.get(), even when they are absent from the editor property list.
	if object.has_method("get_" + name):
		return object.call("get_" + name)
	var value = object.get(name)
	return fallback if value == null else value

func probe_capabilities():
	var missing = []
	for method in ["Start", "ExportForVTT", "ExportResolution"]:
		if not host.Exporter.has_method(method):
			missing.append("Exporter." + method)
	for method in ["GetCurrentLevel", "GetNodeByID"]:
		if not host.World.has_method(method):
			missing.append("World." + method)
	for name in ["OkayButton", "ExportModeOptions", "GridPPISpinBox", "SourceLevelOptions", "OverlayLevelOptions"]:
		if not is_instance_valid(export_window) or export_window.find_node(name, true, false) == null:
			missing.append("Export window / " + name)
	if property(master, "IsExporting") == null:
		missing.append("Master.IsExporting")
	if property(host.World, "TileSize", 0) <= 0:
		missing.append("World.TileSize")
	if not missing.empty():
		return Geometry.failure("HOST_API", "Unsupported host interface: " + PoolStringArray(missing).join(", "))
	return Geometry.success(true)

func exporting():
	return property(master, "IsExporting", false) == true

func dungeondraft_version():
	var label = property(master, "Version")
	var text = property(label, "text", "")
	var pattern = RegEx.new()
	pattern.compile("(?<![0-9.])[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+(?![0-9.])")
	var matched = pattern.search(text)
	return matched.get_string() if matched != null else ""

func integrated_export_allowed(configured):
	var version = dungeondraft_version()
	return not version.empty() and configured.strip_edges() == version

func current_level():
	return export_level if is_instance_valid(export_level) else host.World.GetCurrentLevel()

func layer_id(portal):
	# Portal sprites live inside Portals, but z-index is authored on the Portal.
	# Honor Godot's relative-z chain, rather than a layer display name.
	var node = portal
	var value = 0
	while node is Node2D:
		value += node.z_index
		if not node.z_as_relative:
			break
		node = node.get_parent()
	return value

func list_portals():
	var level = current_level()
	var parent = property(level, "Portals")
	if parent == null:
		return []
	var output = []
	for node in parent.get_children():
		if node.has_method("Export") and node.has_meta("node_id") and property(node, "IsFreestanding", false):
			output.append(node)
	output.sort_custom(self, "_sort_nodes")
	return output

func list_assets():
	var output = list_portals()
	var parent = property(current_level(), "Objects")
	if is_instance_valid(parent):
		for node in parent.get_children():
			if node.has_meta("node_id") and property(node, "Sprite") is Sprite:
				output.append(node)
	output.sort_custom(self, "_sort_nodes")
	return output

func source_kind(node):
	return "portal" if node.get_parent() == property(current_level(), "Portals") else "object"

var export_selection = []
var export_selection_level
var export_selection_active = false
var export_highlights = []

func suspend_export_selection():
	if export_selection_active:
		return Geometry.success(true)
	var tool = host.Editor.Tools.get("SelectTool")
	var selected = property(tool, "Selectables", {})
	if not selected is Dictionary:
		return Geometry.failure("SELECTION", "Cannot inspect native selection before export.")
	for method in ["DeselectAll", "SelectThing", "OnFinishSelection", "EnableTransformBox"]:
		if not is_instance_valid(tool) or not tool.has_method(method):
			return Geometry.failure("SELECTION", "Cannot temporarily clear native selection before export.")
	export_selection_level = weakref(current_level())
	export_selection_active = true
	# Portal._Draw has no IsExporting guard; hover survives DeselectAll.
	var highlight_nodes = list_assets()
	var portals = property(current_level(), "Portals")
	if is_instance_valid(portals):
		for node in portals.get_children():
			if not node in highlight_nodes:
				highlight_nodes.append(node)
	for node in highlight_nodes:
		if node.has_method("Highlight") and property(node, "isHighlighted", false):
			export_highlights.append(weakref(node))
			node.Highlight(false)
	for node in selected:
		if is_instance_valid(node):
			export_selection.append(weakref(node))
	tool.DeselectAll()
	# DeselectAll clears node selection, but neither it nor OnFinishSelection
	# hides the separate native transform box when the selection is now empty.
	# DD allocates this widget only in SelectTool.Enable(). Calling the native
	# method before the user first visits Select dereferences a null field and
	# raises an unhandled Mono exception while the export window is opening.
	if is_instance_valid(property(tool, "transformBox")):
		tool.EnableTransformBox(false)
	return Geometry.success(true)

func restore_export_selection():
	if not export_selection_active:
		return
	export_selection_active = false
	var saved = export_selection
	export_selection = []
	var level = export_selection_level.get_ref()
	export_selection_level = null
	for ref in export_highlights:
		var node = ref.get_ref()
		if is_instance_valid(node) and not node.is_queued_for_deletion() and level == current_level():
			node.Highlight(true)
	export_highlights = []
	if saved.empty():
		return
	if not is_instance_valid(level) or level != current_level():
		return
	var tool = host.Editor.Tools.get("SelectTool")
	if not is_instance_valid(tool):
		return
	# Do not overwrite an unexpected new selection made while capture ended.
	if not property(tool, "Selectables", {}).empty():
		return
	for ref in saved:
		var node = ref.get_ref()
		if is_instance_valid(node) and not node.is_queued_for_deletion() and node.is_inside_tree():
			tool.SelectThing(node, true)
	tool.OnFinishSelection()

func selected_assets():
	var tool = host.Editor.Tools.get("SelectTool")
	# Selectables is a .NET Dictionary; Selected is a .NET List, which is not
	# reliably exposed to GDScript by the Godot 3 Mono bridge.
	var selected = property(tool, "Selectables", {})
	var output = []
	if selected is Dictionary:
		var eligible = list_assets()
		for node in selected:
			if is_instance_valid(node) and node in eligible:
				output.append(str(int(node.get_meta("node_id"))))
	return output

func artwork_bounds(node, axis = "width"):
	var sprite = property(node, "Sprite")
	if not sprite is Sprite or sprite.texture == null:
		return Geometry.failure("MISSING_SPRITE", "The selected asset has no Sprite texture.")
	var transform = Geometry.image_transform(sprite.get_rect(), sprite.global_transform, sprite.flip_h, sprite.flip_v, 1.0)
	if not transform.ok:
		return transform
	return Geometry.success(Geometry.artwork_bounds(transform.value, axis))

func raw_asset_ids(raw):
	var ids = []
	if raw == null:
		return ids
	var eligible = list_assets()
	for entry in raw:
		var node = property(entry, "Thing")
		if is_instance_valid(node) and node in eligible:
			var id = str(int(node.get_meta("node_id")))
			if not id in ids:
				ids.append(id)
	return ids

var axis_cache = {}

func _clear_axis_cache():
	axis_cache.clear()

func default_axis(node, mode, fallback = "width"):
	var sprite = property(node, "Sprite")
	if not sprite is Sprite or sprite.texture == null:
		return Geometry.choose_axis(mode, 0, 0, fallback)
	var size = sprite.get_rect().size
	var scale_size = Vector2(sprite.global_transform.x.length(), sprite.global_transform.y.length())
	var full = size.abs() * scale_size
	if mode in ["width", "height"]:
		return mode
	if mode == "visible" or abs(full.x - full.y) <= Geometry.EPSILON * max(full.x, full.y):
		var key = str(sprite.texture.get_instance_id()) + ":" + str([sprite.region_enabled, sprite.region_rect, sprite.hframes, sprite.vframes, sprite.frame])
		if not axis_cache.has(key):
			if not sprite.texture.is_connected("changed", self, "_clear_axis_cache"):
				sprite.texture.connect("changed", self, "_clear_axis_cache")
			var read = Encoder.sprite_pixels(sprite)
			axis_cache[key] = read.value.image.get_used_rect().size if read.ok else Vector2.ZERO
		var used = axis_cache[key] * scale_size
		# A nearly square silhouette is not a reliable directional signal.
		if min(used.x, used.y) >= 0 and max(used.x, used.y) > 0 and abs(used.x - used.y) > 0.05 * max(used.x, used.y):
			return Geometry.choose_axis("shorter" if mode == "shorter" else "longer", used.x, used.y, fallback)
		return fallback
	return Geometry.choose_axis(mode, full.x, full.y, fallback)

func visible_artwork(node):
	var sprite = property(node, "Sprite")
	if not sprite is Sprite or sprite.texture == null or not sprite.is_visible_in_tree():
		return false
	var alpha = sprite.self_modulate.a
	var ancestor = sprite
	while ancestor is CanvasItem:
		alpha *= ancestor.modulate.a
		ancestor = ancestor.get_parent()
	return alpha > 0.0

func artwork_outline(node):
	var sprite = property(node, "Sprite")
	if not sprite is Sprite or sprite.texture == null:
		return []
	var rect = sprite.get_rect()
	var points = []
	for point in [rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)]:
		points.append(sprite.global_transform.xform(point))
	return points

func select_asset(id):
	var node = resolve_node(id)
	if node == null or not node in list_assets():
		return Geometry.failure("SELECTION", "This asset is no longer on the current level.")
	if exporting() or property(master, "IsBusy", false):
		return Geometry.failure("SELECTION", "Wait for the current operation to finish before selecting an asset.")
	var tool = host.Editor.Tools.get("SelectTool")
	var toolset = property(host.Editor, "Toolset")
	for method in ["DeselectAll", "SelectThing", "OnFinishSelection"]:
		if not is_instance_valid(tool) or not tool.has_method(method):
			return Geometry.failure("SELECTION", "Native selection method unavailable: " + method)
	if not is_instance_valid(toolset) or not toolset.has_method("Quickswitch"):
		return Geometry.failure("SELECTION", "Native tool switching is unavailable.")
	if property(host.Editor, "ActiveTool") != tool:
		toolset.Quickswitch("SelectTool")
	tool.DeselectAll()
	tool.SelectThing(node, true)
	tool.OnFinishSelection()
	return Geometry.success(true)

func _sort_nodes(a, b):
	return int(a.get_meta("node_id")) < int(b.get_meta("node_id"))

func resolve_node(id):
	if host.World.has_method("HasNodeID") and not host.World.HasNodeID(int(id)):
		return null
	return host.World.GetNodeByID(int(id))

func map_name():
	var path = str(property(host.Editor, "CurrentMapFile", ""))
	return path.get_file().get_basename() if not path.empty() else "Untitled"

func prepare_levels(level_accessor = null):
	var source = export_window.find_node("SourceLevelOptions", true, false)
	if source == null or source.get_item_count() == 0 or not host.World.has_method("SetSourceLevel"):
		return Geometry.failure("LEVELS", "Cannot read the ordered Dungeondraft levels.")
	var ordered = property(host.World, "AllLevels", [])
	if ordered.size() != source.get_item_count():
		return Geometry.failure("LEVELS", "Cannot read the ordered Dungeondraft levels.")
	# DD inserts levels at the top. Export bottom-to-top, independently of IDs,
	# and freeze the included source indices for the entire batch.
	var indices = []
	for index in range(ordered.size() - 1, -1, -1):
		if level_accessor != null:
			var component = level_accessor.get_component(ordered[index])
			if component.read_only:
				return Geometry.failure("LEVEL_SETTINGS", component.issue)
			if not component.data.export_enabled:
				continue
		indices.append(index)
	if indices.empty():
		return Geometry.failure("LEVELS", "Enable at least one level for UVTT export.")
	var selection = suspend_export_selection()
	if not selection.ok:
		return selection
	saved_source_index = source.selected
	return Geometry.success(indices)

func select_export_level(index):
	# Export's source list follows World.AllLevels, also used by Level Settings.
	# SetSourceLevel changes the render source without changing the editor level.
	host.World.SetSourceLevel(index)
	export_level = property(host.World, "SourceLevel")
	# Clear hover on every source level as well as the original selection.
	for node in list_assets():
		if node.has_method("Highlight") and property(node, "isHighlighted", false):
			export_highlights.append(weakref(node))
			node.Highlight(false)

func restore_levels():
	if saved_source_index >= 0:
		host.World.SetSourceLevel(saved_source_index)
		saved_source_index = -1
	export_level = null

func export_options(all_levels = false):
	var ppi = int(export_window.find_node("GridPPISpinBox", true, false).value)
	var quality = export_window.find_node("ImageQualitySlider", true, false)
	var overlay = export_window.find_node("OverlayLevelOptions", true, false)
	var source = property(host.World, "SourceLevel")
	if not all_levels and (source == null or source != current_level()):
		return Geometry.failure("EXPORT_LEVEL", "Choose the current level as the export source.")
	if overlay.selected != 0:
		return Geometry.failure("OVERLAY", "Animated Doors exports one level. Set Overlay Level to None.")
	if property(host.Editor, "CompareToggle") != null and host.Editor.CompareToggle.pressed:
		return Geometry.failure("COMPARE", "Turn off level comparison before exporting animated doors.")
	if ppi <= 0 or ppi > 300:
		return Geometry.failure("PPI", "Choose an export resolution between 1 and 300 pixels per grid.")
	if property(export_window, "fillTo1080p", false):
		return Geometry.failure("FIXED_RESOLUTION", "Use a pixels-per-grid preset rather than a fixed 1080p output.")
	return Geometry.success({"ppi": ppi, "quality": int(quality.value) if quality != null else 90, "level_id": str(property(source, "ID", 0))})

func collect(map_settings, door_accessor, options):
	if map_settings.read_only:
		return Geometry.failure("MAP_SETTINGS", map_settings.issue)
	var raster_only = options.get("raster_only", false)
	var native = {} if raster_only else host.Exporter.ExportForVTT(options.ppi, null).duplicate(true)
	if options.get("bake", false):
		return Geometry.success({"native": native, "doors": [], "assets": {}, "visuals": [], "statistics": {"candidates": 0, "declared": 0, "hidden": 0}})
	var snapshots = []
	var visuals = []
	var assets = {}
	var grid_size = float(property(host.World, "TileSize", 0))
	var asset_cache = {}
	var source_bytes = 0
	var statistics = {"candidates": 0, "declared": 0, "hidden": 0}
	for portal in list_assets():
		statistics.candidates += 1
		if not door_accessor.has_component(portal):
			continue
		var component = door_accessor.get_component(portal)
		if component.read_only:
			return Geometry.failure("DOOR_SETTINGS", component.issue)
		if not component.data.enabled:
			continue
		statistics.declared += 1
		var sprite = property(portal, "Sprite")
		if sprite == null:
			return Geometry.failure("MISSING_SPRITE", "Declared door %s has no readable Sprite." % portal.get_meta("node_id"))
		if not sprite.is_visible_in_tree():
			statistics.hidden += 1
			continue
		var id = "level:%s/node:%s" % [options.level_id, str(int(portal.get_meta("node_id")))]
		var tint = sprite.self_modulate
		var ancestor = sprite
		while ancestor is CanvasItem:
			tint *= ancestor.modulate
			ancestor = ancestor.get_parent()
		if tint.a == 0:
			statistics.hidden += 1
			continue
		if raster_only:
			snapshots.append({"id": id})
			visuals.append(sprite)
			var shadow = property(portal, "shadow")
			if source_kind(portal) == "object" and shadow is Sprite and shadow.is_visible_in_tree():
				visuals.append(shadow)
			continue
		for channel in [tint.r, tint.g, tint.b, tint.a]:
			if not Geometry.number(channel) or channel < 0 or channel > 1:
				return Geometry.failure("TINT", id + ": HDR tint cannot be represented.")
		var cache_key = str(sprite.texture.get_instance_id()) + ":" + str(sprite.region_enabled) + ":" + str(sprite.region_rect) + ":" + str(sprite.frame) + ":" + str(sprite.hframes) + ":" + str(sprite.vframes) if sprite.texture != null else "missing"
		var profile = Encoder.material_profile(sprite)
		if not profile.ok:
			profile.message = id + ": " + profile.message
			return profile
		cache_key += ":" + JSON.print(profile.value)
		var encoded
		if asset_cache.has(cache_key):
			encoded = asset_cache[cache_key]
		else:
			encoded = Encoder.read_sprite(sprite, profile)
			if encoded.ok:
				source_bytes += encoded.value.image.get_width()*encoded.value.image.get_height()*4 + encoded.value.original_bytes.size()
				if source_bytes > 268435456:
					return Geometry.failure("MEMORY_LIMIT","Door source readback exceeds the 256 MiB budget.")
			asset_cache[cache_key] = encoded
		if not encoded.ok:
			encoded.message = id + ": " + encoded.message
			return encoded
		var asset = encoded.value
		var source_id = asset.pixel_hash
		# This table is an export-local source descriptor, not an encoded image.
		# Final encoding and byte-hash identity happen only after preparation.
		if not assets.has(source_id):
			assets[source_id] = {"width":asset.image.get_width(),"height":asset.image.get_height(),"format":sprite.texture.resource_path.get_extension().to_lower(),"source_paths":[sprite.texture.resource_path]}
		var transform = Geometry.image_transform(sprite.get_rect(), sprite.global_transform, sprite.flip_h, sprite.flip_v, grid_size)
		if not transform.ok:
			return transform
		var bounds = Geometry.artwork_bounds(transform.value, component.data.axis)
		var kind = source_kind(portal)
		var native_portal = {}
		if kind == "portal":
			native_portal = portal.Export().duplicate(true)
			native_portal["freestanding"] = true
		var endpoint = bounds[0] if component.data.hinge_endpoint == "begin" else bounds[1]
		var hinge_check = Geometry.hinge_index(bounds, endpoint)
		if not hinge_check.ok:
			return Geometry.failure("HINGE", id + ": " + hinge_check.message)
		snapshots.append({"id": id, "settings": component.serialize(portal), "source_kind": kind, "bounds": bounds, "native": native_portal, "hinge": endpoint, "direction": component.data.swing_direction, "asset_id": source_id, "transform": transform.value, "tint": {"r": tint.r, "g": tint.g, "b": tint.b, "a": tint.a}})
		snapshots.back()["asset_render"] = {"material": profile.value.duplicate(true), "region_enabled": sprite.region_enabled, "region": {"x": sprite.region_rect.position.x, "y": sprite.region_rect.position.y, "width": sprite.region_rect.size.x, "height": sprite.region_rect.size.y}, "hframes": sprite.hframes, "vframes": sprite.vframes, "frame": sprite.frame}
		snapshots.back()["source_path"] = sprite.texture.resource_path
		snapshots.back()["source_context"] = "texture:"+str(sprite.texture.get_instance_id())
		snapshots.back()["pixels"] = asset.image
		snapshots.back()["original_bytes"] = asset.original_bytes
		snapshots.back()["full_frame"] = asset.full_frame
		snapshots.back()["source_frame"] = asset.source_frame
		snapshots.back()["asset_format"] = options.get("asset_format", "original")
		snapshots.back()["pixel_hash"] = asset.pixel_hash
		snapshots.back()["provenance"] = asset.provenance
		visuals.append(sprite)
		if kind == "object":
			# The host's object shadow is separate artwork. Suppress it with the
			# door while leaving light occluders and native LOS records intact.
			var shadow = property(portal, "shadow")
			if shadow is Sprite and shadow.is_visible_in_tree():
				visuals.append(shadow)
	return Geometry.success({"native": native, "doors": snapshots, "assets": assets, "visuals": visuals, "statistics": statistics})

func begin_export(format_script, ppi, quality, render_path):
	host.Exporter.Mod = format_script
	host.Exporter.Quality = quality
	host.Exporter.Start(4, ppi, render_path)

func diagnostic_report(door_accessor = null, map_settings = null):
	var report = {"engine": Engine.get_version_info(), "mod_version": "0.15.5", "exporter_methods": [], "exporter_signals": [], "assets": [], "selected_ids": selected_assets()}
	if map_settings != null:
		report["map_settings"] = map_settings.serialize(null)
	for entry in host.Exporter.get_method_list():
		report.exporter_methods.append(entry.name)
	for entry in host.Exporter.get_signal_list():
		report.exporter_signals.append(entry.name)
	for node in list_assets():
		var sprite = property(node, "Sprite")
		var entry = {"node_id": str(node.get_meta("node_id")), "source_kind": source_kind(node), "layer_id": layer_id(node), "visible": sprite.is_visible_in_tree() if sprite is Sprite else false}
		if source_kind(node) == "portal":
			entry["native"] = node.Export()
		if door_accessor != null and door_accessor.has_component(node):
			entry["settings"] = door_accessor.get_component(node).serialize(node)
		entry["artwork_bounds"] = artwork_bounds(node)
		if sprite is Sprite:
			entry["material_profile"] = Encoder.material_profile(sprite)
		report.assets.append(entry)
	return report
