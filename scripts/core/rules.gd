class_name Rules
extends RefCounted
## Table rules. The adjustable ones change the basic strategy chart;
## the constants are fixed for this prototype.

const DECK_OPTIONS: Array[int] = [4, 6, 8]

const BLACKJACK_PAYS := 1.5 ## 3:2
const INSURANCE_PAYS := 2.0 ## 2:1
const MAX_HANDS := 4 ## split up to 4 hands
const PENETRATION := 0.75 ## reshuffle once 75% of the shoe is dealt

var decks: int = 6
var h17: bool = false ## true = dealer hits soft 17
var das: bool = true ## double after split allowed
var surrender: bool = true ## late surrender allowed


func copy() -> Rules:
	var r := Rules.new()
	r.decks = decks
	r.h17 = h17
	r.das = das
	r.surrender = surrender
	return r


func equals(other: Rules) -> bool:
	return other != null and decks == other.decks and h17 == other.h17 \
		and das == other.das and surrender == other.surrender


## Key that identifies which basic strategy chart applies (deck count 4-8 shares one chart).
func chart_key() -> String:
	return "%s-%s-%s" % [h17, das, surrender]


## Compact form for the sidebar, e.g. "6D S17 DAS LS".
func short_code() -> String:
	var parts: Array[String] = ["%dD" % decks, "H17" if h17 else "S17", "DAS" if das else "NO DAS"]
	parts.append("LS" if surrender else "NO LS")
	return " ".join(parts)


## Lines printed on the felt, like a real table.
func felt_lines() -> Array[String]:
	return [
		"BLACKJACK PAYS 3 TO 2",
		"DEALER HITS SOFT 17" if h17 else "DEALER STANDS ON ALL 17S",
		"INSURANCE PAYS 2 TO 1",
	]


## Full plain-language rule list for the guide.
func describe() -> Array[String]:
	var lines: Array[String] = []
	lines.append("%d DECKS, RESHUFFLED AFTER ABOUT %d%% OF THE SHOE IS DEALT." % [decks, int(PENETRATION * 100)])
	if h17:
		lines.append("DEALER HITS SOFT 17 (H17), E.G. DRAWS TO A,6.")
	else:
		lines.append("DEALER STANDS ON ALL 17S (S17), INCLUDING SOFT 17.")
	lines.append("DEALER PEEKS FOR BLACKJACK WITH AN ACE OR 10 UP.")
	lines.append("DOUBLE ON ANY FIRST TWO CARDS.")
	if das:
		lines.append("DOUBLE AFTER SPLIT (DAS): ALLOWED.")
	else:
		lines.append("DOUBLE AFTER SPLIT (DAS): NOT ALLOWED.")
	lines.append("SPLIT UP TO %d HANDS. SPLIT ACES GET ONE CARD EACH AND CAN'T BE RE-SPLIT." % MAX_HANDS)
	if surrender:
		lines.append("LATE SURRENDER: ALLOWED AS YOUR FIRST DECISION. YOU GET HALF YOUR BET BACK.")
	else:
		lines.append("LATE SURRENDER: NOT OFFERED.")
	lines.append("BLACKJACK PAYS 3:2. INSURANCE PAYS 2:1.")
	return lines
