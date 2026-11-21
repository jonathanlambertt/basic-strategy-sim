extends Control
## Main table: plays engine events as animations, draws the HUD, routes input.

const W := 640.0
const H := 360.0
const TABLE_X := 150.0
const TABLE_CX := 395.0
const DEALER_Y := 82.0
const PLAYER_Y := 230.0
const SHOE_POS := Vector2(606, 32)
const DISCARD_POS := Vector2(200, -70)
const BAR_Y := 316.0
const CHIP_VALUES: Array[int] = [5, 25, 100, 500]

var engine: BlackjackEngine
var bet := 25.0
var display_bank := 0.0
var busy := false
var fast := false
var ui_phase := BlackjackEngine.Phase.BETTING

var dealer_sprites: Array[CardSprite] = []
var view_hands: Array[Dictionary] = [] # {sprites, bet, doubled, surrendered, result, net, cx}
var active_hand := -1
var insurance_taken := false
var even_money_offer := false
var acc_pulse := 0.0
var _time := 0.0

var hud: Control
var cards_layer: Node2D
var toast: Toast
var overlay_layer: CanvasLayer
var overlay: Overlay = null

var btn_hit: PixelButton
var btn_stand: PixelButton
var btn_double: PixelButton
var btn_split: PixelButton
var btn_surrender: PixelButton
var btn_clear: PixelButton
var btn_deal: PixelButton
var btn_rebuy: PixelButton
var btn_ins_yes: PixelButton
var btn_ins_no: PixelButton
var btn_chart: PixelButton
var btn_stats: PixelButton
var btn_rules: PixelButton
var chip_buttons: Array[ChipButton] = []


func _ready() -> void:
	size = Vector2(W, H)
	engine = BlackjackEngine.new()
	display_bank = engine.bankroll

	var felt := ColorRect.new()
	felt.size = Vector2(W, H)
	felt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var felt_mat := ShaderMaterial.new()
	felt_mat.shader = load("res://shaders/felt.gdshader")
	felt.material = felt_mat
	add_child(felt)

	hud = Control.new()
	hud.size = Vector2(W, H)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.draw.connect(_draw_hud)
	add_child(hud)

	cards_layer = Node2D.new()
	add_child(cards_layer)

	_build_buttons()

	toast = Toast.new()
	toast.position = Vector2(TABLE_CX, 156)
	toast.modulate.a = 0.0
	add_child(toast)

	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 5
	add_child(overlay_layer)

	_refresh()


func _process(delta: float) -> void:
	_time += delta
	acc_pulse = move_toward(acc_pulse, 0.0, delta * 2.5)
	hud.queue_redraw()


# ---------------------------------------------------------------- buttons

func _build_buttons() -> void:
	var bw := 86.0
	var gap := 5.0
	var x0 := TABLE_CX - (bw * 5 + gap * 4) / 2.0
	btn_hit = _button("HIT", Rect2(x0, BAR_Y, bw, 24), Art.RED, Art.RED_D, "H", func() -> void: _on_action("hit"))
	btn_stand = _button("STAND", Rect2(x0 + (bw + gap), BAR_Y, bw, 24), Art.ORANGE, Art.ORANGE_D, "S", func() -> void: _on_action("stand"))
	btn_double = _button("DOUBLE", Rect2(x0 + (bw + gap) * 2, BAR_Y, bw, 24), Art.BLUE, Art.BLUE_D, "D", func() -> void: _on_action("double"))
	btn_split = _button("SPLIT", Rect2(x0 + (bw + gap) * 3, BAR_Y, bw, 24), Art.GREEN, Art.GREEN_D, "P", func() -> void: _on_action("split"))
	btn_surrender = _button("SURRENDER", Rect2(x0 + (bw + gap) * 4, BAR_Y, bw, 24), Art.PURPLE, Art.PURPLE_D, "R", func() -> void: _on_action("surrender"))

	var cx := 168.0
	for v in CHIP_VALUES:
		var chip := ChipButton.new(v)
		chip.position = Vector2(cx, BAR_Y - 6)
		chip.add_pressed.connect(_on_chip_add)
		chip.remove_pressed.connect(_on_chip_remove)
		add_child(chip)
		chip_buttons.append(chip)
		cx += 38.0
	btn_clear = _button("CLEAR", Rect2(326, BAR_Y, 74, 24), Art.SLATE_L, Art.SLATE_D, "X", _on_clear)
	btn_deal = _button("DEAL", Rect2(408, BAR_Y, 216, 24), Art.GREEN, Art.GREEN_D, "SPACE", _on_deal)
	btn_rebuy = _button("NEW BANKROLL ($1,000)", Rect2(408, BAR_Y, 216, 24), Art.GOLD_D, Art.ORANGE_D, "SPACE", _on_rebuy)

	btn_ins_yes = _button("YES", Rect2(404, BAR_Y, 106, 24), Art.BLUE, Art.BLUE_D, "Y", func() -> void: _on_insurance(true))
	btn_ins_no = _button("NO", Rect2(516, BAR_Y, 106, 24), Art.BLUE, Art.BLUE_D, "N", func() -> void: _on_insurance(false))

	btn_chart = _button("STRATEGY CHART", Rect2(8, 268, 134, 22), Art.BLUE, Art.BLUE_D, "C", func() -> void: _open_overlay("chart"))
	btn_stats = _button("STATS", Rect2(8, 296, 134, 22), Art.SLATE_L, Art.SLATE_D, "T", func() -> void: _open_overlay("stats"))
	btn_rules = _button("TABLE RULES", Rect2(8, 324, 134, 22), Art.SLATE_L, Art.SLATE_D, "O", func() -> void: _open_overlay("rules"))


