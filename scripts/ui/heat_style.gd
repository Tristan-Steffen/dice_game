class_name HeatStyle
extends RefCounted
## Die EINE Quelle der Hitze-Anzeige: Stufennamen, Farbleiter, Wahl-Wörter, Ampel.
## Die Leiter läuft Graublau → Orange → Rot, Weißglut fast weiß - keine Stufe gleicht
## einer Wertungsfarbe (Basis cyan, Mult gold, Krit pink, Geld grün, Energie violett).

const NAMES := {1: "Kühl", 2: "Warm", 3: "Heiß", 4: "Glühend", 5: "Lodernd", 6: "Weißglut"}
const COLORS := {
	1: Color("#7d93ad"),
	2: Color("#c98a66"),
	3: Color("#ee6a22"),
	4: Color("#e5482a"),
	5: Color("#c8221a"),
	6: Color("#fff3e6"),
}
const PICK_WORDS := {GameRun.PICK_COOL: "kühler", GameRun.PICK_KEEP: "gleich", GameRun.PICK_HOT: "heißer"}
const TEXT_COLOR := Color("#e8ebf1")
const MUTED_COLOR := Color("#9aa3b3")
const BONUS_COLOR := Color("#50fa7b")
const MALUS_COLOR := Color("#ff6b6b")
const BOSS_COLOR := Color("#ff3b3b")
## Ampel des Rundenschnitts (GameRun.margin_of).
const MARGIN_COLORS := {GameRun.MARGIN_GOOD: Color("#6fdc8c"), GameRun.MARGIN_TIGHT: Color("#f2c94c"),
	GameRun.MARGIN_SHORT: Color("#ff5a4f")}

static func level_name(level: int) -> String:
	return String(NAMES.get(level, ""))

static func color(level: int) -> Color:
	return COLORS.get(clampi(level, GameRun.HEAT_MIN, GameRun.HEAT_WHITE), COLORS[1])

static func pick_word(pick: String) -> String:
	return String(PICK_WORDS.get(pick, ""))

static func margin_color(margin: String) -> Color:
	return MARGIN_COLORS.get(margin, TEXT_COLOR)

## Was die Wahl einer Karte mit der Hitze macht (route_view_state-Karte).
static func effect_text(card: Dictionary) -> String:
	if bool(card.get("boss", false)):
		return "Hitze ±0"
	var delta := int(card.get("heat_delta", 0))
	var text := ""
	if delta < 0:
		text = "Hitze −%d" % -delta
	elif delta > 0:
		text = "Hitze +%d" % delta
	else:
		text = "Hitze ±0"
	return text

## Fuß einer Karte: nur der Blind - die Ampelfarbe sagt, wie er zum Schnitt steht.
static func foot_text(card: Dictionary) -> String:
	return "Blind %s" % BigNumber.short(int(card.get("blind_after", 0)))
