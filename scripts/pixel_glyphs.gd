extends RefCounted
## Shared pixel pictograms and integer-scaled prop sprites. No emoji/font glyphs.

const PixelSkin := preload("res://scripts/pixel_skin.gd")
const BANANA := preload("res://assets/props/banana.png")
const SPRING := preload("res://assets/props/spring.png")
const GLYPHS := {
	"heart": ["............", ".oooo..oooo.", "oxhhxooxhhxo", "oxxxxxxxxxxo", "oxxxxxxxxxxo", ".oxxxxxxxxo.", "..oxxxxxxo..", "...oxxxxo...", "....oxxo....", ".....oo.....", "............", "............"],
	"emptyheart": ["............", ".oooo..oooo.", "ox..xoo...xo", "ox........xo", "ox........xo", ".ox......xo.", "..ox....xo..", "...ox..xo...", "....oxxo....", ".....oo.....", "............", "............"],
	"boss": ["..oo....oo..", ".oxxo..oxxo.", "..oxxxxxxo..", ".oxxxxxxxxo.", "oxxhhhhhxxxo", "oxxooxxooxxo", "oxxooxxooxxo", ".oxxxxxxxxo.", "..oxoxoxo...", "..oxxxxxo...", "...ooooo....", "............"],
	"clock": ["....oooo....", "....obbo....", "....oooo....", "..oobbbboo..", ".obhhhhhhbo.", "obhhhohhhhbo", "obhhhohhhhbo", "obhhhoohhhbo", "obhhhhhhhhbo", ".obhhhhhhbo.", "..oobbbboo..", "....oooo...."],
	"shield": [".....oo.....", ".ooooxxoooo.", "oxxxxxxxxxxo", "oxxxhhhhxxxo", "oxxxxhhxxxxo", "oxhhhhhhhhxo", "oxxxxhhxxxxo", ".oxxxhhxxxo.", "..oxxxxxxo..", "...oxxxxo...", "....oxxo....", ".....oo....."],
	"lock": ["....oooo....", "...oxxxxo...", "..oxxooxxo..", "..oxo..oxo..", "..oxo..oxo..", ".oooooooooo.", ".obhhhhhhbo.", ".obbbxxbbbo.", ".obbbxxbbbo.", ".obbbbbbbbo.", ".oooooooooo.", "............"],
	"play": ["...oo.......", "...oxoo.....", "...oxxxoo...", "...oxxxxxoo.", "...oxhhxxxo.", "...oxhhhhxxo", "...oxhhxxxo.", "...oxxxxxoo.", "...oxxxoo...", "...oxoo.....", "...oo.......", "............"],
	"pause": ["............", "..ooo..ooo..", "..oxo..oxo..", "..oxo..oxo..", "..oxo..oxo..", "..oxo..oxo..", "..oxo..oxo..", "..oxo..oxo..", "..oxo..oxo..", "..ooo..ooo..", "............", "............"],
	"left": ["............", ".....oo.....", "....oxo.....", "...oxxo.....", "..oxxxooooo.", ".oxxxxxxxxo.", "oxhhhhhhhxo.", ".oxxxxxxxxo.", "..oxxxooooo.", "...oxxo.....", "....oxo.....", ".....oo....."],
	"right": ["............", ".....oo.....", ".....oxo....", ".....oxxo...", ".oooooxxxo..", ".oxxxxxxxxo.", ".oxhhhhhhhxo", ".oxxxxxxxxo.", ".oooooxxxo..", ".....oxxo...", ".....oxo....", ".....oo....."],
	"charge": ["......ooo...", ".....oyyo...", "....oyyo....", "...oyyo.....", "..oyhyoooo..", ".oyhhhhhyyo.", ".ooooyhyyo..", "....oyhyo...", "...oyyyo....", "...oyyo.....", "...oyo......", "...oo......."],
	"shot": ["............", ".......o....", ".......oxo..", "..oo....oxo.", ".oxxoooooxxo", ".oxhhhhhhhxo", ".oxxoooooxxo", "..oo....oxo.", ".......oxo..", ".......o....", "............", "............"],
	"check": ["............", ".........oo.", "........oxxo", ".......oxxo.", ".oo...oxxo..", "oxxo.oxxo...", ".oxxoxxo....", "..oxxxo.....", "...oxo......", "....o.......", "............", "............"],
	"miss": ["............", ".oo......oo.", "oxxo....oxxo", ".oxxo..oxxo.", "..oxxooxxo..", "...oxxxxo...", "...oxxxxo...", "..oxxooxxo..", ".oxxo..oxxo.", "oxxo....oxxo", ".oo......oo.", "............"],
	"book": ["............", ".oooo..oooo.", "obhhyoohyhbo", "obhhhyyhhhbo", "obhbbyybbhbo", "obhhhyyhhhbo", "obhbbyybbhbo", "obhhhyyhhhbo", "obhhhyyhhhbo", ".ooooyyoooo.", ".....oo.....", "............"],
	"flask": ["...oooooo...", "...obbbbo...", "....oxxo....", "....oxxo....", "...oxxxxo...", "..oxxxxxxo..", ".oxxhxxxxxo.", "oxggggggggxo", "oxgghgggggxo", "oxggggghggxo", ".oxxxxxxxxo.", "..oooooooo.."],
	"levels": ["............", "..ooo..ooo..", ".ohhyooyhho.", ".ohhyooyhho.", "..oooxxooo..", ".....xx.....", ".....xx.....", "..oooxxooo..", ".ohhyooyhho.", ".ohhyooyhho.", "..ooo..ooo..", "............"],
	"cup": [".oooooooooo.", "obbhhhhhhbbo", "obobbbbbbobo", "obobbbbbbobo", ".obbbbbbbbo.", "..obbbbbbo..", "...obbbbo...", "....obbo....", "....obbo....", "..oobbbboo..", ".obhhhhhhbo.", ".oooooooooo."],
	"spikes": ["............", "..o...o...o.", ".oxo.oxo.oxo", ".oxo.oxo.oxo", "oxxxoxxxoxxx", "oxhxoxhxoxhx", "oxhxoxhxoxhx", "oxhxoxhxoxhx", "oooooooooooo", "............", "............", "............"],
	"slip": ["......ooo...", ".....oxhxo..", "......ooo...", ".......xo...", "....oooxo...", "...oxxxo....", "..oxxxo.....", ".oxxoxxo....", "oxxo.oxxo...", ".oo...oxxoo.", ".......oooo.", "............"],
	"mouse": ["....oooo....", "...oxxxxo...", "..oxxooxxo..", "..oxxooxxo..", "..oxxooxxo..", "..oxxxxxxo..", "..oxxxxxxo..", "..oxxxxxxo..", "..oxxxxxxo..", "...oxxxxo...", "....oooo....", "............"],
	"sandbag": ["...oooooo...", "...obbbbo...", "....obbo....", "...obbbbo...", "..obbbbbbo..", ".obhbbbbbbo.", "obhbbbbbbbbo", "obbbbbbbbbbo", "obbbbbbbbbbo", ".obbbbbbbbo.", "..oooooooo..", "............"],
	"magnet": [".oooo..oooo.", "oxhxo..oxhxo", "oxhxo..oxhxo", "occco..occco", "occco..occco", "occco..occco", "occcooooccco", ".occcccccco.", "..occcccco..", "...oooooo...", "............", "............"],
	"retry": [".....oooo...", "...ooxxxxoo.", "..oxxooooxxo", ".oxxo....oxo", "oxxxxo...oxo", "oooooo...oxo", ".........oxo", "..oo....oxxo", "..oxooooxxo.", "...oxxxxxo..", "....ooooo...", "............"],
	"or": ["............", "........oo..", ".......oxo..", "......oxo...", ".....oxo....", "....oxo.....", "...oxo......", "..oxo.......", "..oo........", "............", "............", "............"],
}
static var _textures: Dictionary = {}