func _button(label: String, rect: Rect2, col: Color, dark: Color, key: String, cb: Callable) -> PixelButton:
	var b := PixelButton.make(label, rect, col, dark, key)
	b.pressed.connect(cb)
	add_child(b)
	return b


func _refresh() -> void:
	var between := ui_phase == BlackjackEngine.Phase.BETTING or ui_phase == BlackjackEngine.Phase.ROUND_OVER
	var broke := between and not busy and engine.bankroll < BlackjackEngine.MIN_BET
	for chip in chip_buttons:
		chip.visible = between
		chip.disabled = busy or bet + chip.value > engine.bankroll
	btn_clear.visible = between
	btn_clear.disabled = busy or bet <= 0.0
	btn_deal.visible = between and not broke
	btn_deal.disabled = busy or not engine.can_start(bet)
	btn_deal.text = "DEAL " + Art.money(bet) if bet > 0.0 else "DEAL"
	btn_rebuy.visible = broke

	var ins := ui_phase == BlackjackEngine.Phase.INSURANCE
	btn_ins_yes.visible = ins
	btn_ins_no.visible = ins
	btn_ins_yes.disabled = busy
	btn_ins_no.disabled = busy

	var playing := ui_phase == BlackjackEngine.Phase.PLAYER
	var av := engine.available() if not busy else {}
	for pair in [[btn_hit, "hit"], [btn_stand, "stand"], [btn_double, "double"], [btn_split, "split"], [btn_surrender, "surrender"]]:
		var b: PixelButton = pair[0]
		b.visible = playing
		b.disabled = busy or not av.get(pair[1], false)


# ---------------------------------------------------------------- betting

func _on_chip_add(value: int) -> void:
	if busy or not engine.is_between_rounds():
		return
	if bet + value <= engine.bankroll:
		bet += value
		_refresh()


func _on_chip_remove(value: int) -> void:
	if busy or not engine.is_between_rounds():
		return
	bet = maxf(0.0, bet - value)
	_refresh()


func _on_clear() -> void:
	if busy or not engine.is_between_rounds():
		return
	bet = 0.0
	_refresh()


func _on_rebuy() -> void:
	if busy or not engine.is_between_rounds():
		return
	engine.reset_bankroll()
	_set_bank(engine.bankroll)
	bet = minf(maxf(bet, BlackjackEngine.MIN_BET), engine.bankroll)
	toast.show_text("FRESH $1,000", Art.GOLD)
	_refresh()


func _fit_bet() -> void:
	if bet > engine.bankroll:
		bet = floorf(engine.bankroll / 5.0) * 5.0
	bet = maxf(bet, 0.0)


# ---------------------------------------------------------------- round flow

func _on_deal() -> void:
	if busy or not engine.can_start(bet):
		return
	busy = true
	ui_phase = BlackjackEngine.Phase.PLAYER
	_refresh()
	await _clear_table()
	insurance_taken = false
	even_money_offer = false
	view_hands = [_new_view_hand(bet)]
	var ev := engine.start_round(bet)
	await _play(ev)


