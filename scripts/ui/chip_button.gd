class_name ChipButton
extends Control
## A betting chip. Left click adds its value to the bet, right click removes it.

signal add_pressed(value: int)
signal remove_pressed(value: int)

const SIZE := 30

var value := 5
var disabled := false:
	set(v):
		disabled = v
		queue_redraw()
var _hover := false
var _t := 0.0


func _init(chip_value: int = 5) -> void:
	value = chip_value
	size = Vector2(SIZE, SIZE + 4)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = ""


func _ready() -> void:
	mouse_entered.connect(func() -> void: _hover = true)
	mouse_exited.connect(func() -> void: _hover = false)


func _process(delta: float) -> void:
	var target := 1.0 if _hover and not disabled else 0.0
	var nt := move_toward(_t, target, delta * 8.0)
	if nt != _t:
		_t = nt
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		if not disabled:
			add_pressed.emit(value)
		accept_event()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		remove_pressed.emit(value)
		accept_event()


func _draw() -> void:
	var lift := roundf(_t * 3.0)
	var tex := Art.chip_texture(value, SIZE)
	draw_texture(tex, Vector2(0, 4), Color(0, 0, 0, 0.35))
	var mod := Color(0.55, 0.55, 0.6) if disabled else Color.WHITE
	draw_texture(tex, Vector2(0, 2 - lift), mod)
	var label := str(value)
	PixelFont.draw_centered(self, SIZE / 2.0, 2 - lift + (SIZE - PixelFont.GLYPH_H) / 2.0, label,
		Art.WHITE if not disabled else Art.GREY, 1, Art.INK)
