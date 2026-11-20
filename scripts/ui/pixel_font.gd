class_name PixelFont
extends RefCounted
## A 5x7 bitmap font generated in code. Uppercase only (text is upper-cased when drawn).
## Glyphs are trimmed to their used columns for proportional spacing.

const GLYPH_H := 7
const LINE_H := 10 ## line height at scale 1, including spacing
const SPACING := 1
const SPACE_W := 3

const GLYPHS := {
	"A": "01110,10001,10001,11111,10001,10001,10001",
	"B": "11110,10001,10001,11110,10001,10001,11110",
	"C": "01110,10001,10000,10000,10000,10001,01110",
	"D": "11110,10001,10001,10001,10001,10001,11110",
	"E": "11111,10000,10000,11110,10000,10000,11111",
	"F": "11111,10000,10000,11110,10000,10000,10000",
	"G": "01110,10001,10000,10111,10001,10001,01111",
	"H": "10001,10001,10001,11111,10001,10001,10001",
	"I": "01110,00100,00100,00100,00100,00100,01110",
	"J": "00111,00010,00010,00010,00010,10010,01100",
	"K": "10001,10010,10100,11000,10100,10010,10001",
	"L": "10000,10000,10000,10000,10000,10000,11111",
	"M": "10001,11011,10101,10101,10001,10001,10001",
	"N": "10001,10001,11001,10101,10011,10001,10001",
	"O": "01110,10001,10001,10001,10001,10001,01110",
	"P": "11110,10001,10001,11110,10000,10000,10000",
	"Q": "01110,10001,10001,10001,10101,10010,01101",
	"R": "11110,10001,10001,11110,10100,10010,10001",
	"S": "01111,10000,10000,01110,00001,00001,11110",
	"T": "11111,00100,00100,00100,00100,00100,00100",
	"U": "10001,10001,10001,10001,10001,10001,01110",
	"V": "10001,10001,10001,10001,10001,01010,00100",
	"W": "10001,10001,10001,10101,10101,10101,01010",
	"X": "10001,10001,01010,00100,01010,10001,10001",
	"Y": "10001,10001,10001,01010,00100,00100,00100",
	"Z": "11111,00001,00010,00100,01000,10000,11111",
	"0": "01110,10001,10011,10101,11001,10001,01110",
	"1": "00100,01100,00100,00100,00100,00100,01110",
	"2": "01110,10001,00001,00010,00100,01000,11111",
	"3": "11111,00010,00100,00010,00001,10001,01110",
	"4": "00010,00110,01010,10010,11111,00010,00010",
	"5": "11111,10000,11110,00001,00001,10001,01110",
	"6": "00110,01000,10000,11110,10001,10001,01110",
	"7": "11111,00001,00010,00100,01000,01000,01000",
	"8": "01110,10001,10001,01110,10001,10001,01110",
	"9": "01110,10001,10001,01111,00001,00010,01100",
	".": "00000,00000,00000,00000,00000,01100,01100",
	",": "00000,00000,00000,00000,01100,00100,01000",
	":": "00000,01100,01100,00000,01100,01100,00000",
	";": "00000,01100,01100,00000,01100,00100,01000",
	"!": "00100,00100,00100,00100,00100,00000,00100",
	"?": "01110,10001,00001,00010,00100,00000,00100",
	"-": "00000,00000,00000,01110,00000,00000,00000",
	"+": "00000,00100,00100,11111,00100,00100,00000",
	"=": "00000,00000,11111,00000,11111,00000,00000",
	"/": "00001,00001,00010,00100,01000,10000,10000",
	"(": "00010,00100,01000,01000,01000,00100,00010",
	")": "01000,00100,00010,00010,00010,00100,01000",
	"%": "11000,11001,00010,00100,01000,10011,00011",
	"'": "00100,00100,01000,00000,00000,00000,00000",
	"\"": "01010,01010,00000,00000,00000,00000,00000",
	"#": "01010,01010,11111,01010,11111,01010,01010",
	"&": "01100,10010,10100,01000,10101,10010,01101",
	"*": "00000,00100,10101,01110,10101,00100,00000",
	"<": "00010,00100,01000,10000,01000,00100,00010",
	">": "01000,00100,00010,00001,00010,00100,01000",
	"_": "00000,00000,00000,00000,00000,00000,11111",
	"$": "00100,01111,10100,01110,00101,11110,00100",
	"[": "01110,01000,01000,01000,01000,01000,01110",
	"]": "01110,00010,00010,00010,00010,00010,01110",
	"|": "00100,00100,00100,00100,00100,00100,00100",
	"·": "00000,00000,00000,01100,01100,00000,00000",
}