func _on_action(action: String) -> void:
	if busy or overlay or engine.phase != BlackjackEngine.Phase.PLAYER:
		return
	if not engine.available().get(action, false):
		return
	var ev := engine.act(action)
	await _play(ev)


func _on_insurance(take: bool) -> void:
	if busy or overlay or engine.phase != BlackjackEngine.Phase.INSURANCE:
		return
	insurance_taken = take
	var ev := engine.insurance(take)
	await _play(ev)


func _play(events: Array[Dictionary]) -> void:
	busy = true
	_refresh()
	for e in events:
		await _apply(e)
	busy = false
	ui_phase = engine.phase
	if engine.is_between_rounds():
		_fit_bet()
	_refresh()


func _new_view_hand(stake: float) -> Dictionary:
	return {"sprites": [], "bet": stake, "doubled": false, "surrendered": false, "result": "", "net": 0.0, "cx": TABLE_CX}


func _speed() -> float:
	return 0.5 if fast else 1.0


func _wait(t: float) -> void:
	await get_tree().create_timer(t * _speed()).timeout


func _apply(e: Dictionary) -> void:
	match e["t"]:
		"shuffle":
			toast.show_text("SHUFFLING A NEW SHOE", Art.GOLD, 0.6)
			await _wait(0.9)
		"bank":
			_set_bank(e["value"])
		"deal":
			await _deal(e)
		"insurance":
			even_money_offer = e["even_money"]
		"peek":
			toast.show_text("DEALER CHECKS FOR BLACKJACK", Art.CREAM, 0.35)
			if dealer_sprites.size() > 1:
				var hole := dealer_sprites[1]
				var t := create_tween()
				t.tween_property(hole, "rotation", -0.12, 0.1)
				t.tween_property(hole, "rotation", 0.06, 0.1)
				t.tween_property(hole, "rotation", 0.0, 0.1)
			await _wait(0.8)
			if not e["bj"]:
				toast.show_text("NO BLACKJACK", Art.GREY, 0.3)
				await _wait(0.45)
		"reveal":
			if dealer_sprites.size() > 1:
				dealer_sprites[1].flip(true, 0.24 * _speed())
			await _wait(0.4)
		"split":
			var i: int = e["hand"]
			var vh := view_hands[i]
			var nh := _new_view_hand(vh["bet"])
			nh["sprites"].append(vh["sprites"].pop_back())
			view_hands.insert(i + 1, nh)
			active_hand = i
			_layout(0.3)
			await _wait(0.35)
		"double":
			var vh := view_hands[e["hand"]]
			vh["bet"] *= 2.0
			vh["doubled"] = true
			await _wait(0.12)
		"surrender":
			view_hands[e["hand"]]["surrendered"] = true
			await _wait(0.15)
		"active":
			active_hand = e["hand"]
			_layout(0.18)
		"decision":
			acc_pulse = 1.0
		"settle":
			await _settle(e)


func _deal(e: Dictionary) -> void:
	var spr := CardSprite.new().setup(e["card"], false)
	spr.position = SHOE_POS
	spr.rotation = -0.25
	spr.z_index = 150
	cards_layer.add_child(spr)
	var is_dealer: bool = e["to"] == "d"
	if is_dealer:
		dealer_sprites.append(spr)
	else:
		view_hands[e["hand"]]["sprites"].append(spr)
		spr.hoverable = true
		active_hand = e["hand"] if view_hands.size() > 1 else active_hand
	var dur := 0.34 * _speed()
	_layout(dur)
	if not e["down"]:
		spr.flip(true, 0.22 * _speed())
	await _wait(0.42 if is_dealer and dealer_sprites.size() > 2 else 0.26)


func _settle(e: Dictionary) -> void:
	active_hand = -1
	var results: Array = e["results"]
	for r in results:
		var vh := view_hands[r["hand"]]
		vh["result"] = r["result"]
		vh["net"] = r["net"]
		if r["result"] == "WIN" or r["result"] == "BLACKJACK":
			for s in vh["sprites"]:
				s.pop()
	_layout(0.2)
	var net: float = e["net"]
	if e["dealer_bj"]:
		toast.show_text("DEALER BLACKJACK", Art.RED, 0.8)
	elif results.size() == 1 and results[0]["result"] == "BLACKJACK":
		toast.show_text("BLACKJACK!  " + Art.signed_money(net), Art.GOLD, 0.8)
	elif net > 0.0:
		toast.show_text("YOU WIN " + Art.signed_money(net), Art.GREEN, 0.7)
	elif net < 0.0:
		toast.show_text("YOU LOSE " + Art.money(-net), Art.RED_L, 0.7)
	else:
		toast.show_text("PUSH", Art.CREAM, 0.6)
	await _wait(0.45)