static func paint(canvas: CanvasItem, kind: String, center: Vector2, span: float, ink: Color) -> bool:
	if kind in ["banana", "spring"]:
		var texture: Texture2D = BANANA if kind == "banana" else SPRING
		var extent := texture.get_size() * maxf(1, floorf(span / maxf(texture.get_width(), texture.get_height())))
		# Natural palettes, shared by the toolbar, help, preview and deployed props.
		canvas.draw_texture_rect(texture, Rect2((center - extent * 0.5).round(), extent), false, Color(1, 1, 1, ink.a))
		return true
	var key := {"back": "left", "exit": "left", "rush": "right", "strike": "charge", "diamond": "shield"}.get(kind, kind) as String
	if not GLYPHS.has(key):
		return false
	if not _textures.has(key):
		var rows: Array = GLYPHS[key]
		var image := Image.create(12, 12, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		var palette := {"o": PixelSkin.OUTLINE, "x": Color.WHITE, "h": PixelSkin.PAPER, "b": PixelSkin.BRASS, "y": PixelSkin.GOLD, "g": PixelSkin.HERO, "c": Color("9ac4c5")}
		for y in mini(rows.size(), 12):
			for x in mini(rows[y].length(), 12):
				var pixel := str(rows[y][x])
				if palette.has(pixel):
					image.set_pixel(x, y, palette[pixel])
		_textures[key] = ImageTexture.create_from_image(image)
	var extent := maxf(12, floorf(span / 12) * 12)
	canvas.draw_texture_rect(_textures[key], Rect2((center - Vector2.ONE * extent * 0.5).round(), Vector2.ONE * extent), false, ink)
	return true
