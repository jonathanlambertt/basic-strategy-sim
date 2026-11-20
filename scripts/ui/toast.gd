class_name Toast
extends Node2D
## Big centred message that pops in, holds, then fades.

var text := ""
var color := Art.WHITE
var _tween: Tween


func show_text(msg: String, col: Color = Art.WHITE, hold: float = 0.7) -> void:
	text = msg
	color = col
	modulate.a = 1.0
	scale = Vector2(0.6, 0.6)
	queue_redraw()
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(hold)
	_tween.tween_property(self, "modulate:a", 0.0, 0.25)


func hide_now() -> void:
	if _tween:
		_tween.kill()
	modulate.a = 0.0


func _draw() -> void:
	if text.is_empty():
		return
	var w := PixelFont.measure(text, 2) + 24
	var r := Rect2(-roundf(w / 2.0), -14, w, 28)
	Art.panel(self, r, Art.SLATE)
	Art.box(self, r.grow(-2), Art.SLATE_L)
	Art.box(self, r.grow(-3), Art.SLATE)
	PixelFont.draw_centered(self, 0, -7, text, color, 2, Art.INK)
