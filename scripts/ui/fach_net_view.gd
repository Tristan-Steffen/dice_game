class_name FachNetView
extends Control
## Die INFO-SÄULE des Ausgabefachs, seit der KORREKTUR-WELLE I KOMPAKT: über ihr
## LIEGT der eine offene Neuzugang (oder der gewählte Zielwürfel) als Körper, und sie
## trägt darunter ALLEIN sein Würfelnetz - DIREKT unter dem Würfel. Name, Seele und
## Wirkung sind in den Info-Schirm der Werkstatt gewandert; hier steht nur noch das
## Netz, dafür deutlich GRÖSSER (es füllt die ganze Spalte, statt sich mit Text zu
## teilen).
## Ohne Zeiger und ohne Rahmen: sie steht, wann immer das Fach etwas trägt, und ist
## sonst gar nicht da (die Laden-Grammatik).
## Sie MELDET nichts und faßt nichts an - scene_root reicht ihr den Würfel herein
## und schneidet ihr Rechteck unter der Schale zu (das apron_bottom-Muster). Ihr
## gebautes Zellmaß (net_cell) gibt scene_root an das Ergebnis-Netz der Werkstatt
## weiter, damit beide Netze GLEICH GROSS stehen.

## Rand ringsum, in u (= Fensterbreite / UNIT_DIV).
const UNIT_DIV := 100.0
const MARGIN_UNITS := 4.0

## Die Höhe, die die Säule bei dieser BREITE braucht: Rand plus das Netz, das die
## Breite hergibt (nur das Netz - der Text ist fort). scene_root schneidet ihr
## Rechteck daraus, statt eine Zahl zu tippen.
static func height_for(width: float) -> float:
	var u := width / UNIT_DIV
	var inner := maxf(width - u * MARGIN_UNITS * 2.0, 1.0)
	var cell := inner / DieNetView.net_size(1.0).x  # nur die Breite bindet
	return u * MARGIN_UNITS * 2.0 + DieNetView.net_size(cell).y

var _column: Control
## Das gebaute Zellmaß des Netzes in Display-Pixeln (0 = steht gerade nicht) -
## scene_root reicht es an das Ergebnis-Netz der Werkstatt weiter (GLEICH GROSS).
var _cell := 0.0
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
	_cell = 0.0
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

## Das gebaute Zellmaß des Netzes (0 = steht gerade nicht) - die EINE Quelle, aus
## der auch das rechte Ergebnis-Netz der Werkstatt seine Größe nimmt.
func net_cell() -> float:
	return _cell

## Display-Pixel der Netz-Mitte ((-1,-1) = die Säule steht gerade nicht) - der
## GEBURTSORT der Schablone: hier steht das Netz des Zielwürfels.
func net_center_px() -> Vector2:
	if _column == null or not is_instance_valid(_column) or not visible:
		return Vector2(-1, -1)
	var host := _column.get_node_or_null("NetzFeld") as Control
	if host == null:
		return Vector2(-1, -1)
	return host.get_global_rect().get_center()

## EINE Säule: nur das Netz, DIREKT unter dem Würfel (oben in der Spalte, denn der
## Würfel schwebt über ihrer Oberkante) und mittig.
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

	var cell := DieNetView.cell_for(Vector2(inner, column.size.y))
	_cell = cell
	var span := DieNetView.net_size(cell)
	var host := Control.new()
	host.name = "NetzFeld"
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(host)
	host.position = Vector2((inner - span.x) * 0.5, 0.0)
	host.size = span
	host.add_child(DieNetView.build(def, -1, cell))

## Der Schlüssel einer Belegung: die Würfel-Instanz und das eigene Maß.
func _signature_of(def: DieDefinition) -> String:
	if def == null:
		return ""
	return "%d@%d:%d" % [def.get_instance_id(), int(size.x), int(size.y)]
