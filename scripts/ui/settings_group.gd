extends VBoxContainer

# A visual foldout which forwards _Lib's configuration protocol without adding
# a nesting level to saved settings. The standalone builder uses the same UI.
var heading = CheckButton.new()
var content = VBoxContainer.new()
var config_parent

func _init(title = "", expanded = false):
	heading.text = title
	heading.pressed = expanded
	add_child(heading)
	add_child(content)
	content.visible = expanded
	heading.connect("toggled", self, "_toggle")

func _toggle(expanded):
	content.visible = expanded

func get_target():
	return content

func set_parent_config_node(parent):
	config_parent = parent

func is_flattened():
	return true

func get_config_access():
	return self

func mark_dirty():
	if config_parent != null:
		config_parent.mark_dirty()

func save_cfg(data = {}):
	for node in content.get_children():
		if node.has_method("save_cfg"):
			if node.has_method("is_flattened") and node.is_flattened():
				node.save_cfg(data)
			else:
				data[node.get_save_entry()] = node.save_cfg()
	return data

func load_cfg(data):
	if not data is Dictionary:
		data = {}
	for node in content.get_children():
		if node.has_method("load_cfg"):
			if node.has_method("is_flattened") and node.is_flattened():
				node.load_cfg(data)
			else:
				node.load_cfg(data.get(node.get_save_entry()))

func _on_preferences_about_to_show():
	for node in content.get_children():
		if node.has_method("_on_preferences_about_to_show"):
			node._on_preferences_about_to_show()
