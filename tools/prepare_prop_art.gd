extends SceneTree
## Deterministic engine normalization of the imagegen draft, not sprite generation.
const PALETTES := {
	"banana": [Color("241c27"), Color("69483f"), Color("ac702b"), Color("e8ad36"), Color("f5cd5b"), Color("ffe5ae")],
	"spring": [Color("241c27"), Color("69483f"), Color("493334"), Color("ab7950"), Color("dfb269"), Color("ffe5ae"), Color("607e86"), Color("9ac4c5")],
}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or not PALETTES.has(args[0]):
		push_error("Pass banana|spring and the generated source PNG after --")
		quit(1)
		return
	var kind := args[0]
	var palette: Array = PALETTES[kind]
	var draft := Image.load_from_file(args[1])
	if draft == null:
		quit(1)
		return
	# Remove faint edge noise before cropping the transparent generated draft.
	for y in draft.get_height():
		for x in draft.get_width():
			if draft.get_pixel(x, y).a < 0.5:
				draft.set_pixel(x, y, Color.TRANSPARENT)
	var sprite := draft.get_region(draft.get_used_rect())
	var dimensions := Vector2i(32, 24) if kind == "banana" else Vector2i(24, 28)
	var inset := Vector2i(0, 2) if kind == "banana" else Vector2i(1, 2)
	sprite.resize(dimensions.x - inset.x * 2, dimensions.y - inset.y * 2, Image.INTERPOLATE_NEAREST)
	var result := Image.create(dimensions.x, dimensions.y, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	for y in sprite.get_height():
		for x in sprite.get_width():
			var pixel := sprite.get_pixel(x, y)
			if pixel.a < 0.5:
				continue
			var best: Color = palette[0]
			var distance := INF
			for swatch: Color in palette:
				var delta := Vector3(pixel.r - swatch.r, pixel.g - swatch.g, pixel.b - swatch.b).length_squared()
				if delta < distance:
					distance = delta
					best = swatch
			result.set_pixel(x + inset.x, y + inset.y, best)
	var error := result.save_png("res://assets/props/" + kind + ".png")
	print("%s: %s RGBA, %d-color palette, binary alpha. Save result: %d" % [kind, dimensions, palette.size(), error])
	quit(error)
