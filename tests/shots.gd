extends SceneTree
## Drives the real game and saves screenshots (run windowed, not headless):
## godot --path . --script res://tests/shots.gd -- <output dir>

const A := 0
const C5 := 4
const C6 := 5
const C7 := 6
const C8 := 7
const C9 := 8
const C10 := 9
const K := 12
const HEARTS := 13
const CLUBS := 26
const DIAMONDS := 39

var game: Control
var out_dir := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else OS.get_user_data_dir()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	_run()


func _run() -> void:
	await _sleep(0.6)
	await shot("01_start")

	# Pair of 8s vs dealer 6: split, double the first hand, stand the second.
	game.engine.shoe.rigged.assign([C8, C6 + HEARTS, C8 + DIAMONDS, C10 + CLUBS, 2 + HEARTS, K, C9 + CLUBS, C10 + DIAMONDS])
	game._on_deal()
	await _sleep(2.4)
	await shot("02_pair_of_eights")
	game._on_action("split")
	await _sleep(1.4)
	await shot("03_split")
	game._on_action("double")
	await _sleep(1.6)
	game._on_action("stand")
	await _sleep(2.6)
	await shot("04_settled")

	# Dealer ace: insurance offer.
	game.engine.shoe.rigged.assign([K + HEARTS, A + CLUBS, C7 + DIAMONDS, C6])
	game._on_deal()
	await _sleep(2.4)
	await shot("05_insurance")
	game._on_insurance(false)
	await _sleep(2.0)
	await shot("06_after_insurance")
	game._on_action("stand")
	await _sleep(2.4)

	game._open_overlay("chart")
	await _sleep(0.4)
	await shot("07_chart")
	game.overlay.set_tab("guide")
	await _sleep(0.3)
	await shot("08_guide")
	game.overlay._scroll_by(250)
	await _sleep(0.2)
	await shot("09_guide_scrolled")
	game._close_overlay()

	game._open_overlay("stats")
	await _sleep(0.4)
	await shot("10_stats")
	game._close_overlay()

	game._open_overlay("rules")
	await _sleep(0.4)
	await shot("11_rules")
	game.overlay._choose("h17", true)
	game.overlay._choose("das", false)
	await _sleep(0.2)
	await shot("12_rules_changed")
	game._close_overlay()

	game._open_overlay("chart")
	await _sleep(0.4)
	await shot("13_chart_h17_nodas")
	game._close_overlay()

	# Blackjack.
	game.engine.shoe.rigged.assign([A + HEARTS, C9, K + DIAMONDS, C7 + CLUBS])
	game._on_deal()
	await _sleep(3.0)
	await shot("14_blackjack")
	quit()


func _sleep(t: float) -> void:
	await create_timer(t).timeout


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved ", name)
