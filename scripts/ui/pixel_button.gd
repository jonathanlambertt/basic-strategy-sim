class_name PixelButton
extends Control
## Chunky pixel button: drop shadow, press-down, hover brighten, optional hotkey badge.

signal pressed

const DEPTH := 2

var text := "":
	set(v):
		text = v
		queue_redraw()
var hotkey := "":
	set(v):
		hotkey = v
		queue_redraw()
var color := Art.BLUE:
	set(v):
		color = v
		queue_redraw()
var color_dark := Art.BLUE_D:
	set(v):
		color_dark = v
		queue_redraw()
var disabled := false:
	set(v):
		disabled = v
		if v:
			_down = false
		mouse_default_cursor_shape = Control.CURSOR_ARROW if v else Control.CURSOR_POINTING_HAND
		queue_redraw()
## For option buttons: draws a gold outline when selected.
var selected := false:
	set(v):
		selected = v
		queue_redraw()

var _hover := false
var _down := false


static func make(label: String, rect: Rect2, col: Color = Art.BLUE, col_dark: Color = Art.BLUE_D, key: String = "") -> PixelButton:
	var b := PixelButton.new()
	b.text = label
	b.position = rect.position
	b.size = rect.size
	b.color = col
	b.color_dark = col_dark
	b.hotkey = key
	return b


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _ready() -> void:
	mouse_entered.connect(func() -> void:
		_hover = true
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hover = false
		_down = false
		queue_redraw())


func _gui_input(event: InputEvent) -> void:
	if disabled or not is_visible_in_tree():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = true
			queue_redraw()
		elif _down:
			_down = false
			queue_redraw()
			if Rect2(Vector2.ZERO, size).has_point(event.position):
				pressed.emit()
		accept_event()


## Brief press animation, used when the hotkey triggers the button.
func flash() -> void:
	_down = true
	queue_redraw()
	await get_tree().create_timer(0.08).timeout
	_down = false
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y - DEPTH
	var y := DEPTH if _down and not disabled else 0
	var body := color
	var side := color_dark
	var txt := Art.WHITE
	if disabled:
		body = Art.SLATE_L
		side = Art.SLATE_D
		txt = Art.GREY
	elif _hover and not _down:
		body = color.lightened(0.12)
	# shadow / side
	Art.box(self, Rect2(0, DEPTH, w, h), Art.INK)
	Art.box(self, Rect2(1, DEPTH, w - 2, h - 1), side)
	# body
	var outline := Art.GOLD if selected else Art.INK
	Art.box(self, Rect2(0, y, w, h), outline)
	Art.box(self, Rect2(1, y + 1, w - 2, h - 2), body)
	if selected:
		Art.box(self, Rect2(1, y + 1, w - 2, h - 2), Art.GOLD)
		Art.box(self, Rect2(2, y + 2, w - 4, h - 4), body)
	# highlight line
	if not disabled:
		draw_rect(Rect2(2, y + 1, w - 4, 1), body.lightened(0.25))

	var text_y := y + floorf((h - PixelFont.GLYPH_H) / 2.0)
	var right := w
	if hotkey != "":
		var kw := PixelFont.measure(hotkey) + 4
		var kr := Rect2(w - kw - 3, y + 3, kw, h - 6)
		Art.box(self, kr, side if not disabled else Art.SLATE_D)
		PixelFont.draw(self, Vector2(kr.position.x + 2, text_y), hotkey, txt.darkened(0.15) if not disabled else Art.GREY_D)
		right = kr.position.x
	PixelFont.draw_centered(self, right / 2.0 + (1.0 if hotkey != "" else 0.0), text_y, text, txt, 1, Art.INK if not disabled else Color(0, 0, 0, 0))
