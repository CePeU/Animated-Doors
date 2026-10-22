extends Reference

# Only Animated Doors controls use this catalog. Never change the host's locale
# or register global translations which could affect another mod's labels.
const META = "AnimatedDoors.localization"

static func configure(language, mod_root):
	var messages = {}
	if language == "auto":
		language = host_language()
	var chosen = language if language in ["en", "de"] else "en"
	var file = File.new()
	if file.open(mod_root.plus_file("languages/" + chosen + ".json"), File.READ) == OK:
		var parsed = JSON.parse(file.get_as_text())
		file.close()
		if parsed.error == OK and parsed.result is Dictionary:
			messages = parsed.result
	Engine.set_meta(META, {"language": chosen, "messages": messages})
	return not messages.empty()

static func host_language():
	# Dungeondraft localizes its UI independently of Godot's TranslationServer.
	var configuration = ConfigFile.new()
	if configuration.load("user://config.ini") == OK:
		var configured = configuration.get_value("Preferences", "language", "")
		if configured in ["en", "de"]:
			return configured
	var locale = TranslationServer.get_locale().to_lower().replace("-", "_")
	return "de" if locale.split("_")[0] == "de" else "en"

static func text(source):
	if not Engine.has_meta(META):
		return source
	var messages = Engine.get_meta(META).messages
	var translated = messages.get(source)
	if translated is String and not translated.empty():
		return translated
	# Labels composed from a stable prefix/suffix still translate each whole
	# message; user filenames and layer names are never passed through this path.
	for prefix in ["Default ", "Menu order: "]:
		if source.begins_with(prefix):
			return messages.get(prefix, prefix) + text(source.substr(prefix.length()))
	for suffix in [" (mixed)", " (a)"]:
		if source.ends_with(suffix):
			return text(source.substr(0, source.length() - suffix.length())) + messages.get(suffix, suffix)
	return source

static func _source(node, key, current):
	var saved = node.get_meta(key) if node.has_meta(key) else {}
	var original = saved.source if saved.get("translated") == current else current
	var translated = text(original)
	node.set_meta(key, {"source": original, "translated": translated})
	return translated

static func property_text(node, property):
	var value = node.get(property)
	if value is String and not value.empty():
		node.set(property, _source(node, "ad_i18n_" + property, value))

static func apply_tree(node):
	if not is_instance_valid(node):
		return
	if node is Control:
		property_text(node, "hint_tooltip")
	if node is WindowDialog:
		property_text(node, "window_title")
	if node is AcceptDialog:
		property_text(node, "dialog_text")
	if node is LineEdit:
		property_text(node, "placeholder_text")
		return # Never translate the user's text or a filename.
	if node is OptionButton:
		if not node.has_meta("ad_skip_items"):
			for index in range(node.get_item_count()):
				node.set_item_text(index, _source(node, "ad_i18n_item_" + str(index), node.get_item_text(index)))
		return # Its popup is an internal duplicate of these items.
	if node is Label or node is Button:
		property_text(node, "text")
	if node is Tree:
		_tree_items(node, node.get_root())
	if node is ColorPickerButton or node is ColorPicker:
		return # Color-picker internals belong to Godot, including editable hex.
	for child in node.get_children():
		apply_tree(child)

static func _tree_items(tree, item):
	while item != null:
		for column in range(tree.columns):
			item.set_text(column, _source(item, "ad_i18n_column_" + str(column), item.get_text(column)))
		_tree_items(tree, item.get_children())
		item = item.get_next()