func _clear_table() -> void:
	var all: Array[CardSprite] = []
	all.append_array(dealer_sprites)
	for vh in view_hands:
		for s in vh["sprites"]:
			all.append(s)
	dealer_sprites.clear()
	view_hands.clear()
	active_hand = -1
	toast.hide_now()
	if all.is_empty():
		return
	for i in all.size():
		all[i].discard(DISCARD_POS + Vector2(i * 3, 0), 0.3 * _speed())
	await _wait(0.22)


func _set_bank(v: float) -> void:
	var t := create_tween()
	t.tween_property(self, "display_bank", v, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Positions every card; cards glide to their spots.
func _layout(dur: float) -> void:
	var n := dealer_sprites.size()
	var off := 24.0
	var w := Art.CARD_W + (n - 1) * off
	var x0 := TABLE_CX - w / 2.0 + Art.CARD_W / 2.0
	for i in n:
		var s := dealer_sprites[i]
		s.base_z = i
		s.move_to(Vector2(roundf(x0 + i * off), DEALER_Y), 0.0, dur)

	var k := view_hands.size()
	if k == 0:
		return
	var left := TABLE_X + 12.0
	var right := W - 12.0
	var slot := (right - left) / k
	for hi in k:
		var vh := view_hands[hi]
		var sprites: Array = vh["sprites"]
		var m := sprites.size()
		var cx := left + slot * (hi + 0.5)
		vh["cx"] = cx
		var poff := 20.0 if k == 1 else 16.0
		if m > 1:
			poff = minf(poff, (slot - Art.CARD_W - 12.0) / (m - 1))
		var hw := Art.CARD_W + (m - 1) * poff
		var raise := 8.0 if hi == active_hand and k > 1 else 0.0
		var mid := (m - 1) / 2.0
		for ci in m:
			var s: CardSprite = sprites[ci]
			var pos := Vector2(cx - hw / 2.0 + Art.CARD_W / 2.0 + ci * poff, PLAYER_Y - raise + absf(ci - mid))
			var rot := deg_to_rad((ci - mid) * 2.5)
			if vh["doubled"] and ci == 2:
				rot = PI / 2.0
				pos += Vector2(12, 3)
			s.base_z = 20 + hi * 20 + ci
			s.move_to(pos.round(), rot, dur)


# ---------------------------------------------------------------- overlays

func _open_overlay(kind: String) -> void:
	if overlay:
		_close_overlay()
	match kind:
		"chart":
			overlay = ChartOverlay.new(engine.rules)
		"stats":
			var so := StatsOverlay.new(engine.stats)
			so.reset_requested.connect(func() -> void: engine.stats.reset())
			overlay = so
		"rules":
			var st := SettingsOverlay.new(engine.rules, fast)
			st.is_locked = func() -> bool: return busy or not engine.is_between_rounds()
			st.rules_changed.connect(_on_rules_changed)
			st.display_changed.connect(_on_display_changed)
			st.bankroll_reset.connect(_on_bankroll_reset)
			overlay = st
	overlay.closed.connect(_close_overlay)
	overlay_layer.add_child(overlay)


func _close_overlay() -> void:
	if overlay:
		overlay.queue_free()
		overlay = null


func _on_rules_changed(r: Rules) -> void:
	if busy or not engine.is_between_rounds():
		return
	if engine.set_rules(r):
		toast.show_text("NEW %d-DECK SHOE" % r.decks, Art.GOLD)


func _on_display_changed(f: bool) -> void:
	fast = f


func _on_bankroll_reset() -> void:
	if busy or not engine.is_between_rounds():
		return
	engine.reset_bankroll()
	_set_bank(engine.bankroll)
	_fit_bet()
	_refresh()


# ---------------------------------------------------------------- keys

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: Key = event.keycode
	get_viewport().set_input_as_handled()
	if overlay:
		var toggle := (k == KEY_C and overlay is ChartOverlay) or (k == KEY_T and overlay is StatsOverlay) \
			or (k == KEY_O and overlay is SettingsOverlay)
		if k == KEY_ESCAPE or toggle:
			_close_overlay()
		else:
			overlay.handle_key(k)
		return
	match k:
		KEY_H:
			_press(btn_hit)
		KEY_S:
			_press(btn_stand)
		KEY_D:
			_press(btn_double)
		KEY_P:
			_press(btn_split)
		KEY_R:
			_press(btn_surrender)
		KEY_Y:
			_press(btn_ins_yes)
		KEY_N:
			_press(btn_ins_no)
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			if btn_rebuy.visible:
				_press(btn_rebuy)
			else:
				_press(btn_deal)
		KEY_X, KEY_BACKSPACE:
			_press(btn_clear)
		KEY_1, KEY_2, KEY_3, KEY_4:
			var chip := chip_buttons[k - KEY_1]
			if chip.visible and not chip.disabled:
				_on_chip_add(chip.value)
		KEY_C:
			_open_overlay("chart")
		KEY_T:
			_open_overlay("stats")
		KEY_O:
			_open_overlay("rules")


func _press(b: PixelButton) -> void:
	if b.visible and not b.disabled:
		b.flash()
		b.pressed.emit()


# ---------------------------------------------------------------- HUD

func _draw_hud() -> void:
	var ci := hud
	_draw_felt_print(ci)
	_draw_shoe(ci)
	_draw_dealer_info(ci)
	_draw_hands_info(ci)
	_draw_bar_info(ci)
	_draw_sidebar(ci)


func _draw_sidebar(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, TABLE_X, H), Art.SLATE_D)
	ci.draw_rect(Rect2(TABLE_X - 2, 0, 2, H), Art.INK)
	ci.draw_rect(Rect2(TABLE_X, 0, 2, H), Color(0, 0, 0, 0.25))
	PixelFont.draw_centered(ci, 75, 9, "BLACKJACK", Art.GOLD, 2, Art.INK)
	PixelFont.draw_centered(ci, 75, 27, "BASIC STRATEGY TRAINER", Art.GREY)

	var r := Rect2(8, 42, 134, 38)
	Art.panel(ci, r, Art.SLATE)
	PixelFont.draw(ci, r.position + Vector2(7, 6), "BANKROLL", Art.GREY)
	PixelFont.draw(ci, r.position + Vector2(7, 18), Art.money(display_bank), Art.GOLD, 2, Art.INK)

	r = Rect2(8, 86, 134, 38)
	Art.panel(ci, r, Art.SLATE)
	var on_table := 0.0
	for vh in view_hands:
		if vh["result"] == "":
			on_table += vh["bet"]
	var between := engine.is_between_rounds() and not busy
	PixelFont.draw(ci, r.position + Vector2(7, 6), "NEXT BET" if between else "ON THE TABLE", Art.GREY)
	PixelFont.draw(ci, r.position + Vector2(7, 18), Art.money(bet if between else on_table), Art.WHITE, 2, Art.INK)
	if insurance_taken and not between:
		PixelFont.draw_right(ci, r.end.x - 7, r.position.y + 6, "+INS " + Art.money(engine.insurance_bet), Art.BLUE_L)

	r = Rect2(8, 130, 134, 56)
	Art.panel(ci, r, Art.SLATE)
	if acc_pulse > 0.0:
		Art.box(ci, r.grow(1), Color(Art.GOLD, acc_pulse * 0.8))
		Art.box(ci, r.grow(-1), Art.SLATE)
	var st := engine.stats
	var acc := st.accuracy()
	PixelFont.draw(ci, r.position + Vector2(7, 6), "ACCURACY", Art.GREY)
	PixelFont.draw(ci, r.position + Vector2(7, 18), StatsOverlay.pct_text(acc), StatsOverlay.pct_color(acc), 2, Art.INK)
	PixelFont.draw_right(ci, r.end.x - 7, r.position.y + 21, "%d/%d" % [st.correct, st.decisions], Art.CREAM)
	PixelFont.draw(ci, r.position + Vector2(7, 40), "STREAK %d · BEST %d" % [st.streak, st.best_streak], Art.CREAM)

	r = Rect2(8, 192, 134, 68)
	Art.panel(ci, r, Art.SLATE)
	var rules := engine.rules
	PixelFont.draw(ci, r.position + Vector2(7, 6), "TABLE", Art.GREY)
	PixelFont.draw_right(ci, r.end.x - 7, r.position.y + 6, "%d DECKS" % rules.decks, Art.CREAM)
	PixelFont.draw(ci, r.position + Vector2(7, 18), "DEALER HITS SOFT 17" if rules.h17 else "DEALER STANDS ON 17", Art.CREAM)
	PixelFont.draw(ci, r.position + Vector2(7, 29), ("DAS" if rules.das else "NO DAS") + " · " + ("SURRENDER" if rules.surrender else "NO SURRENDER"), Art.CREAM)
	PixelFont.draw(ci, r.position + Vector2(7, 45), "SHOE", Art.GREY)
	var bar := Rect2(r.position.x + 34, r.position.y + 45, 92, 7)
	Art.box(ci, bar, Art.SLATE_D)
	var frac := engine.shoe.fraction_until_cut()
	var fw := roundf((bar.size.x - 2) * frac)
	if fw > 0:
		ci.draw_rect(Rect2(bar.position.x + 1, bar.position.y + 1, fw, 5), Art.GOLD if frac > 0.15 else Art.RED)