static var _tex: ImageTexture
static var _src := {} ## char -> Rect2 in the atlas (trimmed)


static func _ensure() -> void:
	if _tex != null:
		return
	var keys := GLYPHS.keys()
	var img := Image.create(keys.size() * 6, GLYPH_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for gi in keys.size():
		var ch: String = keys[gi]
		var rows: PackedStringArray = GLYPHS[ch].split(",")
		var min_c := 5
		var max_c := -1
		for y in GLYPH_H:
			for x in 5:
				if rows[y][x] == "1":
					img.set_pixel(gi * 6 + x, y, Color.WHITE)
					min_c = mini(min_c, x)
					max_c = maxi(max_c, x)
		if max_c < 0:
			min_c = 0
			max_c = 0
		_src[ch] = Rect2(gi * 6 + min_c, 0, max_c - min_c + 1, GLYPH_H)
	_tex = ImageTexture.create_from_image(img)


## Raw bitmap rows for a glyph (used to bake text into card images).
static func glyph_rows(ch: String) -> PackedStringArray:
	return GLYPHS.get(ch, GLYPHS["?"]).split(",")


static func char_width(ch: String) -> int:
	_ensure()
	if ch == " ":
		return SPACE_W
	var r: Rect2 = _src.get(ch, _src["?"])
	return int(r.size.x)


## Width in base pixels.
static func measure(text: String, scale: int = 1) -> int:
	var t := text.to_upper()
	if t.is_empty():
		return 0
	var w := 0
	for i in t.length():
		w += char_width(t[i]) + SPACING
	return (w - SPACING) * scale


## Draws text with its top-left corner at pos. Returns the width drawn.
static func draw(ci: CanvasItem, pos: Vector2, text: String, color: Color, scale: int = 1, shadow: Color = Color(0, 0, 0, 0)) -> int:
	_ensure()
	var t := text.to_upper()
	if shadow.a > 0.0:
		_draw_run(ci, pos + Vector2(0, scale), t, shadow, scale)
	return _draw_run(ci, pos, t, color, scale)


static func _draw_run(ci: CanvasItem, pos: Vector2, t: String, color: Color, scale: int) -> int:
	var x := 0.0
	var px := Vector2(roundf(pos.x), roundf(pos.y))
	for i in t.length():
		var ch := t[i]
		if ch == " ":
			x += (SPACE_W + SPACING) * scale
			continue
		var src: Rect2 = _src.get(ch, _src["?"])
		ci.draw_texture_rect_region(_tex, Rect2(px.x + x, px.y, src.size.x * scale, GLYPH_H * scale), src, color)
		x += (src.size.x + SPACING) * scale
	return int(x) - SPACING * scale


## Draws text centred horizontally on cx.
static func draw_centered(ci: CanvasItem, cx: float, y: float, text: String, color: Color, scale: int = 1, shadow: Color = Color(0, 0, 0, 0)) -> void:
	draw(ci, Vector2(roundf(cx - measure(text, scale) / 2.0), y), text, color, scale, shadow)


static func draw_right(ci: CanvasItem, right_x: float, y: float, text: String, color: Color, scale: int = 1, shadow: Color = Color(0, 0, 0, 0)) -> void:
	draw(ci, Vector2(right_x - measure(text, scale), y), text, color, scale, shadow)


## Word-wraps text to max_width base pixels.
static func wrap(text: String, max_width: int, scale: int = 1) -> Array[String]:
	var lines: Array[String] = []
	var line := ""
	for word in text.split(" ", false):
		var trial := word if line.is_empty() else line + " " + word
		if measure(trial, scale) <= max_width or line.is_empty():
			line = trial
		else:
			lines.append(line)
			line = word
	if not line.is_empty():
		lines.append(line)
	return lines
