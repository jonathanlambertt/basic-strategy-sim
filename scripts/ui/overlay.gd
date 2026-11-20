class_name Overlay
extends Control
## Base for full-screen panels (chart, stats, table rules). Subclasses draw in _draw_content().

signal closed

const PANEL := Rect2(10, 8, 620, 344)

var title := ""
var _close_btn: PixelButton


func _init() -> void:
	position = Vector2.ZERO
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	_close_btn = PixelButton.make("X", Rect2(PANEL.end.x - 30, PANEL.position.y + 8, 22, 18), Art.RED, Art.RED_D)
	_close_btn.pressed.connect(close)
	add_child(_close_btn)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.12)


func close() -> void:
	closed.emit()


## Keys other than Esc are passed here while the overlay is open.
func handle_key(_keycode: Key) -> void:
	pass


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.05, 0.75))
	Art.panel(self, PANEL, Art.SLATE)
	Art.box(self, PANEL.grow(-2), Art.SLATE_L)
	Art.box(self, PANEL.grow(-3), Art.SLATE)
	PixelFont.draw(self, PANEL.position + Vector2(12, 11), title, Art.GOLD, 2, Art.INK)
	_draw_content()


func _draw_content() -> void:
	pass
