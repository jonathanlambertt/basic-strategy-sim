class_name SettingsOverlay
extends Overlay
## Table rules (which drive the strategy chart) and display options.

signal rules_changed(new_rules: Rules)
signal display_changed(fast: bool)
signal bankroll_reset

const OPT_X := 230
const KEYS_X := 452

var rules: Rules
var fast := false
var is_locked: Callable = func() -> bool: return false

var _opts := [] # [{button, row, value}]
var _rule_buttons: Array[PixelButton] = []
var _bank_btn: PixelButton
var _locked := false


func _init(current: Rules = null, fast_anim: bool = false) -> void:
	super()
	rules = current.copy() if current else Rules.new()
	fast = fast_anim
	title = "TABLE RULES"


func _ready() -> void:
	super()
	_add_row("decks", 60, [["4", 4], ["6", 6], ["8", 8]], 40, true)
	_add_row("h17", 88, [["STANDS", false], ["HITS", true]], 70, true)
	_add_row("das", 116, [["ALLOWED", true], ["NOT ALLOWED", false]], 76, true)
	_add_row("surrender", 144, [["ALLOWED", true], ["NOT ALLOWED", false]], 76, true)
	_add_row("fast", 240, [["NORMAL", false], ["FAST", true]], 70, false)
	_bank_btn = PixelButton.make("RESET BANKROLL TO $1,000", Rect2(24, 318, 170, 20), Art.RED, Art.RED_D)
	_bank_btn.pressed.connect(func() -> void: bankroll_reset.emit())
	add_child(_bank_btn)
	_refresh()


func _add_row(row: String, y: int, options: Array, w: int, is_rule: bool) -> void:
	var x := OPT_X
	for o in options:
		var b := PixelButton.make(o[0], Rect2(x, y - 5, w, 20), Art.SLATE_L, Art.SLATE_D)
		var value: Variant = o[1]
		b.pressed.connect(func() -> void: _choose(row, value))
		add_child(b)
		_opts.append({"button": b, "row": row, "value": value})
		if is_rule:
			_rule_buttons.append(b)
		x += w + 6


func _process(_delta: float) -> void:
	var l: bool = is_locked.call()
	if l != _locked:
		_refresh()


func _value(row: String) -> Variant:
	match row:
		"decks":
			return rules.decks
		"h17":
			return rules.h17
		"das":
			return rules.das
		"surrender":
			return rules.surrender
		"fast":
			return fast
	return null


func _choose(row: String, value: Variant) -> void:
	match row:
		"decks", "h17", "das", "surrender":
			if is_locked.call():
				return
			var r := rules.copy()
			r.set(row, value)
			if r.equals(rules):
				return
			rules = r
			rules_changed.emit(rules.copy())
		"fast":
			fast = value
			display_changed.emit(fast)
	_refresh()


func _refresh() -> void:
	_locked = is_locked.call()
	for o in _opts:
		var b: PixelButton = o["button"]
		var on: bool = _value(o["row"]) == o["value"]
		b.selected = on
		b.color = Art.BLUE if on else Art.SLATE_L
		b.color_dark = Art.BLUE_D if on else Art.SLATE_D
	for b in _rule_buttons:
		b.disabled = _locked and not b.selected
	if _bank_btn:
		_bank_btn.disabled = _locked
	queue_redraw()


func _draw_content() -> void:
	PixelFont.draw(self, Vector2(24, 40), "THE STRATEGY CHART, GUIDE AND ACCURACY CHECKS FOLLOW THESE RULES.", Art.GREY)
	_label(60, "DECKS", "4, 6 AND 8 DECKS USE THE SAME CHART")
	_label(88, "DEALER SOFT 17", "STANDS = S17, HITS = H17")
	_label(116, "DOUBLE AFTER SPLIT", "DOUBLE ON A HAND MADE BY SPLITTING")
	_label(144, "LATE SURRENDER", "GIVE UP AND GET HALF YOUR BET BACK")
	var y := 176
	var fixed := "ALWAYS: DEALER PEEKS FOR BLACKJACK · BLACKJACK PAYS 3:2 · INSURANCE PAYS 2:1 · SPLIT UP TO 4 HANDS · SPLIT ACES GET ONE CARD"
	for line in PixelFont.wrap(fixed, KEYS_X - 40):
		PixelFont.draw(self, Vector2(24, y), line, Art.GREY_D)
		y += 10
	if _locked:
		PixelFont.draw(self, Vector2(24, y + 4), "FINISH THE CURRENT HAND TO CHANGE RULES.", Art.RED_L)

	PixelFont.draw(self, Vector2(24, 222), "DISPLAY", Art.GOLD)
	_label(240, "ANIMATIONS", "")
	PixelFont.draw(self, Vector2(24, 302), "BANKROLL", Art.GOLD)

	# key reference
	draw_rect(Rect2(KEYS_X - 12, 56, 1, 284), Art.SLATE_L)
	PixelFont.draw(self, Vector2(KEYS_X, 56), "KEYS", Art.GOLD)
	var keys := [
		["H", "HIT"], ["S", "STAND"], ["D", "DOUBLE"], ["P", "SPLIT"], ["R", "SURRENDER"],
		["Y / N", "INSURANCE"], ["SPACE", "DEAL"], ["1-4", "ADD A CHIP"], ["X", "CLEAR BET"],
		["C", "CHART"], ["T", "STATS"], ["O", "TABLE RULES"], ["ESC", "CLOSE PANEL"],
	]
	var ky := 72
	for k in keys:
		var kw := PixelFont.measure(k[0]) + 6
		Art.box(self, Rect2(KEYS_X, ky - 2, kw, 11), Art.SLATE_D)
		PixelFont.draw(self, Vector2(KEYS_X + 3, ky), k[0], Art.WHITE)
		PixelFont.draw(self, Vector2(KEYS_X + 44, ky), k[1], Art.CREAM)
		ky += 15
	PixelFont.draw(self, Vector2(KEYS_X, ky + 4), "RIGHT-CLICK A CHIP", Art.GREY)
	PixelFont.draw(self, Vector2(KEYS_X, ky + 14), "TO REMOVE IT", Art.GREY)


func _label(y: int, text: String, hint: String) -> void:
	PixelFont.draw(self, Vector2(24, y - 2 if hint != "" else y), text, Art.CREAM)
	if hint != "":
		PixelFont.draw(self, Vector2(24, y + 8), hint, Art.GREY_D)
