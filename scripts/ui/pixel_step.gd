extends Node

# Keep SpinBox precision (and _Lib's attached config script), but make its
# buttons, wheel and arrow keys move by one map pixel instead of 0.001.
var spin
var repeat_timer = Timer.new()
var direction = 0

func _init(control):
	name = "PixelStep"
	spin = control
	add_child(repeat_timer)
	repeat_timer.one_shot = true
	repeat_timer.connect("timeout", self, "_repeat")

func _input(event):
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and not event.pressed and direction != 0:
		direction = 0
		repeat_timer.stop()
		get_tree().set_input_as_handled()
		return
	if not _can_edit():
		direction = 0
		repeat_timer.stop()
		return
	if event is InputEventKey and event.pressed and spin.get_line_edit().has_focus() and event.scancode in [KEY_UP, KEY_DOWN]:
		advance(1 if event.scancode == KEY_UP else -1)
		get_tree().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		var local = spin.get_global_transform_with_canvas().affine_inverse().xform(event.position)
		if not Rect2(Vector2.ZERO, spin.rect_size).has_point(local):
			return
		if event.button_index in [BUTTON_WHEEL_UP, BUTTON_WHEEL_DOWN]:
			advance(1 if event.button_index == BUTTON_WHEEL_UP else -1)
		elif event.button_index == BUTTON_LEFT and local.x >= spin.rect_size.x - spin.get_icon("updown", "SpinBox").get_width():
			direction = 1 if local.y < spin.rect_size.y / 2 else -1
			advance(direction)
			repeat_timer.start(0.6)
		else:
			return
		get_tree().set_input_as_handled()

func advance(amount):
	# Commit text first, so clicking after typing starts from that value.
	spin.apply()
	spin.value += amount

func _can_edit():
	if not spin.is_visible_in_tree() or not spin.editable:
		return false
	var modal = spin.get_viewport().get_modal_stack_top()
	return modal == null or modal == spin or modal.is_a_parent_of(spin)

func _repeat():
	if direction == 0 or not _can_edit() or not Input.is_mouse_button_pressed(BUTTON_LEFT):
		direction = 0
		return
	advance(direction)
	repeat_timer.start(0.075)
