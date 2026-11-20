class_name CardSprite
extends Node2D
## One card on the table. Drawn centred on its position so it can rotate and flip in place.

var card := 0
var face_up := false
var landed := false
var hoverable := false
var base_z := 0

var _move: Tween
var _flip: Tween
var _hover := 0.0
var _tilt := 0.0


func setup(card_id: int, up: bool) -> CardSprite:
	card = card_id
	face_up = up
	return self


func _process(delta: float) -> void:
	var want := 0.0
	var want_tilt := 0.0
	if hoverable and landed:
		var m := get_local_mouse_position()
		var half := Vector2(Art.CARD_W, Art.CARD_H) / 2.0
		if absf(m.x) <= half.x and absf(m.y) <= half.y:
			want = 1.0
			want_tilt = clampf(m.x / half.x, -1.0, 1.0)
	var nh := move_toward(_hover, want, delta * 7.0)
	var nt := move_toward(_tilt, want_tilt, delta * 5.0)
	if nh != _hover or nt != _tilt:
		_hover = nh
		_tilt = nt
		queue_redraw()


func _draw() -> void:
	var tex := Art.card_texture(card) if face_up else Art.card_back()
	var half := Vector2(Art.CARD_W, Art.CARD_H) / 2.0
	var lift := roundf(_hover * 4.0)
	draw_set_transform(Vector2(0, -lift), _tilt * _hover * 0.05, Vector2.ONE)
	draw_texture(tex, -half.floor() + Vector2(2, 3 + lift), Art.SHADOW)
	draw_texture(tex, -half.floor())
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Glides to a spot on the table.
func move_to(pos: Vector2, rot: float, duration: float) -> void:
	if _move:
		_move.kill()
	if duration <= 0.0:
		position = pos
		rotation = rot
		landed = true
		z_index = base_z
		return
	_move = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_move.tween_property(self, "position", pos, duration)
	_move.tween_property(self, "rotation", rot, duration)
	_move.chain().tween_callback(func() -> void:
		landed = true
		z_index = base_z)


## Turns the card over by squashing it horizontally.
func flip(up: bool, duration: float) -> void:
	if _flip:
		_flip.kill()
	_flip = create_tween()
	_flip.tween_property(self, "scale:x", 0.0, duration / 2.0).set_trans(Tween.TRANS_SINE)
	_flip.tween_callback(func() -> void:
		face_up = up
		queue_redraw())
	_flip.tween_property(self, "scale:x", 1.0, duration / 2.0).set_trans(Tween.TRANS_SINE)


## Quick squash-and-stretch, used for emphasis.
func pop() -> void:
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1.12, 1.12), 0.08)
	t.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Sweeps the card off the table and frees it.
func discard(to: Vector2, duration: float) -> void:
	if _move:
		_move.kill()
	landed = false
	hoverable = false
	z_index = 200
	var t := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(self, "position", to, duration)
	t.tween_property(self, "rotation", rotation + 0.6, duration)
	t.chain().tween_callback(queue_free)
