extends SceneTree
## Long basic-strategy simulation to sanity-check payouts against the known house edge.
## godot --headless --path . --script res://tests/sim.gd -- <seed> <rounds> <h17 0/1>
## Prints the player's average result per round in units of the initial bet.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_value := int(args[0]) if args.size() > 0 else 1
	var rounds := int(args[1]) if args.size() > 1 else 100000
	var r := Rules.new()
	r.h17 = args.size() > 2 and args[2] == "1"
	var e := BlackjackEngine.new(r, seed_value)
	e.bankroll = 1e12
	var bet := BlackjackEngine.MIN_BET
	var start := e.bankroll
	var sum_sq := 0.0
	for n in rounds:
		var before := e.bankroll
		if e.start_round(bet).is_empty():
			print("RESULT error: round did not start")
			quit(1)
			return
		while e.phase != BlackjackEngine.Phase.ROUND_OVER:
			if e.phase == BlackjackEngine.Phase.INSURANCE:
				e.insurance(false)
			else:
				e.act(e.best_play()["action"])
		var d := (e.bankroll - before) / bet
		sum_sq += d * d
	var mean := (e.bankroll - start) / bet / rounds
	var sd := sqrt(sum_sq / rounds - mean * mean)
	print("RESULT seed=%d rounds=%d h17=%s mean=%.6f sd=%.4f" % [seed_value, rounds, r.h17, mean, sd])
	quit()