func _draw_felt_print(ci: CanvasItem) -> void:
	var ink := Color(0.8, 0.95, 0.85, 0.16)
	# arc of dashes, like the insurance line on a real table
	var segs := 40
	for i in segs:
		if i % 2 == 1:
			continue
		var t0 := float(i) / segs
		var t1 := float(i + 1) / segs
		var p0 := Vector2(lerpf(184, 606, t0), 134 + sin(t0 * PI) * 40)
		var p1 := Vector2(lerpf(184, 606, t1), 134 + sin(t1 * PI) * 40)
		ci.draw_line(p0.round(), p1.round(), ink, 2.0)
	var lines := engine.rules.felt_lines()
	PixelFont.draw_centered(ci, TABLE_CX, 130, lines[0], ink, 1)
	PixelFont.draw_centered(ci, TABLE_CX, 142, lines[1], ink, 1)
	PixelFont.draw_centered(ci, TABLE_CX, 154, lines[2], ink, 1)


func _draw_shoe(ci: CanvasItem) -> void:
	var back := Art.card_back()
	var base := SHOE_POS - Vector2(Art.CARD_W, Art.CARD_H) / 2.0
	base = base.floor()
	Art.box(ci, Rect2(base + Vector2(-4, 6), Vector2(Art.CARD_W + 8, Art.CARD_H)), Art.SHADOW)
	for i in 3:
		ci.draw_texture(back, base + Vector2(2 - i, 2 - i))
	PixelFont.draw_centered(ci, SHOE_POS.x, base.y + Art.CARD_H + 6, "SHOE", Color(0.8, 0.95, 0.85, 0.35))


