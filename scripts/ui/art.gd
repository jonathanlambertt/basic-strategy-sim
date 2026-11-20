class_name Art
extends RefCounted
## Palette, procedurally generated pixel textures (cards, chips) and box-drawing helpers.

const INK := Color("1b1c26")
const CREAM := Color("f4efe1")
const CREAM_D := Color("d6ccb6")
const WHITE := Color("fbf6e9")
const RED := Color("e04a3f")
const RED_D := Color("9e2f2b")
const RED_L := Color("f2b3a6")
const SUIT_BLACK := Color("2b2d3c")
const GOLD := Color("f3b643")
const GOLD_D := Color("b9791f")
const GOLD_L := Color("f8dc9a")
const BLUE := Color("3e7bd6")
const BLUE_D := Color("27508f")
const BLUE_L := Color("a9c6f0")
const GREEN := Color("49ad6b")
const GREEN_D := Color("2c7346")
const PURPLE := Color("8a5ac8")
const PURPLE_D := Color("5a3889")
const ORANGE := Color("ec8b3c")
const ORANGE_D := Color("a85a20")
const SLATE := Color("2a3140")
const SLATE_D := Color("1d222d")
const SLATE_L := Color("3d475c")
const GREY := Color("8a92a3")
const GREY_D := Color("5b6273")
const FELT := Color("2f6a4f")
const FELT_D := Color("1f4a37")
const FELT_L := Color("4b8f6c")
const SHADOW := Color(0, 0, 0, 0.35)

const CARD_W := 41
const CARD_H := 57

const SUIT_BIG := [
	# spade
	["...#...", "..###..", ".#####.", "#######", "##.#.##", "...#...", "..###.."],
	# heart
	[".##.##.", "#######", "#######", "#######", ".#####.", "..###..", "...#..."],
	# club
	["..###..", "..###..", "##.#.##", "#######", "##.#.##", "...#...", "..###.."],
	# diamond
	["...#...", "..###..", ".#####.", "#######", ".#####.", "..###..", "...#..."],
]
const SUIT_SMALL := [
	["..#..", ".###.", "#####", "#.#.#", "..#.."],
	["##.##", "#####", "#####", ".###.", "..#.."],
	[".###.", ".###.", "#####", "#.#.#", "..#.."],
	["..#..", ".###.", "#####", ".###.", "..#.."],
]

## Pip centres for 2-10 on a 41x57 card (x, y). Pips below the middle are drawn upside down.
const PIPS := {
	2: [[20, 12], [20, 44]],
	3: [[20, 12], [20, 28], [20, 44]],
	4: [[13, 12], [27, 12], [13, 44], [27, 44]],
	5: [[13, 12], [27, 12], [20, 28], [13, 44], [27, 44]],
	6: [[13, 12], [27, 12], [13, 28], [27, 28], [13, 44], [27, 44]],
	7: [[13, 12], [27, 12], [20, 20], [13, 28], [27, 28], [13, 44], [27, 44]],
	8: [[13, 12], [27, 12], [20, 20], [13, 28], [27, 28], [20, 36], [13, 44], [27, 44]],
	9: [[13, 12], [27, 12], [13, 23], [27, 23], [20, 28], [13, 33], [27, 33], [13, 44], [27, 44]],
	10: [[13, 12], [27, 12], [20, 17], [13, 23], [27, 23], [13, 33], [27, 33], [20, 39], [13, 44], [27, 44]],
}

static var _cards := {}
static var _back: ImageTexture
static var _chips := {}


static func suit_color(card: int) -> Color:
	return RED if Hand.is_red(card) else SUIT_BLACK


# ---------------------------------------------------------------- cards

static func card_texture(card: int) -> ImageTexture:
	if not _cards.has(card):
		_cards[card] = ImageTexture.create_from_image(_card_image(card))
	return _cards[card]


static func card_back() -> ImageTexture:
	if _back == null:
		_back = ImageTexture.create_from_image(_back_image())
	return _back


