class_name StatsOverlay
extends Overlay
## Accuracy against basic strategy, by hand type, plus the spots missed most.

signal reset_requested

var stats: Stats
var _reset_btn: PixelButton


func _init(session_stats: Stats = null) -> void:
	super()
	stats = session_stats if session_stats else Stats.new()
	title = "ACCURACY STATS"


func _ready() -> void:
	super()
	_reset_btn = PixelButton.make("RESET STATS", Rect2(22, 322, 104, 20), Art.RED, Art.RED_D)
	_reset_btn.pressed.connect(func() -> void:
		reset_requested.emit()
		queue_redraw())
	add_child(_reset_btn)


static func pct_text(p: float) -> String:
	return "--" if p < 0.0 else "%d%%" % roundi(p)


static func pct_color(p: float) -> Color:
	if p < 0.0:
		return Art.GREY
	if p >= 95.0:
		return Art.GREEN
	if p >= 80.0:
		return Art.GOLD
	return Art.RED


func _draw_content() -> void:
	_draw_left()
	_draw_misses()


func _draw_left() -> void:
	var acc := stats.accuracy()
	PixelFont.draw(self, Vector2(22, 44), "OVERALL", Art.GREY)
	PixelFont.draw(self, Vector2(22, 56), pct_text(acc), pct_color(acc), 3, Art.INK)
	PixelFont.draw(self, Vector2(112, 58), "%d OF %d DECISIONS CORRECT" % [stats.correct, stats.decisions], Art.CREAM)
	PixelFont.draw(self, Vector2(112, 70), "STREAK %d · BEST %d" % [stats.streak, stats.best_streak], Art.CREAM)

	PixelFont.draw(self, Vector2(22, 92), "BY HAND TYPE", Art.GOLD)
	var y := 106
	for cat in Stats.CATEGORIES:
		var c: Array = stats.by_category[cat]
		var p := stats.category_accuracy(cat)
		PixelFont.draw(self, Vector2(22, y), Stats.CATEGORY_NAMES[cat], Art.WHITE)
		var bar := Rect2(98, y, 110, 8)
		Art.box(self, bar, Art.SLATE_D)
		if p >= 0.0:
			var fill := roundf((bar.size.x - 2) * p / 100.0)
			if fill > 0:
				draw_rect(Rect2(bar.position.x + 1, y + 1, fill, 6), pct_color(p))
		PixelFont.draw(self, Vector2(216, y), "%d/%d" % [c[0], c[1]], Art.CREAM)
		PixelFont.draw_right(self, 300, y, pct_text(p), pct_color(p))
		y += 14

	y += 8
	PixelFont.draw(self, Vector2(22, y), "SESSION", Art.GOLD)
	y += 14
	PixelFont.draw(self, Vector2(22, y), "ROUNDS PLAYED: %d" % stats.rounds, Art.CREAM)
	y += 11
	PixelFont.draw(self, Vector2(22, y), "HANDS WON %d · LOST %d · PUSHED %d" % [stats.hands_won, stats.hands_lost, stats.hands_pushed], Art.CREAM)
	y += 11
	PixelFont.draw(self, Vector2(22, y), "BLACKJACKS: %d" % stats.blackjacks, Art.CREAM)
	y += 11
	var net_col := Art.GREEN if stats.net > 0.0 else (Art.RED if stats.net < 0.0 else Art.CREAM)
	var x := 22 + PixelFont.draw(self, Vector2(22, y), "NET: ", Art.CREAM)
	PixelFont.draw(self, Vector2(x + 4, y), Art.signed_money(stats.net), net_col)
	y += 18
	var tip := "EVERY HIT, STAND, DOUBLE, SPLIT, SURRENDER AND INSURANCE ANSWER IS CHECKED AGAINST THE CHART FOR YOUR TABLE RULES."
	for line in PixelFont.wrap(tip, 278):
		PixelFont.draw(self, Vector2(22, y), line, Art.GREY_D)
		y += 10


func _draw_misses() -> void:
	var x := 318.0
	var right := 618.0
	draw_rect(Rect2(x - 8, 44, 1, 296), Art.SLATE_L)
	PixelFont.draw(self, Vector2(x, 44), "MOST MISSED", Art.GOLD)
	var y := 58.0
	if stats.decisions == 0:
		PixelFont.draw(self, Vector2(x, y), "PLAY A FEW HANDS FIRST.", Art.GREY)
		return
	var list := stats.top_misses(6)
	if list.is_empty():
		PixelFont.draw(self, Vector2(x, y), "NO MISSES YET. PERFECT PLAY!", Art.GREEN)
		return
	for m in list:
		var rule_lines := PixelFont.wrap(m["rule"], int(right - x - 6))
		var h := 22.0 + rule_lines.size() * 10.0 + 6.0
		if y + h > 344.0:
			break
		Art.box(self, Rect2(x - 3, y - 3, right - x + 6, h - 2), Art.SLATE_D)
		PixelFont.draw(self, Vector2(x, y), m["label"], Art.WHITE)
		PixelFont.draw_right(self, right, y, "MISSED X%d" % m["misses"], Art.RED)
		y += 11
		var play: String = "PLAY: " + Strategy.ACTION_NAMES[m["best"]]
		if m["note"] != "":
			play += " (" + m["note"] + ")"
		var px := x + PixelFont.draw(self, Vector2(x, y), play, Art.GREEN)
		PixelFont.draw(self, Vector2(px + 10, y), "YOU: " + Strategy.ACTION_NAMES[m["last_taken"]], Art.RED_L)
		y += 11
		for line in rule_lines:
			PixelFont.draw(self, Vector2(x, y), line, Art.GREY)
			y += 10
		y += 6
