class_name ChartOverlay
extends Overlay
## Basic strategy chart for the active rules, plus a written guide.

const TABLE_Y := 54
const ROW_PITCH := 11
const CELL_PITCH := 17
const LABEL_W := 30
const GUIDE_RECT := Rect2(22, 50, 586, 292)

var rules: Rules
var tab := "chart"
var _chart: Dictionary
var _guide: Array[Dictionary]
var _guide_lines: Array = [] # [{text, kind}] pre-wrapped
var _scroll := 0.0
var _guide_view: Control
var _tab_chart: PixelButton
var _tab_guide: PixelButton


static func code_colors(code: String) -> Array[Color]:
	match code:
		"H":
			return [Art.RED, Art.WHITE]
		"S":
			return [Art.ORANGE, Art.WHITE]
		"D":
			return [Art.BLUE, Art.WHITE]
		"DS":
			return [Art.BLUE_L, Art.INK]
		"P":
			return [Art.GREEN, Art.WHITE]
	return [Art.PURPLE, Art.WHITE] # RH, RS, RP


func _init(active_rules: Rules = null) -> void:
	super()
	rules = active_rules.copy() if active_rules else Rules.new()
	title = "BASIC STRATEGY"
	_chart = Strategy.chart(rules)
	_guide = Strategy.guide(rules)
	_build_guide_lines()


func _ready() -> void:
	super()
	_tab_chart = PixelButton.make("CHART", Rect2(462, 16, 64, 20), Art.BLUE, Art.BLUE_D)
	_tab_guide = PixelButton.make("GUIDE", Rect2(530, 16, 64, 20), Art.BLUE, Art.BLUE_D)
	_tab_chart.pressed.connect(func() -> void: set_tab("chart"))
	_tab_guide.pressed.connect(func() -> void: set_tab("guide"))
	add_child(_tab_chart)
	add_child(_tab_guide)
	_guide_view = Control.new()
	_guide_view.position = GUIDE_RECT.position
	_guide_view.size = GUIDE_RECT.size
	_guide_view.clip_contents = true
	_guide_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guide_view.draw.connect(_draw_guide)
	add_child(_guide_view)
	set_tab(tab)


func set_tab(t: String) -> void:
	tab = t
	_tab_chart.selected = tab == "chart"
	_tab_guide.selected = tab == "guide"
	_guide_view.visible = tab == "guide"
	queue_redraw()


func handle_key(keycode: Key) -> void:
	match keycode:
		KEY_TAB, KEY_LEFT, KEY_RIGHT, KEY_G:
			set_tab("guide" if tab == "chart" else "chart")
		KEY_DOWN:
			_scroll_by(20)
		KEY_UP:
			_scroll_by(-20)
		KEY_PAGEDOWN, KEY_SPACE:
			_scroll_by(200)
		KEY_PAGEUP:
			_scroll_by(-200)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and tab == "guide":
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_by(20)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_by(-20)
			accept_event()


func _scroll_by(dy: float) -> void:
	if tab != "guide":
		return
	_scroll = clampf(_scroll + dy, 0.0, _max_scroll())
	_guide_view.queue_redraw()
	queue_redraw()


func _content_height() -> float:
	var h := 0.0
	for l in _guide_lines:
		h += _line_h(l["kind"])
	return h


func _max_scroll() -> float:
	return maxf(0.0, _content_height() - GUIDE_RECT.size.y)


func _line_h(kind: String) -> float:
	match kind:
		"title":
			return 14.0
		"gap":
			return 8.0
	return 10.0


func _build_guide_lines() -> void:
	_guide_lines = []
	var width := int(GUIDE_RECT.size.x) - 24
	for si in _guide.size():
		var s: Dictionary = _guide[si]
		if si > 0:
			_guide_lines.append({"text": "", "kind": "gap"})
		_guide_lines.append({"text": s["title"], "kind": "title"})
		for line in s["lines"]:
			var wrapped := PixelFont.wrap(line, width)
			for wi in wrapped.size():
				_guide_lines.append({"text": wrapped[wi], "kind": "first" if wi == 0 else "cont"})


func _rules_line() -> String:
	var parts: Array[String] = ["%d DECKS" % rules.decks]
	parts.append("DEALER HITS SOFT 17" if rules.h17 else "DEALER STANDS ON SOFT 17")
	parts.append("DOUBLE AFTER SPLIT" if rules.das else "NO DOUBLE AFTER SPLIT")
	parts.append("LATE SURRENDER" if rules.surrender else "NO SURRENDER")
	return " · ".join(parts)


func _draw_content() -> void:
	PixelFont.draw(self, Vector2(22, 38), "RULES: " + _rules_line(), Art.GREY)
	if tab == "chart":
		_draw_chart()
	else:
		_draw_scrollbar()


# ---------------------------------------------------------------- chart tab