static func _in_shape(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= CARD_W or y >= CARD_H:
		return false
	var cx := mini(x, CARD_W - 1 - x)
	var cy := mini(y, CARD_H - 1 - y)
	return cx + cy >= 2 # cut 2px corners


static func _card_base(fill: Color) -> Image:
	var img := Image.create(CARD_W, CARD_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in CARD_H:
		for x in CARD_W:
			if not _in_shape(x, y):
				continue
			var edge := not (_in_shape(x - 1, y) and _in_shape(x + 1, y) and _in_shape(x, y - 1) and _in_shape(x, y + 1))
			img.set_pixel(x, y, INK if edge else fill)
	return img


static func _blit(img: Image, rows: Array, x0: int, y0: int, color: Color, scale: int = 1, flip: bool = false) -> void:
	var h := rows.size()
	var w: int = rows[0].length()
	for y in h:
		for x in w:
			if rows[y][x] != "#" and rows[y][x] != "1":
				continue
			var px := x
			var py := y
			if flip:
				px = w - 1 - x
				py = h - 1 - y
			img.fill_rect(Rect2i(x0 + px * scale, y0 + py * scale, scale, scale), color)


## Glyph rows trimmed to used columns.
static func _glyph(ch: String) -> Array:
	var rows := PixelFont.glyph_rows(ch)
	var min_c := 5
	var max_c := 0
	for r in rows:
		for x in r.length():
			if r[x] == "1":
				min_c = mini(min_c, x)
				max_c = maxi(max_c, x)
	var out := []
	for r in rows:
		out.append(r.substr(min_c, max_c - min_c + 1))
	return out


## Rank string as one bitmap (glyphs joined with 1px spacing).
static func _rank_rows(card: int) -> Array:
	var name := Hand.rank_name(card)
	var rows := ["", "", "", "", "", "", ""]
	for i in name.length():
		var g := _glyph(name[i])
		for y in 7:
			rows[y] += ("." if i > 0 else "") + g[y]
	return rows


static func _card_image(card: int) -> Image:
	var img := _card_base(CREAM)
	# soft top highlight and bottom shade
	for x in range(2, CARD_W - 2):
		img.set_pixel(x, 1, WHITE)
		img.set_pixel(x, CARD_H - 2, CREAM_D)
	var suit := Hand.suit_of(card)
	var rank := Hand.rank_of(card)
	var col := suit_color(card)
	var dark := RED_D if Hand.is_red(card) else INK

	# corner indices
	var rank_rows := _rank_rows(card)
	var rw: int = rank_rows[0].length()
	_blit(img, rank_rows, 3, 3, col)
	var sx := 3 + int((rw - 5) / 2.0) if rw > 5 else 3
	_blit(img, SUIT_SMALL[suit], sx, 12, col)
	_blit(img, rank_rows, CARD_W - 3 - rw, CARD_H - 10, col, 1, true)
	_blit(img, SUIT_SMALL[suit], CARD_W - sx - 5, CARD_H - 17, col, 1, true)

	if rank == 1:
		_blit(img, SUIT_BIG[suit], 10, 18, col, 3)
	elif rank >= 11:
		var tint: Color = [BLUE_L, RED_L, GOLD_L][rank - 11]
		var fx := 9
		var fy := 9
		var fw := 23
		var fh := 39
		img.fill_rect(Rect2i(fx, fy, fw, fh), INK)
		img.fill_rect(Rect2i(fx + 1, fy + 1, fw - 2, fh - 2), tint)
		# little crown / band along the top of the frame
		for x in range(fx + 2, fx + fw - 2):
			if x % 2 == 0:
				img.set_pixel(x, fy + 2, dark)
		var letter := _glyph(Hand.rank_name(card))
		_blit(img, letter, 20 - int(letter[0].length() * 3 / 2.0), fy + 6, dark, 3)
		_blit(img, SUIT_BIG[suit], 17, fy + 28, col)
		for x in range(fx + 2, fx + fw - 2):
			if x % 2 == 0:
				img.set_pixel(x, fy + fh - 3, dark)
	else:
		for p in PIPS[rank]:
			_blit(img, SUIT_BIG[suit], p[0] - 3, p[1] - 3, col, 1, p[1] > 28)
	return img


static func _back_image() -> Image:
	var img := _card_base(BLUE)
	for y in range(3, CARD_H - 3):
		for x in range(3, CARD_W - 3):
			var border := x == 3 or y == 3 or x == CARD_W - 4 or y == CARD_H - 4
			if border:
				img.set_pixel(x, y, CREAM)
			elif x > 4 and y > 4 and x < CARD_W - 5 and y < CARD_H - 5:
				var lattice := (x + y) % 6 == 0 or (x - y + 60) % 6 == 0
				img.set_pixel(x, y, BLUE_L if lattice else BLUE_D)
	# centre emblem
	var cx := 20
	var cy := 28
	for dy in range(-5, 6):
		for dx in range(-5, 6):
			var d := absi(dx) + absi(dy)
			if d <= 5:
				img.set_pixel(cx + dx, cy + dy, INK if d == 5 else (GOLD if d <= 3 else GOLD_D))
	_blit(img, SUIT_SMALL[0], cx - 2, cy - 2, INK)
	return img


# ---------------------------------------------------------------- chips

const CHIP_COLORS := {5: [RED, RED_D], 25: [GREEN, GREEN_D], 100: [SUIT_BLACK, INK], 500: [PURPLE, PURPLE_D]}


static func chip_texture(value: int, size: int) -> ImageTexture:
	var key := "%d-%d" % [value, size]
	if not _chips.has(key):
		var cols: Array = CHIP_COLORS[value]
		_chips[key] = ImageTexture.create_from_image(_chip_image(size, cols[0], cols[1]))
	return _chips[key]


static func _chip_image(d: int, base: Color, dark: Color) -> Image:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := (d - 1) / 2.0
	var R := d / 2.0 - 0.5
	var rim := maxf(2.0, d / 8.0)
	for y in d:
		for x in d:
			var v := Vector2(x - c, y - c)
			var dist := v.length()
			var col: Color
			if dist > R + 0.5:
				continue
			elif dist > R - 0.5:
				col = INK
			elif dist > R - 0.5 - rim:
				var a := atan2(v.y, v.x) + PI
				var sector := int(floor(a / (TAU / 12.0)))
				col = WHITE if sector % 2 == 0 else base
			elif dist > R - 1.5 - rim:
				col = dark
			else:
				col = base.lightened(0.12)
			if y > c + R * 0.55 and col != INK and col != WHITE:
				col = col.darkened(0.15)
			img.set_pixel(x, y, col)
	return img


## Splits an amount into chip values, largest first.
static func chip_breakdown(amount: float) -> Array[int]:
	var out: Array[int] = []
	var left := int(floor(amount + 0.001))
	for v in [500, 100, 25, 5]:
		while left >= v:
			out.append(v)
			left -= v
	if left > 0 and out.is_empty():
		out.append(5)
	return out


# ---------------------------------------------------------------- drawing helpers

## Box with 1px cut corners.
static func box(ci: CanvasItem, r: Rect2, fill: Color) -> void:
	ci.draw_rect(Rect2(r.position.x + 1, r.position.y, r.size.x - 2, r.size.y), fill)
	ci.draw_rect(Rect2(r.position.x, r.position.y + 1, r.size.x, r.size.y - 2), fill)


## Outlined box with a drop shadow, used for panels and badges.
static func panel(ci: CanvasItem, r: Rect2, fill: Color, outline: Color = INK, shadow: bool = true) -> void:
	if shadow:
		box(ci, Rect2(r.position + Vector2(0, 2), r.size), SHADOW)
	box(ci, r, outline)
	box(ci, r.grow(-1), fill)


static func money(v: float) -> String:
	var neg := v < 0.0
	var a := absf(v)
	var whole := int(floor(a + 0.0001))
	var half := a - whole > 0.25
	var s := str(whole)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	out = s + out
	if half:
		out += ".5"
	return ("-" if neg else "") + "$" + out


static func signed_money(v: float) -> String:
	if v > 0.0:
		return "+" + money(v)
	return money(v)
