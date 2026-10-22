extends Reference

const DEFAULTS = {
	"triangle": Color(0.2, 0.65, 1.0),
	"circle": Color(0.2, 0.65, 1.0),
	"square": Color(0.2, 0.65, 1.0),
	"axis": Color.white,
	"swing": Color(0.4, 1.0, 0.5),
	"locked_swing": Color.red,
	"open_swing": Color.white,
	"offset": Color.red,
	"hinge": Color.red,
	"pivot": Color(1.0, 0.55, 0.15),
	"selection": Color(0.15, 0.6, 1.0),
	"door": Color(1.0, 0.85, 0.25),
	"secret": Color.red,
	"window": Color.white
}
const LABELS = {
	"triangle": "Triangle color", "circle": "Circle color", "square": "Square color",
	"axis": "Door axis line color", "swing": "Swing graphics color", "offset": "Hinge offset line color",
	"locked_swing": "Locked door preview color",
	"open_swing": "Open door preview color",
	"hinge": "Hinge marker color", "pivot": "Central pivot color", "selection": "Selected door highlight color",
	"door": "Door outline color", "secret": "Secret door outline color", "window": "Window outline color"
}

static func palette(preferences):
	var result = DEFAULTS.duplicate()
	if preferences != null:
		for key in result:
			var value = preferences.get("color_" + key)
			if value is Color:
				result[key] = value
	return result