func _visible_cards(sprites: Array) -> Array:
	var out := []
	for s in sprites:
		if s.landed and s.face_up:
			out.append(s.card)
	return out


func _total_text(cards: Array, two_card_bj: bool) -> String:
	if cards.size() == 1 and Hand.rank_of(cards[0]) == 1:
		return "A"
	var t := Hand.total_of(cards)
	if t > 21:
		return "BUST"
	if two_card_bj and cards.size() == 2 and t == 21:
		return "BLACKJACK"
	if Hand.is_soft_list(cards) and t < 21:
		return "SOFT %d" % t
	return str(t)


func _badge(ci: CanvasItem, cx: float, y: float, text: String, fill: Color, col: Color) -> void:
	var w := PixelFont.measure(text) + 10
	var r := Rect2(roundf(cx - w / 2.0), y, w, 13)
	Art.panel(ci, r, fill)
	PixelFont.draw_centered(ci, cx, y + 3, text, col)


func _draw_dealer_info(ci: CanvasItem) -> void:
	PixelFont.draw_centered(ci, TABLE_CX, 38, "DEALER", Color(0.85, 0.95, 0.9, 0.55))
	if dealer_sprites.is_empty():
		return
	var cards := _visible_cards(dealer_sprites)
	if cards.is_empty():
		return
	var text := _total_text(cards, true)
	var fill := Art.SLATE
	var col := Art.WHITE
	if text == "BUST":
		fill = Art.RED_D
	elif text == "BLACKJACK":
		fill = Art.GOLD_D
	_badge(ci, TABLE_CX, DEALER_Y + 33, text, fill, col)