func _draw_chart() -> void:
	var hard_rows: Array = [["5-8", 8]]
	for t in range(9, 18):
		hard_rows.append([str(t), t])
	hard_rows.append(["18+", 18])
	var soft_rows: Array = []
	for t in range(13, 21):
		soft_rows.append(["A,%d" % (t - 11), t])
	var pair_rows: Array = []
	for v in range(2, 11):
		pair_rows.append(["%d,%d" % [v, v], v])
	pair_rows.append(["A,A", 11])

	_draw_table(Vector2(20, TABLE_Y), "HARD", _chart["hard"], hard_rows)
	_draw_table(Vector2(222, TABLE_Y), "SOFT", _chart["soft"], soft_rows)
	_draw_table(Vector2(424, TABLE_Y), "PAIRS", _chart["pair"], pair_rows)

	# legend
	var y := 206
	var x := 22.0
	for item in [["H", "HIT"], ["S", "STAND"], ["P", "SPLIT"], ["D", "DOUBLE, ELSE HIT"], ["DS", "DOUBLE, ELSE STAND"]]:
		x = _legend(x, y, item[0], item[1]) + 12
	if rules.surrender:
		x = 22.0
		x = _legend(x, y + 13, "RH", "")
		x = _legend(x - 4, y + 13, "RS", "")
		x = _legend(x - 4, y + 13, "RP", "SURRENDER, ELSE HIT / STAND / SPLIT")

	# what the rules change
	var box := Rect2(20, 236, 600, 104)
	Art.box(self, box, Art.SLATE_D)
	var ty := box.position.y + 6
	PixelFont.draw(self, Vector2(box.position.x + 8, ty), "WHAT YOUR RULES CHANGE", Art.GOLD)
	ty += 13
	for s in _guide:
		if s["title"] != "WHAT YOUR RULES CHANGE":
			continue
		for line in s["lines"]:
			var wrapped := PixelFont.wrap(line, int(box.size.x) - 26)
			for wi in wrapped.size():
				if wi == 0:
					draw_rect(Rect2(box.position.x + 9, ty + 3, 2, 2), Art.GOLD)
				PixelFont.draw(self, Vector2(box.position.x + 16, ty), wrapped[wi], Art.CREAM)
				ty += 10
			ty += 2
	PixelFont.draw_right(self, box.end.x - 8, box.end.y - 12, "GUIDE TAB: EVERY RULE IN WORDS", Art.GREY_D)


func _legend(x: float, y: float, code: String, text: String) -> float:
	var cols := code_colors(code)
	var cw := maxf(16.0, PixelFont.measure(code) + 6.0)
	Art.box(self, Rect2(x, y, cw, 10), cols[0])
	PixelFont.draw_centered(self, x + cw / 2.0, y + 2, code, cols[1])
	if text.is_empty():
		return x + cw + 6
	return x + cw + 4 + PixelFont.draw(self, Vector2(x + cw + 4, y + 2), text, Art.CREAM)


func _draw_table(origin: Vector2, name: String, data: Dictionary, rows: Array) -> void:
	PixelFont.draw(self, origin, name, Art.GOLD)
	PixelFont.draw_centered(self, origin.x + LABEL_W + CELL_PITCH * 5, origin.y, "DEALER UP CARD", Art.GREY_D)
	var hy := origin.y + 11
	for c in 10:
		var cx := origin.x + LABEL_W + c * CELL_PITCH + 8
		PixelFont.draw_centered(self, cx, hy, Strategy.UP_LABELS[c], Art.WHITE)
	var y0 := hy + 11
	for ri in rows.size():
		var label: String = rows[ri][0]
		var key: int = rows[ri][1]
		var y := y0 + ri * ROW_PITCH
		PixelFont.draw_right(self, origin.x + LABEL_W - 5, y + 2, label, Art.WHITE)
		var row: Array = data[key]
		for c in 10:
			var code: String = row[c]
			var cols := code_colors(code)
			var r := Rect2(origin.x + LABEL_W + c * CELL_PITCH, y, CELL_PITCH - 1, ROW_PITCH - 1)
			draw_rect(r, cols[0])
			PixelFont.draw_centered(self, r.position.x + r.size.x / 2.0, y + 2, code, cols[1])


# ---------------------------------------------------------------- guide tab

func _draw_guide() -> void:
	var y := -_scroll
	for l in _guide_lines:
		var h := _line_h(l["kind"])
		if y + h >= 0 and y <= GUIDE_RECT.size.y:
			match l["kind"]:
				"title":
					PixelFont.draw(_guide_view, Vector2(0, y + 2), l["text"], Art.GOLD, 1, Art.INK)
					_guide_view.draw_rect(Rect2(0, y + 11, PixelFont.measure(l["text"]), 1), Art.GOLD_D)
				"first":
					_guide_view.draw_rect(Rect2(2, y + 3, 2, 2), Art.GOLD)
					PixelFont.draw(_guide_view, Vector2(10, y), l["text"], Art.CREAM)
				"cont":
					PixelFont.draw(_guide_view, Vector2(10, y), l["text"], Art.CREAM)
		y += h


func _draw_scrollbar() -> void:
	var total := _content_height()
	if total <= GUIDE_RECT.size.y:
		return
	var track := Rect2(GUIDE_RECT.end.x + 6, GUIDE_RECT.position.y, 4, GUIDE_RECT.size.y)
	draw_rect(track, Art.SLATE_D)
	var frac := GUIDE_RECT.size.y / total
	var th := maxf(12.0, track.size.y * frac)
	var ty := track.position.y + (track.size.y - th) * (_scroll / _max_scroll())
	draw_rect(Rect2(track.position.x, ty, 4, th), Art.GOLD)
