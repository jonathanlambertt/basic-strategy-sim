# Project notes

## House-edge simulation (payout sanity check)

`tests/sim.gd` auto-plays rounds with perfect basic strategy (always declines insurance)
and prints the player's average result per round, in units of the initial bet. If the
result is far from the published house edge for the same rules, a payout or rule bug is
likely.

Run one batch (headless, ~1-2 min for 600k rounds):

```
Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/sim.gd -- <seed> <rounds> <h17 0|1>
```

Run several seeds in parallel and average them; standard deviation per round is ~1.14
bets, so the standard error is 1.14 / sqrt(total rounds).

### Results (2026-11-20), 6 decks, DAS, late surrender, no resplit aces, peek, 3:2

| Rules | Seeds | Rounds | Player result per round |
|---|---|---|---|
| S17 | 101, 202, 303, 404 | 2.4M | -0.52% ± 0.07% |
| S17 | 1111 ... 8888 | 4.8M | -0.35% ± 0.05% |
| **S17, all runs** | 12 seeds | **7.2M** | **-0.41% ± 0.04%** |
| H17 | 101, 202, 303, 404 | 2.4M | -0.71% ± 0.07% |

Published figures: about 0.44% house edge for 6-deck S17 DAS without surrender, and
late surrender is worth about 0.08%, so roughly 0.36-0.40% for these S17 rules. Dealer
hitting soft 17 adds about 0.22%.

**Status: resolved, no bug found.** The first S17 batch read ~0.15% worse than expected
(about 2 standard errors). A second batch with fresh shuffles landed on the published
value, so the first batch was bad luck. The H17 batch used the same seeds as that first
S17 batch, so it shares the same luck. If you want extra confidence, rerun H17 with new
seeds; expect about -0.58% to -0.62%.

Sources:
- https://bodhi-root.github.io/gambling-stats-bookdown/blackjack.html
- https://www.lasvegasadvisor.com/blog/the-house-edge-at-blackjack/
- https://www.deucescracked.com/casino/blackjack/blackjack-odds-calculator

Gotcha: the simulator must bet at least the $5 table minimum. An earlier version bet $1;
the engine refused the bet, the script errored without quitting, and the processes hung.
The script now quits with an error if a round fails to start.
