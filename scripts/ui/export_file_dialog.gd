extends FileDialog

# Godot 3.4 clears the save name on directory navigation. Keep the last nonempty
# name, including edits made by the user, and restore it after the directory UI.
var saved_filename = ""
var previous_directory = ""
var user_cleared_filename = false

func choose_native(extension, description):
	# Dungeondraft exposes its OS dialog through a custom Godot OS method.
	# call() keeps this script compatible with the stock test engine.
	var path = ""
	var directory = current_dir
	if directory.begins_with("res://") or directory.begins_with("user://"):
		directory = ProjectSettings.globalize_path(directory)
	if OS.get_name() == "X11":
		var output = []
		var status = OS.execute("zenity", ["--file-selection", "--save", "--confirm-overwrite", "--title=" + window_title, "--filename=" + directory.plus_file(current_file), "--file-filter=*." + extension], true, output)
		if status == 0 and not output.empty():
			path = str(output[0]).strip_edges()
	elif OS.has_method("show_save_dialog"):
		path = OS.call("show_save_dialog", window_title, description + " (*." + extension + ")|*." + extension, directory)
	else:
		return false
	if not path.empty():
		if not path.to_lower().ends_with("." + extension):
			path += "." + extension
		current_dir = path.get_base_dir()
		_file_chosen(path)
		emit_signal("file_selected", path)
	return true

func _ready():
	get_line_edit().connect("text_changed", self, "_filename_changed")
	connect("about_to_show", self, "_remember_name")
	connect("file_selected", self, "_file_chosen")
	set_process(true)

func _remember_name():
	user_cleared_filename = false
	if not current_file.empty():
		saved_filename = current_file
	previous_directory = current_dir
	call_deferred("_restore_name")

func _file_chosen(path):
	saved_filename = path.get_file()
	user_cleared_filename = false

func _restore_name():
	if visible and current_file.empty() and not saved_filename.empty() and not user_cleared_filename:
		current_file = saved_filename

func _filename_changed(value):
	user_cleared_filename = value.empty() and get_line_edit().has_focus()
	if not value.empty():
		saved_filename = value.get_file()
	else:
		call_deferred("_restore_name")

func _process(_delta):
	if not visible:
		return
	# Directory refreshes may clear the name on a later frame, without another
	# current_dir change (including after the first save). Watch the field too.
	if current_dir != previous_directory:
		user_cleared_filename = false
		previous_directory = current_dir
	if not current_file.empty():
		saved_filename = current_file.get_file()
	_restore_name()
