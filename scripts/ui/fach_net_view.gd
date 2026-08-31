class_name FachNetView
extends Control
## Die INFO-SÄULE des Ausgabefachs: über ihr LIEGT der eine offene Neuzugang als
## Körper, hier steht von oben nach unten, was er ist und tut - sein NAME, seine
## SEELEN-ZEILE im eigenen Glühen der Essenz, deren WIRKUNG - und darunter sein
## Würfelnetz. Das ist die ganze Auskunft eines Neuzugangs; ein Dossier braucht er
## dafür nicht mehr.
## Ohne Zeiger und ohne Rahmen: sie steht, wann immer das Fach etwas trägt, und ist
## sonst gar nicht da (die Laden-Grammatik).
## Sie MELDET nichts und faßt nichts an - scene_root reicht ihr den Würfel herein
## und schneidet ihr Rechteck unter der Schale zu (das apron_bottom-Muster).

## Rand ringsum, in u (= Fensterbreite / UNIT_DIV).
const UNIT_DIV := 100.0
const MARGIN_UNITS := 4.0
## Die drei Zeilen der Erklärung und die Fuge zwischen den Blöcken, in u.
const NAME_UNITS := 12.0
const SOUL_UNITS := 10.0
const EFFECT_UNITS := 26.0
const GAP_UNITS := 3.0
## Die Fuge VOR dem Netz ist großzügiger: Wirkung und Netz stießen sonst aneinander.
const NET_GAP_UNITS := 6.0
## Schriftgrad je Zeile, als Anteil ihrer eigenen Höhe.
const NAME_FONT_SHARE := 0.62
const SOUL_FONT_SHARE := 0.62
## Der Wirkungstext läuft um: sein Grad ist ein Anteil EINER Zeile des Bandes.
const EFFECT_LINES := 3
const EFFECT_FONT_SHARE := 0.74

## Die Höhe, die die Säule bei dieser BREITE braucht: Rand, die drei Zeilen samt
## Fugen und das Netz, das die Breite hergibt. scene_root schneidet ihr Rechteck
## daraus, statt eine Zahl zu tippen.
static func height_for(width: float) -> float:
	var u := width / UNIT_DIV
	var inner := maxf(width - u * MARGIN_UNITS * 2.0, 1.0)
	var text := u * (NAME_UNITS + SOUL_UNITS + EFFECT_UNITS + GAP_UNITS * 2.0 + NET_GAP_UNITS)
	var cell := inner / DieNetView.net_size(1.0).x
	return u * MARGIN_UNITS * 2.0 + text + DieNetView.net_size(cell).y

var _column: Control
## Der Würfel, aus dem die stehende Säule gebaut wurde - je Bild gefragt, gebaut
## nur der WECHSEL (der Zeiger gehört hier niemandem).
var _signature := ""

func _init() -> void:
	name = "FachNetWindow"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # sie ist Auskunft, kein Bedienteil

## Den einen offenen Neuzugang setzen (null = fort). Idempotent.
func set_die(def: DieDefinition) -> void:
	var signature := _signature_of(def)
	if signature == _signature and (def == null or _column != null):
		return
	_signature = signature
	if _column != null and is_instance_valid(_column):
		remove_child(_column)
		_column.queue_free()
	_column = null
	if def == null or size.x <= 0.0 or size.y <= 0.0:
		return
	_build_column(def)

## Denselben Würfel noch einmal aufbauen - eine Gravur ändert seinen Inhalt, nicht
## seine Instanz, und die Signatur allein sähe das nicht.
func refresh() -> void:
	_signature = ""

## Steht die Säule? Der Beweis, daß sie zeigt, was die Schale trägt.
func net_count() -> int:
	return 1 if _column != null and is_instance_valid(_column) else 0

## EINE Säule: Name, Seele, Wirkung, Netz - in dieser Reihenfolge von oben nach
## unten, und das Netz nimmt, was die Erklärung übrig läßt.
## Sie hängt sich SOFORT ein: eine Zeile außerhalb des Baumes mißt sich an der
## Theme-Schrift statt an ihrem eigenen Grad und klemmt ihr Maß hoch.
func _build_column(def: DieDefinition) -> void:
	var u := size.x / UNIT_DIV
	var margin := u * MARGIN_UNITS
	var inner := maxf(size.x - margin * 2.0, 1.0)
	var column := Control.new()
	column.name = "Saeule"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	_column = column
	column.position = Vector2(margin, margin)
	column.size = Vector2(inner, maxf(size.y - margin * 2.0, 1.0))

	var essence := Essence.by_id(def.essence_id)
	var top := 0.0
	var name_h := u * NAME_UNITS
	_line(column, "Name", def.display_name, Vector2(0.0, top),
		Vector2(inner, name_h), name_h * NAME_FONT_SHARE, CasinoStyle.CREAM)
	top += name_h + u * GAP_UNITS

	# Die Seele in ihrem eigenen Glühen - dieselbe EINE Farbquelle wie im Laden.
	# Ein seelenloser Würfel läßt die Zeile leer und behält ihren Platz.
	var soul_h := u * SOUL_UNITS
	_line(column, "Seele", essence.display_name if essence != null else "",
		Vector2(0.0, top), Vector2(inner, soul_h), soul_h * SOUL_FONT_SHARE,
		ShopController.soul_tint(def.essence_id))
	top += soul_h + u * GAP_UNITS

	# Der umbrechende Satz bekommt eine Handbreit Rand: bündig gesetzt schnitt der
	# Umbruch die Ränder seiner längsten Zeile an.
	var effect_h := u * EFFECT_UNITS
	var effect := _line(column, "Wirkung",
		essence.description if essence != null else "", Vector2(u, top),
		Vector2(maxf(inner - u * 2.0, 1.0), effect_h),
		effect_h / float(EFFECT_LINES) * EFFECT_FONT_SHARE, CasinoStyle.MUTED, true)
	effect.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	top += effect_h + u * NET_GAP_UNITS

	var rest := maxf(column.size.y - top, 1.0)
	var cell := DieNetView.cell_for(Vector2(inner, rest))
	var span := DieNetView.net_size(cell)
	var host := Control.new()
	host.name = "NetzFeld"
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(host)
	host.position = Vector2((inner - span.x) * 0.5, top)
	host.size = span
	host.add_child(DieNetView.build(def, -1, cell))

func _line(host: Control, line_name: String, text: String, at: Vector2, span: Vector2,
		font_size: float, tint: Color, wrap := false) -> Label:
	var label := Label.new()
	label.name = line_name
	# Grad, Umbruch und clip_text VOR dem Maß: sonst rechnet die Mindestgröße mit
	# der Theme-Schrift und klemmt die Zeile auf ihre Höhe bzw. über ihre Spalte.
	label.add_theme_font_size_override("font_size", maxi(8, int(font_size)))
	label.add_theme_color_override("font_color", tint)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(label)
	label.text = text
	label.position = at
	label.size = span
	return label

## Der Schlüssel einer Belegung: die Würfel-Instanz und das eigene Maß.
func _signature_of(def: DieDefinition) -> String:
	if def == null:
		return ""
	return "%d@%d:%d" % [def.get_instance_id(), int(size.x), int(size.y)]
