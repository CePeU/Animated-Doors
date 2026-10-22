extends FileDialog

# Godot 3.4 clears the save name on directory navigation. Keep the last nonempty
# name, including edits made by the user, and restore it after the directory UI.
var saved_filename = ""
var previous_directory = ""
var user_cleared_filename = false

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