func _draw_hands_info(ci: CanvasItem) -> void:
	var multi := view_hands.size() > 1
	for hi in view_hands.size():
		var vh := view_hands[hi]
		var cx: float = vh["cx"]
		var cards := _visible_cards(vh["sprites"])
		var res: String = vh["result"]
		# total
		if not cards.is_empty():
			var text := _total_text(cards, not multi)
			var fill := Art.SLATE
			if text == "BUST":
				fill = Art.RED_D
			elif text == "BLACKJACK":
				fill = Art.GOLD_D
			elif hi == active_hand and multi:
				fill = Art.BLUE_D
			_badge(ci, cx, PLAYER_Y + 34, text, fill, Art.WHITE)
		# bet chips
		_draw_chip_stack(ci, Vector2(cx - 14, PLAYER_Y + 62), vh["bet"])
		var bet_text := Art.money(vh["bet"])
		if vh["doubled"]:
			bet_text += " X2"
		PixelFont.draw(ci, Vector2(cx - 2, PLAYER_Y + 56), bet_text, Art.WHITE, 1, Art.INK)
		# result or active marker
		if res != "":
			_draw_result(ci, cx, PLAYER_Y - 50, res, vh["net"])
		elif hi == active_hand and multi and not busy:
			var bob := roundf(sin(_time * 6.0) * 1.5)
			var ty := PLAYER_Y - 52 + bob
			ci.draw_colored_polygon(PackedVector2Array([Vector2(cx - 5, ty), Vector2(cx + 6, ty), Vector2(cx + 0.5, ty + 6)]), Art.GOLD)

	if view_hands.is_empty() and engine.is_between_rounds():
		_draw_chip_stack(ci, Vector2(TABLE_CX - 14, PLAYER_Y + 62), bet)
		if bet > 0.0:
			PixelFont.draw(ci, Vector2(TABLE_CX - 2, PLAYER_Y + 56), Art.money(bet), Art.WHITE, 1, Art.INK)
		var msg := "PLACE YOUR BET, THEN DEAL" if engine.bankroll >= BlackjackEngine.MIN_BET else "OUT OF CHIPS"
		PixelFont.draw_centered(ci, TABLE_CX, PLAYER_Y - 4, msg, Color(0.9, 1.0, 0.95, 0.7), 1, Art.INK)


func _draw_result(ci: CanvasItem, cx: float, y: float, res: String, net: float) -> void:
	var fill := Art.SLATE
	var col := Art.WHITE
	var text := res
	match res:
		"WIN":
			fill = Art.GREEN_D
			text = "WIN " + Art.signed_money(net)
		"BLACKJACK":
			fill = Art.GOLD_D
			text = "BLACKJACK " + Art.signed_money(net)
		"PUSH":
			fill = Art.SLATE_L
		"SURRENDER":
			fill = Art.PURPLE_D
			text = "SURRENDER " + Art.money(net)
		_:
			fill = Art.RED_D
			text = res + " " + Art.money(net)
	var w := PixelFont.measure(text) + 12
	var r := Rect2(roundf(cx - w / 2.0), y, w, 15)
	Art.panel(ci, r, fill)
	PixelFont.draw_centered(ci, cx, y + 4, text, col, 1, Art.INK)


func _draw_chip_stack(ci: CanvasItem, pos: Vector2, amount: float) -> void:
	if amount <= 0.0:
		return
	var chips := Art.chip_breakdown(amount)
	var shown := mini(chips.size(), 8)
	for i in shown:
		ci.draw_texture(Art.chip_texture(chips[i], 16), pos + Vector2(-8, -8 - i * 2))


func _draw_bar_info(ci: CanvasItem) -> void:
	if ui_phase == BlackjackEngine.Phase.INSURANCE and not busy:
		var q := "EVEN MONEY?" if even_money_offer else "INSURANCE?"
		PixelFont.draw(ci, Vector2(170, BAR_Y + 2), q, Art.GOLD, 2, Art.INK)
		var cost := engine.hands[0].bet / 2.0 if not engine.hands.is_empty() else 0.0
		PixelFont.draw(ci, Vector2(170, BAR_Y + 18), "COSTS " + Art.money(cost) + " · PAYS 2:1", Art.CREAM, 1, Art.INK)
