class_name DieInspectorView
extends Control
## Die Gravur-Station für einen einzelnen Würfel - ein Neon-Panel im
## Werkstatt-Fenster (WorkshopView.attach_station). Der gegriffene Würfel
## schwebt als ECHTES Weltobjekt im Stasis-Feld über der Bühne links im Panel
## und IST die Ansicht; das Ziel wechselt ein Klick auf die echten Trays, die im
## selben Zoom darüber liegen. Auf ihn zeigt der Spieler direkt: scene_root
## pickt Seite und Rahmen und meldet sie über click_face/click_edges/
## set_die_hover herein, zurück gehen Auswahl (selection_changed) und Eignung
## (dimmed_faces).
##
## Werkzeug-zuerst: Klick auf eine Gravur am Bord NIMMT sie auf, dann führt die
## Station zu ihren Zielen (gültige Seiten leuchten, ungültige dimmen; Überfahren
## zeigt die Vorschau "3→5"). Gerichtete Paare lesen Quelle → Ziel. Ganz-Würfel-
## Gravuren (Spiegelung/Begradigung) brauchen keine Seitenwahl - ein Klick auf den
## Würfel genügt. Die KANTEN sind der Rahmen um die Seiten-Chips (wie an den
## Tray-Kacheln): Klickziel der Kanten-Gravuren, keine eigene Auswahl (ein Würfel
## hat nur einen Rahmen). Erneuter Klick aufs Werkzeug legt es ab. Der
## gezeigte Würfel ist DIESELBE DieDefinition-Instanz wie im Pool - die Gravur
## wirkt dauerhaft. Bedient über die Maus-Weiterleitung; Rechtsklick behandelt
## scene_root.

## Nach dem Anwenden einer Ätzung - scene_root zeichnet die Trays neu.
signal changed
## Nach dem Anwenden, mit Quelle für die Absorptions-Animation.
signal applied(engraving_id: String, slot_px: Vector2)
signal closed
## Kachel des Würfel-Rasters angeklickt: scene_root wechselt das Gravur-Ziel
## (slot = ECHTER Slot-Index im Ursprungs-Tray).
signal select_tray_die(slot: int)

## Auswahl oder Eignung geändert - scene_root malt beides auf das schwebende
## Werkstück (face_index 0..5, -1 = keine Auswahl).
signal selection_changed(face_index: int)

## Ablauf-Zustand: nichts in der Hand (Inspektion) oder Werkzeug hält und
## wartet auf Ziel-Klicks.
enum Mode { IDLE, TARGETING }

## Ziel-Form je Gravur - steuert Eignung, Vorschau und Anwendung.
const TARGET_FACE := "face"              # Kerbe, Feile, Transplantat, Blaupause, Materialien
const TARGET_PAIR_DIRECTED := "pair_directed"  # Meißel, Schleifstein, Anschluss (Quelle→Ziel)
const TARGET_PAIR := "pair"              # Doppelkerbe, Mittelung (ungeordnet)
const TARGET_WHOLE_DIE := "whole_die"    # Spiegelung, Begradigung

## Farben im Display-Stil (80s Neon).
const NEON_MAGENTA := Color("#ff79c6")
const NEON_GOLD := Color("#ffd319")
const NEON_TEXT := Color(1.35, 1.35, 1.3)
const NEON_MUTED := Color(0.75, 0.78, 0.9)
## Neutraler Rahmen unausgewählter Seiten-/Kanten-Chips.
const CHIP_BORDER := Color(0.72, 0.76, 0.8)
## Vorschau: Wert steigt grün, sinkt warm-rot; ungeeignete Ziffern dimmen grau.
## Das Grün ist dasselbe wie am liegenden Würfel (DieFaceDisplay) - grün heißt
## überall "vorläufig, steht nicht in der Def".
const PREVIEW_UP := DieFaceDisplay.PREVIEW_NUMBER_COLOR
const PREVIEW_DOWN := Color(1.0, 0.6, 0.5)
const DIM_NUMBER_COLOR := Color(0.35, 0.35, 0.42)
const DIM_CHIP_ALPHA := 0.30


## Mindest-Anteil der Panel-Höhe für die Bühne des schwebenden Werkstücks. Sie
## nimmt darüber hinaus, was die Seiten-Übersicht übrig lässt: der Würfel selbst
## ist die Anzeige, eine flache Projektion daneben gibt es nicht mehr.
const STAGE_FRACTION := 0.15
## Zellgröße des Seiten-Würfelnetzes (Breiteneinheiten u). Kleiner als das alte
## 3×2-Raster, weil das Kreuz 4×3 Plätze braucht und in dieselbe Spalte muss.
const TRAY_TILE := 5.0
## Höhe des Stationsinhalts in Maßeinheiten. Die Einheit kommt aus BEIDEN Achsen
## (min), sonst bläst ein breiteres Werkbank-Fenster den Inhalt über die
## unveränderte Fensterhöhe hinaus - die Breite allein ist kein Platzgewinn.
const CONTENT_UNITS := 51.0

## Textbreite des Seiten-Fensters in Einheiten - breit genug für die dotierten
## Zeilen und die Runen-Beinamen, ohne ins Raster hinauszulaufen.
const TOOLTIP_WIDTH := 30.0
## Rückfall-Skala des Ziel-Rasters, solange seine Spalte noch kein Maß hat.
const GRID_UNIT_SCALE := 0.80
## Rand des Rasters zu seiner Spalte (Breiteneinheiten u) - ringsum derselbe.
const GRID_MARGIN := 1.2

## Der laufende Spiellauf (setzt scene_root) - Engraving-Bestand und -Verbrauch.
var run: GameRun

var current_def: DieDefinition = null
## Sichtbare Auswahl-Spiegelung (violette Hervorhebung an Chips + schwebendem
## Würfel): bei Paaren der erste Klick, sonst reine Inspektions-Auswahl.
var selected_face: int = -1  # -1 = keine
var mode: int = Mode.IDLE
## Aufgenommene Gravur ("" = nichts in der Hand); ihr _targeting_of führt die Klicks.
var held_id: String = ""
## Erster Klick eines Paares (-1 = noch keiner); der zweite Klick schließt ab.
var first_face: int = -1
## Vorschau aktiv (Chip-Texte zeigen das Ergebnis, noch nicht angewandt).
var preview_active: bool = false
## Seite unter dem Zeiger (-1 = keine) - nur die Dotier-Vorschau braucht sie.
var hovered_face: int = -1
## Die zwei Zeiger-Quellen getrennt: der Chip im Netz meldet über die eigenen
## Hover-Signale, das schwebende Werkstück lässt scene_root je Frame picken.
## Zusammengelegt (nur hovered_face) löschte der Frame-Takt des Würfels den
## gerade betretenen Chip wieder.
var _hover_chip: int = -1
var _hover_die: int = -1

## Während der Runde gesperrt: der Würfel ist einsehbar, aber keine Gravur lässt
## sich aufnehmen/anwenden (setzt scene_root über set_editing_locked).
var editing_locked: bool = false

## Breiteneinheit (size.x / 100), in _build_layout gesetzt.
var u := 8.0

# Gerüst-Referenzen (je show_die frisch gebaut).
var summary_list: VBoxContainer  # Seiten-Raster im Kanten-Rahmen
## Anzeige-Reihenfolge der Seiten-Chips (physische Indizes): beim Öffnen/Ziel-
## Wechsel nach Wert sortiert, während der Bearbeitung eingefroren - die Chips
## springen beim Gravieren nicht um.
var face_order: Array[int] = []
## Seiten-Chips nach physischem Index (für Eignungs-Dimmung + Vorschau ohne
## Neuaufbau): Button, Grundfüllung und die im Ruhezustand gesetzte Zifferfarbe.
var face_chips: Array[Button] = []
var face_chip_fills: Array[Color] = []
var face_chip_font: Array[Color] = []
## Der Rahmen: Panel um das Seiten-Raster im Essenzglühen
## (die Kanten SIND der Rahmen um die Seiten). Klickziel der Kanten-Gravuren.
var edge_frame: PanelContainer

## Handgesteuerter Tooltip der Chips/Slots: Godots eingebautes Tooltip-System
## feuert im Tisch-SubViewport nicht zuverlässig - gesteuert über
## mouse_entered/mouse_exited (die Maus-Weiterleitung liefert Motion).
var face_tooltip: PanelContainer
var face_tooltip_title: Label
## Je Aussage EINE Zeile. Vorher lief alles in ein Label - eine Seite mit
## Material UND Rune schrieb dann zwei Wirkungstexte ineinander.
var face_tooltip_lines: VBoxContainer

## Das Gravur-Bord liegt NICHT im Panel, sondern in den drei Vorrats-Schubladen
## unter der Werkbank (setzt scene_root über set_drawers). Die Station hält nur
## den Ablauf; die Schubladen zeigen Bestand und Auswahl.
var drawers: Array[SupplyDrawerView] = []

## Würfel-Raster rechts: spiegelt das Ursprungs-Tray (Buchreihenfolge, leere
## Slots als leere Zellen); Klick meldet den ECHTEN Slot-Index. Der Kontext
## kommt von scene_root und übersteht den Neuaufbau des Gerüsts.
var target_grid: DiceGridView
var target_defs: Array[DieDefinition] = []
var target_current := -1
var target_columns := 10
## Die Spalte, die das Raster misst, und die zuletzt daraus errechnete Einheit.
var grid_host: Control
var _grid_unit := 0.0

## Die Bühne: leere Landefläche, über der der ECHTE Würfel schwebt; ihre Mitte
## ist Landeziel und Endpunkt der Absorptions-Bahn.
var stage: Control

## Öffnet die Station für def (die echte Pool-Instanz) und setzt den Zustand
## zurück; baut Gerüst und Bord frisch.
func show_die(def: DieDefinition) -> void:
	# Gerüst + Bord nur beim frischen Öffnen bauen. Beim Ziel-Wechsel bleiben
	# beide stehen (sie hängen am Lauf, nicht am Würfel) - der Bord-Aufbau
	# kostet ~17 ms und verursachte den Ruckler bei jeder Neu-Auswahl.
	var fresh_open := not visible or target_grid == null or not is_instance_valid(target_grid)
	current_def = def
	face_order = _faces_sorted_by_value(def)
	selected_face = -1
	held_id = ""
	first_face = -1
	mode = Mode.IDLE
	preview_active = false
	hovered_face = -1
	_hover_chip = -1
	_hover_die = -1
	if fresh_open:
		_build_layout()
	_sync_drawers()
	_refresh_face_summary()
	for drawer in drawers:
		drawer.set_ceremony(true)  # die Schubladen werden zum Werkzeug-Bord
	_sync_drawers()
	visible = true

## Der gezeigte Würfel hat sich von außen geändert (Kauf, Nehmen-Effekt): das
## Netz nachziehen, ohne die Werkzeug-Auswahl zu verlieren.
func refresh_die() -> void:
	if current_def == null or not visible:
		return
	face_order = _faces_sorted_by_value(current_def)
	_refresh_face_summary()

func close() -> void:
	if not visible:
		return
	for drawer in drawers:
		drawer.set_ceremony(false)  # zurück in die Lager-Anzeige
	visible = false
	closed.emit()

# --- Gerüst (Neon-Panel) -------------------------------------------------------

func _build_layout() -> void:
	for child in get_children():
		child.queue_free()
	u = minf(maxf(size.x, 640.0) / 100.0, size.y / CONTENT_UNITS)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true  # nichts ragt über den Hub-Rahmen hinaus

	# Schmaler Rand ringsum: das Ziel-Raster soll das Fenster ausfüllen. Keine
	# Kopfzeile - der schwebende Würfel sagt deutlich genug, was hier läuft.
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, int(u * GRID_MARGIN))
	add_child(margin)

	var root := VBoxContainer.new()
	root.name = "Root"
	root.add_theme_constant_override("separation", int(u * 1.2))
	margin.add_child(root)

	_build_body(root)

	_build_face_tooltip()  # zuletzt: liegt als Overlay über allem

## Querformat, weil das Werkstatt-Fenster flach ist: links oben die Bühne des
## schwebenden Werkstücks, darunter die Seiten-Übersicht; rechts allein das
## Ziel-Raster. Die linke Spalte nimmt nur ihre Mindestbreite - der Rest gehört
## dem Raster, das sonst breitenbegrenzt wäre und oben/unten Luft stehen ließe.
func _build_body(root: Control) -> void:
	var body := HBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", int(u * GRID_MARGIN))
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	var left_col := VBoxContainer.new()
	left_col.name = "LeftColumn"
	left_col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_col.add_theme_constant_override("separation", int(u * 1.0))
	body.add_child(left_col)

	# Oben der ECHTE schwebende Würfel, darunter sein Netz: dieselbe Sache
	# zweimal, von körperlich zu abstrakt. Die Bühne bekommt allen Platz, den das
	# Netz übrig lässt - sie ist die Ansicht, nicht bloß ein Landeplatz.
	stage = CenterContainer.new()
	stage.name = "Stage"
	stage.custom_minimum_size = Vector2(u * 10.0, size.y * STAGE_FRACTION)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Sie nimmt die GANZE Spaltenbreite (das Netz darunter gibt sie ohnehin vor):
	# zur Bühne gehört nicht nur der Würfel, sondern auch seine Stasis-Station -
	# die steht auf der Fläche und liegt damit ein Stück unterhalb von ihm.
	stage.size_flags_horizontal = Control.SIZE_FILL
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_col.add_child(stage)

	summary_list = VBoxContainer.new()
	summary_list.name = "FaceSummary"
	summary_list.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	summary_list.size_flags_vertical = Control.SIZE_SHRINK_END
	summary_list.add_theme_constant_override("separation", int(u * 0.8))
	left_col.add_child(summary_list)

	# Bewusst ein nacktes Control, KEIN Container: es misst den Platz für das
	# Raster: ein Container würde dessen Mindestmaß zurückmelden und mit jedem
	# Neuaufbau weiterwachsen. Das Raster wird darin von Hand zentriert.
	var right_col := Control.new()
	right_col.name = "RightColumn"
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(right_col)
	grid_host = right_col
	grid_host.resized.connect(_refresh_target_grid)
	_build_target_grid(right_col)

## Das Würfel-Raster des Ursprungs-Trays: ein Klick macht einen anderen Würfel
## zum Ziel, ohne den Blick von der Station zu nehmen. Die Augensummen zeigen
## dabei, welcher Würfel eine Gravur am nötigsten hat.
func _build_target_grid(root: Control) -> void:
	target_grid = DiceGridView.new()
	target_grid.name = "TargetGrid"
	target_grid.place(target_columns, u * GRID_UNIT_SCALE, true)
	target_grid.slot_pressed.connect(func(index: int) -> void: select_tray_die.emit(index))
	root.add_child(target_grid)
	_refresh_target_grid()

## Übernimmt das Raster des Ursprungs-Trays (je ECHTEM Slot eine Def, null =
## leer) und welcher Slot gerade bearbeitet wird.
func set_target_grid(columns: int, defs: Array[DieDefinition], current_slot: int) -> void:
	target_columns = maxi(columns, 1)
	target_defs = defs
	target_current = current_slot
	_refresh_target_grid()

## Erklärzeile zur Ziel-Kachel unter pixel ("" = keine). Die Station schreibt
## sonst nichts mehr auf die Hinweiskarte - nur die Seele des Würfels, über den
## der Zeiger gerade steht (scene_root fragt je Bild).
func grid_hint_at(pixel: Vector2) -> String:
	if target_grid == null or not is_instance_valid(target_grid):
		return ""
	return target_grid.hint_at(pixel)

func _refresh_target_grid() -> void:
	if target_grid == null or not is_instance_valid(target_grid):
		return
	var unit := _target_grid_unit()
	if is_equal_approx(unit, _grid_unit) and target_grid.get_child_count() > 0:
		return  # resized feuert während des Layouts mehrfach - nicht neu bauen
	_grid_unit = unit
	target_grid.place(target_columns, unit, true)
	target_grid.fill(target_defs, target_current)
	_center_target_grid.call_deferred()

## Setzt das Raster in seine Spalte (der nackte Control-Wirt legt nichts aus):
## senkrecht mittig und rechts mit DEMSELBEN Abstand. Die Kacheln sind quadratisch,
## also bleibt der Rest der Breite links stehen - dort federt ihn die Würfel-Spalte ab.
func _center_target_grid() -> void:
	if target_grid == null or not is_instance_valid(target_grid) \
			or grid_host == null or not is_instance_valid(grid_host):
		return
	var span := target_grid.get_combined_minimum_size()
	target_grid.size = span
	var margin := maxf((grid_host.size.y - span.y) * 0.5, 0.0)
	target_grid.position = Vector2(maxf(grid_host.size.x - span.x - margin, 0.0), margin)

## Maßeinheit des Rasters: es füllt seine Spalte in BEIDEN Richtungen aus, statt
## an einer festen Skala zu hängen (dann stand oben/unten Luft). Vor dem ersten
## Layout ist die Spalte noch maßlos - der feste Anteil springt dann ein.
func _target_grid_unit() -> float:
	if grid_host == null or not is_instance_valid(grid_host) or grid_host.size.x <= 0.0:
		return u * GRID_UNIT_SCALE
	var columns := maxi(target_columns, 1)
	var rows := maxi(int(ceil(float(target_defs.size()) / float(columns))), 1)
	# Senkrecht ohne Abzug: der Wirt sitzt bereits im Fensterrand. Waagerecht geht
	# nur der linke Abstand zur Würfel-Spalte ab.
	return DiceGridView.unit_for(columns, rows, grid_host.size - Vector2(u * GRID_MARGIN, 0.0))

## Bestand je Gravur-id (Testmodus: alles einmal vorhanden) - entscheidet, ob
## ein Werkzeug nach dem Anwenden in der Hand bleibt.
func _engraving_counts() -> Dictionary:
	var counts := {}
	if run == null:
		return counts
	if run.unlimited_engravings:
		for archetype in Engraving.all():
			counts[archetype.id] = 1
		return counts
	for engraving in run.owned_engravings:
		counts[engraving.id] = counts.get(engraving.id, 0) + 1
	return counts

## Reicht Werkzeug-Zustand und Eignung an die Schubladen weiter - sie sind das
## Bord. Aufbau passiert dort (an engravings_changed), hier nur das Umfärben.
func _sync_drawers() -> void:
	for drawer in drawers:
		if is_instance_valid(drawer):
			drawer.set_state(held_id, [] as Array[String], editing_locked)

## Sperrt/entsperrt das Bearbeiten (Runde läuft): der Würfel bleibt einsehbar,
## die Gravuren werden unbenutzbar.
func set_editing_locked(locked: bool) -> void:
	if editing_locked == locked:
		return
	editing_locked = locked
	if locked and held_id != "":
		_put_down_tool()  # ein gehaltenes Werkzeug fällt ab
	_sync_drawers()

## Verdrahtet die Schubladen als Werkzeug-Bord (setzt scene_root).
func set_drawers(list: Array[SupplyDrawerView]) -> void:
	drawers = list
	for drawer in drawers:
		if not drawer.tool_pressed.is_connected(_on_engraving_pressed):
			drawer.tool_pressed.connect(_on_engraving_pressed)
	_sync_drawers()

# --- Bühne ----------------------------------------------------------------------

## Bühnen-Mitte in Display-Pixeln (Landeziel/Endpunkt der Absorptions-Bahn);
## Panel-Mitte als Rückfall.
func stage_center_px() -> Vector2:
	if stage != null and is_instance_valid(stage):
		return stage.get_global_rect().get_center()
	return get_global_rect().get_center()

# --- Würfel-Raster (Umwählen) ----------------------------------------------------

## Seiten-Indizes nach Augenzahl aufsteigend (bei Gleichstand nach Index) -
## Raster und Kacheln lesen wie "1-6", jede Kachel bleibt ihre EIGENE Seite.
func _faces_sorted_by_value(def: DieDefinition) -> Array[int]:
	var order: Array[int] = []
	for i in def.faces.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		if def.faces[a] != def.faces[b]:
			return def.faces[a] < def.faces[b]
		return a < b)
	return order

func _material_of(def: DieDefinition, face_index: int) -> String:
	return def.materials[face_index] if face_index < def.materials.size() else ""

func _tile_box(bg: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(maxi(1, int(u * 0.33)))
	box.set_corner_radius_all(int(u * 0.9))
	return box

# --- Werkzeug-Zustand ------------------------------------------------------------

## true, solange eine Gravur in der Hand ist (Rechtsklick legt sie ab, siehe scene_root).
func has_pending_action() -> bool:
	return held_id != ""

## Ziel-Form einer Gravur.
func _targeting_of(engraving_id: String) -> String:
	if DieMaterial.is_valid_id(engraving_id):
		return TARGET_FACE
	match engraving_id:
		Engraving.CHISEL, Engraving.GRINDSTONE, Engraving.POINTER:
			return TARGET_PAIR_DIRECTED
		Engraving.AVERAGING:
			return TARGET_PAIR
		Engraving.STRAIGHTEN, Engraving.POLISH, Engraving.SANDPAPER:
			return TARGET_WHOLE_DIE
	return TARGET_FACE  # Kerbe, Feile, Stanze, Blaupause

## Zusätzliche Runen-Plätze aus dem Dock: die Glasglocke gibt dem Vakuum einen
## dritten. Die Def kennt keine Charms, also entscheidet die Station.
func _extra_rune_slots() -> int:
	return 1 if run != null and run.charm_ids().has(Charm.BELL_JAR) else 0

## Platz, auf den das nächste Rune dieser Seite fällt: der erste FREIE
## (Vakuum trägt zwei, mit Glasglocke drei), sonst der erste - er wird ersetzt.
func _free_rune_slot(face_index: int) -> int:
	for slot in current_def.rune_slots(_extra_rune_slots()):
		var occupied: String = current_def.runes[face_index]
		if slot == 1:
			occupied = current_def.second_runes[face_index]
		elif slot == 2:
			occupied = current_def.third_runes[face_index]
		if occupied == "":
			return slot
	return 0

## Bord-Klick: dieselbe Gravur legt ab, sonst nimmt sie (neue) auf.
func _on_engraving_pressed(engraving_id: String) -> void:
	if current_def == null or editing_locked:
		return
	if held_id == engraving_id:
		_put_down_tool()
	else:
		_pick_up_tool(engraving_id)

func _pick_up_tool(engraving_id: String) -> void:
	held_id = engraving_id
	first_face = -1
	selected_face = -1
	mode = Mode.TARGETING
	preview_active = false
	_restyle_slots()
	_refresh_face_summary()

func _put_down_tool() -> void:
	held_id = ""
	first_face = -1
	selected_face = -1
	mode = Mode.IDLE
	preview_active = false
	_restyle_slots()
	_refresh_face_summary()

## Bricht das laufende Werkzeug ab (Rechtsklick, siehe scene_root).
func cancel_pending() -> void:
	if held_id == "":
		return
	_put_down_tool()

# --- Ziel-Klicks -----------------------------------------------------------------

## Klick auf eine Seite (Chip oder 3D). Ohne Werkzeug = reine Inspektions-Auswahl.
func _handle_face_target(face_index: int) -> void:
	if current_def == null:
		return
	if held_id == "":
		selected_face = face_index
		_refresh_face_summary()
		return
	match _targeting_of(held_id):
		TARGET_WHOLE_DIE:
			_apply_whole_die()
		TARGET_FACE:
			if _face_eligible(face_index):
				_apply_single_face(face_index)
		TARGET_PAIR, TARGET_PAIR_DIRECTED:
			if not _face_eligible(face_index):
				return
			if first_face == -1:
				first_face = face_index
				selected_face = face_index  # erster Klick violett hervorgehoben
				_clear_preview()
				_refresh_face_summary()
			else:
				_apply_pair(first_face, face_index)

## Klick auf den Rahmen (Rahmen-Panel oder 3D): Ziel der Ganz-Würfel-Gravuren.
## Die Kanten selbst sind KEIN Ausbau-Slot mehr - sie zeigen nur noch die Essenz,
## und die ist angeboren.
func _handle_edge_target() -> void:
	if current_def == null or held_id == "":
		return
	if _targeting_of(held_id) == TARGET_WHOLE_DIE:
		_apply_whole_die()  # Klick am Rahmen zählt als Würfel-Klick

## Zielt das gehaltene Werkzeug auf den GANZEN Würfel? Dann ist der Rahmen sein
## Klickziel - der schwebende Würfel der Zeremonie hebt ihn passend hervor.
## (Nachfolger des alten edges_targeted: Kanten sind kein Ausbau-Slot mehr.)
func whole_die_targeted() -> bool:
	return held_id != "" and _targeting_of(held_id) == TARGET_WHOLE_DIE

## Klick auf eine Seite des schwebenden Werkstücks (scene_root pickt sie).
func click_face(face_index: int) -> void:
	_handle_face_target(face_index)

## Klick auf den Kanten-Rahmen des Werkstücks - Ziel der Ganz-Würfel-Gravuren.
func click_edges() -> void:
	_handle_edge_target()

func _on_chip_clicked(_value: int, face_index: int) -> void:
	_handle_face_target(face_index)

# --- Anwendung -------------------------------------------------------------------

## Einseitige Gravuren + Material auf die geklickte Seite.
func _apply_single_face(face_index: int) -> void:
	if DieMaterial.is_valid_id(held_id):
		current_def.set_face_material(face_index, held_id)
		_finish_apply(held_id)
		return
	if Engraving.is_rune_id(held_id):
		# Ein besetzter Platz wird ersetzt - neu brechen ist erlaubt. Auf dem
		# Vakuum-Würfel füllt der zweite Rune erst den freien Zweitplatz.
		var rune_id := Engraving.rune_id_of(held_id)
		current_def.set_rune(face_index, rune_id, _free_rune_slot(face_index), _extra_rune_slots())
		_finish_apply(held_id)
		return
	match held_id:
		Engraving.DOPING:
			# Der einzige Weg in den dotierten Zustand - darum ein epischer Sonderposten.
			current_def.dope(face_index)
			_finish_apply(held_id)
		Engraving.NOTCH:
			EtchingEffects.notch(current_def, face_index)
			_finish_apply(held_id)
		Engraving.FILE_DOWN:
			EtchingEffects.file_down(current_def, face_index)
			_finish_apply(held_id)
		Engraving.PUNCH:
			EtchingEffects.punch(current_def, face_index)
			_finish_apply(held_id)
		Engraving.BLUEPRINT:
			EtchingEffects.blueprint(current_def, face_index)
			_finish_apply(held_id)

## Gerichtete/ungeordnete Paare: a = erster Klick (Quelle/−1), b = zweiter (Ziel/+1).
func _apply_pair(a: int, b: int) -> void:
	match held_id:
		Engraving.CHISEL:
			EtchingEffects.chisel(current_def, a, b)  # Quelle a -> Ziel b
			_finish_apply(held_id)
		Engraving.GRINDSTONE:
			EtchingEffects.grindstone(current_def, a, b)  # −1 auf a, +1 auf b
			_finish_apply(held_id)
		Engraving.AVERAGING:
			EtchingEffects.averaging(current_def, a, b)
			_finish_apply(held_id)
		Engraving.POINTER:
			# Überschreiben erlaubt - je Seite höchstens eine Leiterbahn.
			current_def.pointers[a] = b
			_finish_apply(held_id)

## Ganz-Würfel-Gravuren (ein Klick auf den Würfel genügt).
func _apply_whole_die() -> void:
	match held_id:
		Engraving.STRAIGHTEN:
			EtchingEffects.straighten(current_def)
			_finish_apply(held_id)
		Engraving.POLISH:
			EtchingEffects.polish(current_def)
			_finish_apply(held_id)
		Engraving.SANDPAPER:
			EtchingEffects.sandpaper(current_def)
			_finish_apply(held_id)

## Verbraucht die Gravur und meldet changed/applied. Das Werkzeug bleibt in der
## Hand, solange noch Exemplare da sind (direkt weitergravieren) - sonst abgelegt.
func _finish_apply(engraving_id: String) -> void:
	if run != null:
		# Gravierstift: einmal pro Runde wird eine ÄTZUNG nicht verbraucht -
		# Materialien und die Sonderposten (Leiterbahn, Dotierung) nie.
		var is_etching := not DieMaterial.is_valid_id(engraving_id) \
			and not Engraving.is_special_id(engraving_id)
		if is_etching and CharmEffects.has_engraving_pen(run.charm_ids()) and not run.gravierstift_used_this_round:
			run.gravierstift_used_this_round = true
		else:
			# Zwinge: die Material-Gravur bleibt manchmal eingespannt (je Anwendung neu).
			run.consume_applied_engraving(engraving_id)
	var keep: bool = int(_engraving_counts().get(engraving_id, 0)) > 0
	held_id = engraving_id if keep else ""
	first_face = -1
	selected_face = -1
	mode = Mode.TARGETING if keep else Mode.IDLE
	preview_active = false
	changed.emit()
	applied.emit(engraving_id, _slot_center_px(engraving_id))
	_sync_drawers()  # der Bestand hat sich geändert (die Schubladen bauen selbst neu)
	_refresh_face_summary()

## Display-Pixel der Bord-Kachel einer Gravur (Quelle der Absorptions-Bahn);
## Panel-Mitte als Rückfall.
func _slot_center_px(engraving_id: String) -> Vector2:
	for drawer in drawers:
		if is_instance_valid(drawer):
			var center := drawer.slot_center_px(engraving_id)
			if center.x >= 0.0:
				return center
	return stage_center_px()

# --- Eignung ---------------------------------------------------------------------

## Je Seite: gültiges Ziel der gehaltenen Gravur im aktuellen Schritt. Ohne
## Werkzeug ist alles gültig (Inspektion).
func _eligible_faces() -> Array[bool]:
	var e: Array[bool] = []
	e.resize(6)
	if current_def == null or held_id == "":
		e.fill(true)
		return e
	e.fill(false)
	var faces := current_def.faces
	match held_id:
		Engraving.FILE_DOWN:
			for i in 6: e[i] = faces[i] > EtchingEffects.MIN_FACE_VALUE
		Engraving.GRINDSTONE:
			if first_face == -1:
				for i in 6: e[i] = faces[i] > EtchingEffects.MIN_FACE_VALUE  # die −1-Seite
			else:
				for i in 6: e[i] = i != first_face
		Engraving.POINTER:
			# Ziel nur eine NACHBAR-Seite - die Leiterbahn quert genau eine Kante.
			if first_face == -1:
				e.fill(true)
			else:
				for i in 6: e[i] = current_def.can_point(first_face, i)
		Engraving.DOPING:
			# Sie dotiert ein vorhandenes Material - leere und schon dotierte
			# Seiten fallen weg.
			for i in 6: e[i] = DieMaterial.is_valid_id(current_def.materials[i]) \
				and current_def.material_level(i) < DieMaterial.MAX_LEVEL
		_:
			match _targeting_of(held_id):
				TARGET_FACE:
					if DieMaterial.is_valid_id(held_id):
						# Dasselbe Material noch einmal ist kein Ziel; ein Einbrand
						# sperrt das Übermalen.
						for i in 6:
							e[i] = current_def.materials[i] != held_id and not _face_burned_in(i)
					else:
						e.fill(true)
				TARGET_WHOLE_DIE:
					e.fill(true)
				TARGET_PAIR, TARGET_PAIR_DIRECTED:
					if first_face == -1:
						e.fill(true)
					else:
						for i in 6: e[i] = i != first_face
	return e

## Ist der Wert dieser Seite eingebrannt? Dann lässt sie sich nicht übermalen.
func _face_burned_in(face_index: int) -> bool:
	return RuneEffects.protects_face_value(current_def.runes_on(face_index))

func _face_eligible(face_index: int) -> bool:
	return _eligible_faces()[face_index]

## Je Seite: soll ihre Ziffer am schwebenden Werkstück ausgegraut sein? Nur mit
## Werkzeug in der Hand, und die gewählte Seite bleibt immer hell (sie ist der
## erste Klick eines Paares).
func dimmed_faces() -> Array[bool]:
	var dim: Array[bool] = []
	dim.resize(6)
	dim.fill(false)
	if current_def == null or held_id == "":
		return dim
	var eligible := _eligible_faces()
	for i in 6:
		dim[i] = i != selected_face and not eligible[i]
	return dim

## Rahmenfarbe: das Essenzglühen (neutral das Kanten-Neon), gedimmt unter einem
## Seiten-Werkzeug - der Rahmen ist nur noch Anzeige.
func _edge_frame_border() -> Color:
	var base := Essence.glow_for(current_def.essence_id) if Essence.is_valid_id(current_def.essence_id) \
		else DieFaceDisplay.EDGE_NEON
	if held_id == "" or _targeting_of(held_id) == TARGET_WHOLE_DIE:
		return base
	return Color(base.r, base.g, base.b, 0.3)

# --- Vorschau (Überfahren) -------------------------------------------------------

func _on_face_hover(face_index: int) -> void:
	_hover_chip = face_index
	_apply_hover()

func _on_face_hover_exit() -> void:
	_hover_chip = -1
	_apply_hover()

## Seite unter dem Zeiger am schwebenden Werkstück (-1 = keine); scene_root
## pickt sie je Frame, weil der Zeiger auf dem Tisch liegt, nicht im SubViewport.
func set_die_hover(face_index: int) -> void:
	_hover_die = face_index
	_apply_hover()

## Das Werkstück schlägt den Chip: der Zeiger kann nur an einem von beiden
## stehen, und der Würfel meldet sich je Frame - er darf den Chip nicht löschen.
func _apply_hover() -> void:
	var face := _hover_die if _hover_die != -1 else _hover_chip
	if face == hovered_face:
		return
	hovered_face = face
	_sync_level_preview()
	if face == -1:
		_clear_preview()
	else:
		_preview_face(face)

## Zustand, den diese Seite NACH dem gehaltenen Werkzeug trüge - die Zelle zeigt
## die Ziel-Sättigung, sobald das Werkzeug über ihr steht.
func _level_after(face_index: int) -> int:
	if current_def == null:
		return 1
	var level := current_def.material_level(face_index)
	if held_id == "" or hovered_face != face_index or not _face_eligible(face_index):
		return level
	if held_id == Engraving.DOPING:
		return DieMaterial.MAX_LEVEL
	return level

## Malt die Zellen auf den Zustand um, den sie NACH dem Werkzeug trügen. Ohne
## Zeiger fällt jede auf ihren echten zurück - der Aufruf ist idempotent.
func _sync_level_preview() -> void:
	if current_def == null:
		return
	for face_index in face_chips.size():
		var chip: Button = face_chips[face_index]
		if chip == null or not is_instance_valid(chip) or chip.disabled:
			continue
		_paint_chip_fill(chip, DieMaterial.tint_for(
			_material_of(current_def, face_index), _level_after(face_index)))

## Tauscht nur die Füllung eines Chips - Auswahlrand, Schrift und Dimmung bleiben.
func _paint_chip_fill(chip: Button, fill: Color) -> void:
	for state in ["normal", "hover", "pressed"]:
		var box := chip.get_theme_stylebox(state) as StyleBoxFlat
		if box == null:
			continue
		box.bg_color = fill.lightened(0.12) if state == "hover" \
			else (fill.darkened(0.1) if state == "pressed" else fill)

## Vorschau des Ergebnisses, wenn die gehaltene Gravur hier landet.
func _preview_face(face_index: int) -> void:
	if held_id == "" or current_def == null:
		return
	var kind := _targeting_of(held_id)
	if kind == TARGET_WHOLE_DIE:
		var gw := _ghost_after(-1)
		if gw != null:
			_show_preview(gw.faces)
		return
	if kind == TARGET_FACE:
		if DieMaterial.is_valid_id(held_id):
			return  # Material ändert keine Augenzahl
		if not _face_eligible(face_index):
			return
		var g := _ghost_after(face_index)
		if g != null:
			_show_preview(g.faces)
		return
	if kind == TARGET_PAIR or kind == TARGET_PAIR_DIRECTED:
		if first_face == -1 or not _face_eligible(face_index):
			return  # erst nach dem ersten Klick sinnvoll
		var gp := _ghost_after(face_index)
		if gp != null:
			_show_preview(gp.faces)

## Vorschau eines Ganz-Würfel-Werkzeugs beim Überfahren seines Bord-Slots.
func _preview_slot_hover(engraving_id: String) -> void:
	if current_def == null:
		return
	if held_id != "" and held_id != engraving_id:
		return  # ein anderes Werkzeug ist in der Hand
	var g := current_def.instantiate()
	match engraving_id:
		Engraving.STRAIGHTEN:
			EtchingEffects.straighten(g)
		Engraving.POLISH:
			EtchingEffects.polish(g)
		Engraving.SANDPAPER:
			EtchingEffects.sandpaper(g)
		_:
			return
	_show_preview(g.faces)

# --- Kanten-Rahmen ---------------------------------------------------------------

## Klick in den Rahmen (auch zwischen/unter den Chips - bei gehaltener Kanten-
## Gravur reichen die Chips durch).
func _on_edge_frame_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_edge_target()

## Überfahren des Rahmens: die Essenz erklärt sich - nur lesen, nie ändern.
func _on_edge_frame_hover() -> void:
	_show_essence_info()

func _on_edge_frame_hover_exit() -> void:
	_hide_face_tooltip()
	_clear_preview()


## Klon nach Anwendung der gehaltenen Gravur (hover_face -1 bei Ganz-Würfel);
## null, wenn hier nichts passiert. Nutzt die echten EtchingEffects (kein Duplikat).
func _ghost_after(hover_face: int) -> DieDefinition:
	var g := current_def.instantiate()
	match _targeting_of(held_id):
		TARGET_FACE:
			match held_id:
				Engraving.NOTCH: EtchingEffects.notch(g, hover_face)
				Engraving.FILE_DOWN: EtchingEffects.file_down(g, hover_face)
				Engraving.PUNCH: EtchingEffects.punch(g, hover_face)
				Engraving.BLUEPRINT: EtchingEffects.blueprint(g, hover_face)
				_: return null
		TARGET_PAIR, TARGET_PAIR_DIRECTED:
			match held_id:
				Engraving.CHISEL: EtchingEffects.chisel(g, first_face, hover_face)
				Engraving.GRINDSTONE: EtchingEffects.grindstone(g, first_face, hover_face)
				Engraving.AVERAGING: EtchingEffects.averaging(g, first_face, hover_face)
		TARGET_WHOLE_DIE:
			match held_id:
				Engraving.STRAIGHTEN: EtchingEffects.straighten(g)
				Engraving.POLISH: EtchingEffects.polish(g)
				Engraving.SANDPAPER: EtchingEffects.sandpaper(g)
		_:
			return null
	return g

## Zeigt das Ergebnis in den Chips ("3→5", grün/rot), ohne den echten Würfel
## zu verändern.
func _show_preview(new_faces: Array) -> void:
	if current_def == null or face_chips.size() < 6:
		return
	preview_active = true
	for i in 6:
		var chip: Button = face_chips[i]
		var old_v: int = current_def.faces[i]
		var new_v: int = int(new_faces[i])
		if chip == null or not is_instance_valid(chip):
			continue
		if new_v != old_v:
			chip.text = "%d→%d" % [old_v, new_v]
			chip.add_theme_font_size_override("font_size", maxi(8, int(u * TRAY_TILE * 0.30)))
			var col := PREVIEW_UP if new_v > old_v else PREVIEW_DOWN
			for st in ["font_color", "font_hover_color", "font_pressed_color"]:
				chip.add_theme_color_override(st, col)

## Stellt Chip-Texte/Rahmenfarbe aus current_def wieder her (Ende der Vorschau).
func _clear_preview() -> void:
	if not preview_active:
		return
	preview_active = false
	_restore_face_chips()
	if edge_frame != null and is_instance_valid(edge_frame) and current_def != null:
		edge_frame.add_theme_stylebox_override("panel", _edge_frame_box(_edge_frame_border()))

func _restore_face_chips() -> void:
	if current_def == null:
		return
	for i in mini(6, face_chips.size()):
		var chip: Button = face_chips[i]
		if chip == null or not is_instance_valid(chip):
			continue
		chip.text = str(current_def.faces[i])
		chip.add_theme_font_size_override("font_size", int(u * TRAY_TILE * 0.5))
		var col: Color = face_chip_font[i] if i < face_chip_font.size() else CasinoStyle.INK
		for st in ["font_color", "font_hover_color", "font_pressed_color"]:
			chip.add_theme_color_override(st, col)

# --- Seiten-Übersicht -------------------------------------------------------------

## Baut die Seiten-Übersicht neu: je physischer Seite ein Chip (Wert +
## Material-Tönung) im 3×2-Raster in der eingefrorenen face_order, eingefasst
## vom Rahmen im Essenzglühen. Klick wählt genau diese Seite.
func _refresh_face_summary() -> void:
	if summary_list == null:
		return
	_hide_face_tooltip()  # die alten Chips (mit Hover-Verbindungen) fallen weg
	for child in summary_list.get_children():
		child.queue_free()
	if current_def == null:
		return

	edge_frame = PanelContainer.new()
	edge_frame.name = "EdgeFrame"
	edge_frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	edge_frame.add_theme_stylebox_override("panel", _edge_frame_box(_edge_frame_border()))
	edge_frame.gui_input.connect(_on_edge_frame_input)
	edge_frame.mouse_entered.connect(_on_edge_frame_hover)
	edge_frame.mouse_exited.connect(_on_edge_frame_hover_exit)
	summary_list.add_child(edge_frame)

	# Würfelnetz statt Reihenraster: dieselbe Anordnung wie im Netzfeld der Grube,
	# also nach PHYSISCHER Lage - nur so treffen die Leiterbahn-Pfeile die Kante,
	# über die sie zeigen. Ein nacktes Control, weil die Zellen absolut sitzen.
	var cell := u * TRAY_TILE
	var face_grid := Control.new()
	face_grid.name = "FaceNet"
	face_grid.custom_minimum_size = DieNetView.net_size(cell)
	face_grid.mouse_filter = Control.MOUSE_FILTER_PASS  # Klicks erreichen den Rahmen
	edge_frame.add_child(face_grid)
	# Chip-Referenzen nach physischem Index für Eignungs-Dimmung + Vorschau.
	face_chips.clear()
	face_chips.resize(6)
	face_chip_fills.clear()
	face_chip_fills.resize(6)
	face_chip_font.clear()
	face_chip_font.resize(6)
	var eligible := _eligible_faces()
	if face_order.size() != current_def.faces.size():
		face_order = _faces_sorted_by_value(current_def)  # Rückfall (Tests/Direktzugriff)
	for face_index in face_order:
		var value: int = current_def.faces[face_index]
		var material_id := _material_of(current_def, face_index)
		# Gedimmt nur, wenn ein Werkzeug hält, die Seite kein Ziel und nicht der
		# erste Paar-Klick ist.
		var ok := held_id == "" or eligible[face_index] or face_index == first_face
		var chip := _face_chip(value, material_id, selected_face == face_index, face_index, ok)
		chip.position = DieNetView.cell_position(face_index, cell)
		chip.size = Vector2.ONE * cell
		face_chips[face_index] = chip
		face_chip_fills[face_index] = DieMaterial.tint_for(material_id,
			current_def.material_level(face_index))
		face_chip_font[face_index] = chip.get_theme_color("font_color")
		face_grid.add_child(chip)

	# Essenz-Chip in die leere Kreuz-Ecke, Runen durch die Zellmitten, Dotier-
	# Plaketten in die Zellecken und die Leiterbahn-Pfeile obendrauf - die Pfeile
	# zuletzt, sie liegen über den Zellrändern. Die Station baut ihre Zellen
	# selbst, also auch Runen und Plaketten.
	face_grid.add_child(DieNetView.edge_chip(current_def, cell))
	for crack in DieNetView.rune_glyphs(current_def, cell):
		face_grid.add_child(crack)
	for badge in DieNetView.level_badges(current_def, cell):
		face_grid.add_child(badge)
	for arrow in DieNetView.pointer_arrows(current_def, cell):
		face_grid.add_child(arrow)

	selection_changed.emit(selected_face)  # scene_root malt Auswahl + Dimmung aufs Werkstück

## Anklickbarer Seiten-Chip im Look der echten Würfel; highlighted = violetter
## Auswahl-Look, eligible = gültiges Ziel (sonst gedimmt/gesperrt). Material-
## Tooltip + Vorschau-Hover handgesteuert (siehe face_tooltip).
func _face_chip(value: int, material_id: String, highlighted: bool, face_index: int, eligible: bool) -> Button:
	var chip := Button.new()
	chip.text = str(value)
	chip.custom_minimum_size = Vector2.ONE * u * TRAY_TILE
	chip.add_theme_font_size_override("font_size", int(u * TRAY_TILE * 0.5))
	_style_chip(chip, DieMaterial.tint_for(material_id, _level_after(face_index)),
		highlighted, eligible)
	chip.disabled = held_id != "" and not eligible and not highlighted
	# JEDE Seite erklärt sich - auch die nackte: das Fenster steht fest, also
	# kostet eine leere Seite keinen springenden Kasten mehr.
	chip.mouse_entered.connect(_show_face_info.bind(face_index))
	chip.mouse_exited.connect(_hide_face_tooltip)
	# Vorschau beim Überfahren (alle Seiten) + Ziel-Klick.
	chip.mouse_entered.connect(_on_face_hover.bind(face_index))
	chip.mouse_exited.connect(_on_face_hover_exit)
	chip.pressed.connect(_on_chip_clicked.bind(value, face_index))
	return chip

## Stylebox des Kanten-Rahmens: dicker Rand + hauchdünne Füllung in border.
func _edge_frame_box(border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(border.r, border.g, border.b, 0.10)
	box.border_color = border
	box.set_border_width_all(maxi(2, int(u * 0.7)))
	box.set_corner_radius_all(int(u * 1.6))
	box.set_content_margin_all(int(u * 1.1))
	return box

## Gemeinsamer Chip-Look: Füllung bleibt die Material-/Kantenfarbe; gewählt
## leuchten Ziffer + Rahmen in der Auswahl-Farbe (mit dunklem Umriss, damit
## das Violett auf hellen Seiten lesbar bleibt). Ungeeignete Chips dimmen aus.
func _style_chip(chip: Button, base_fill: Color, highlighted: bool, eligible: bool = true) -> void:
	chip.focus_mode = Control.FOCUS_NONE
	chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if not eligible and not highlighted:
		var dim_fill := Color(base_fill.r, base_fill.g, base_fill.b, base_fill.a * DIM_CHIP_ALPHA)
		var muted := Color(NEON_MUTED.r, NEON_MUTED.g, NEON_MUTED.b, 0.5)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
			chip.add_theme_color_override(state, muted)
		chip.add_theme_color_override("font_outline_color", CasinoStyle.INK)
		chip.add_theme_constant_override("outline_size", 0)
		var dim_box := _chip_box(dim_fill, CHIP_BORDER.darkened(0.35), maxi(2, int(u * 0.2)))
		for state in ["normal", "hover", "pressed", "disabled"]:
			chip.add_theme_stylebox_override(state, dim_box)
		chip.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		return
	var font_color := DieFaceDisplay.SELECT_NUMBER_COLOR if highlighted else CasinoStyle.INK
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		chip.add_theme_color_override(state, font_color)
	chip.add_theme_color_override("font_outline_color", CasinoStyle.INK)
	chip.add_theme_constant_override("outline_size", int(u * 0.45) if highlighted else 0)
	var border := DieFaceDisplay.SELECT_NUMBER_COLOR if highlighted else CHIP_BORDER
	var border_width := int(u * 0.6) if highlighted else maxi(2, int(u * 0.2))
	chip.add_theme_stylebox_override("normal", _chip_box(base_fill, border, border_width))
	chip.add_theme_stylebox_override("hover", _chip_box(base_fill.lightened(0.12), border, border_width))
	chip.add_theme_stylebox_override("pressed", _chip_box(base_fill.darkened(0.1), border, border_width))
	chip.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _chip_box(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(maxi(1, border_width))
	box.set_corner_radius_all(int(u * 1.0))
	return box

## Spiegelt Werkzeug-Zustand in die Schubladen (sie stylen ihre Plätze selbst).
func _refresh_engraving_enabled() -> void:
	_sync_drawers()

func _restyle_slots() -> void:
	_sync_drawers()

# --- Neon-Bausteine ----------------------------------------------------------------

func _label(text: String, font_size: float, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", maxi(8, int(font_size)))
	label.modulate = color
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _neon_button(text: String, accent: Color, font_size: float, min_size: Vector2 = Vector2.ZERO) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override("font_size", maxi(8, int(font_size)))
	button.add_theme_color_override("font_color", NEON_TEXT)
	button.add_theme_color_override("font_hover_color", NEON_GOLD)
	button.add_theme_color_override("font_pressed_color", NEON_GOLD)
	button.add_theme_color_override("font_disabled_color", Color(NEON_MUTED.r, NEON_MUTED.g, NEON_MUTED.b, 0.45))
	button.add_theme_stylebox_override("normal", _button_box(Color("#221e46cc"), accent))
	button.add_theme_stylebox_override("hover", _button_box(Color("#2c2757dd"), NEON_GOLD))
	button.add_theme_stylebox_override("pressed", _button_box(Color("#3a2f66"), NEON_GOLD))
	button.add_theme_stylebox_override("focus", _button_box(Color("#221e46cc"), accent))
	button.add_theme_stylebox_override("disabled", _button_box(Color("#1a183666"), Color(accent.r, accent.g, accent.b, 0.25)))
	return button

func _button_box(bg: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(maxi(1, int(u * 0.22)))
	box.set_corner_radius_all(int(u * 0.9))
	box.set_content_margin_all(int(u * 0.8))
	return box

# --- Tooltip-Overlay ----------------------------------------------------------------

## Baut das (verborgene) Tooltip-Overlay im Charm-Look, u-skaliert für das
## hochaufgelöste Display; liegt als letztes Kind über allem im Panel.
func _build_face_tooltip() -> void:
	face_tooltip = PanelContainer.new()
	face_tooltip.name = "FaceTooltip"
	face_tooltip.visible = false
	face_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CasinoStyle.style_panel(face_tooltip)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", int(u * 0.4))
	face_tooltip.add_child(box)
	face_tooltip_title = Label.new()
	face_tooltip_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CasinoStyle.style_score_label(face_tooltip_title, int(u * 2.6), CasinoStyle.GOLD)
	box.add_child(face_tooltip_title)
	face_tooltip_lines = VBoxContainer.new()
	face_tooltip_lines.name = "Lines"
	face_tooltip_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face_tooltip_lines.add_theme_constant_override("separation", int(u * 0.35))
	box.add_child(face_tooltip_lines)
	add_child(face_tooltip)

## Füllt das Overlay und stellt es an seinen FESTEN Platz. Es folgt bewusst
## nicht mehr dem Zeiger: eine Seite kann Material, zwei Runen und eine
## Leiterbahn tragen, und eine wandernde Karte dieser Höhe springt bei jedem
## Chip woandershin. Jede Aussage bekommt ihre eigene Zeile.
func _show_face_tooltip(title: String, lines: Array[String]) -> void:
	if face_tooltip == null:
		return
	face_tooltip_title.text = title
	for child in face_tooltip_lines.get_children():
		face_tooltip_lines.remove_child(child)
		child.queue_free()
	for line in lines:
		if line == "":
			continue
		var label := Label.new()
		label.text = line
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(u * TOOLTIP_WIDTH, 0)
		CasinoStyle.style_body_label(label, int(u * 1.9), CasinoStyle.CREAM)
		face_tooltip_lines.add_child(label)
	face_tooltip.visible = true
	face_tooltip.reset_size()
	face_tooltip.position = _face_tooltip_anchor()

## Fester Platz: rechts NEBEN dem Würfel-Schirm, bündig an der unteren linken
## Ecke des Ziel-Rasters. Dass er das Raster dort überdeckt, ist gewollt - wer
## eine Seite mustert, sucht in diesem Moment keinen anderen Würfel aus.
func _face_tooltip_anchor() -> Vector2:
	var pos := Vector2(size.x * 0.5, size.y * 0.5)
	if grid_host != null and is_instance_valid(grid_host):
		var local := grid_host.get_global_rect().position - get_global_rect().position
		pos = Vector2(local.x, local.y + grid_host.size.y - face_tooltip.size.y)
	pos.x = clampf(pos.x, u * 1.0, maxf(u * 1.0, size.x - face_tooltip.size.x - u * 1.0))
	pos.y = clampf(pos.y, u * 1.0, maxf(u * 1.0, size.y - face_tooltip.size.y - u * 1.0))
	return pos

## Die Zeilen EINER Seite: Kopf mit Nummer und Wert (plus Vorschauwert, wenn das
## gehaltene Werkzeug ihn verschöbe), dann je Ausbau eine eigene Zeile.
func _show_face_info(face_index: int) -> void:
	if current_def == null or face_index < 0 or face_index >= current_def.faces.size():
		return
	var value: int = current_def.faces[face_index]
	var title := "Seite %d – Wert %d" % [face_index + 1, value]
	if held_id != "":
		var ghost := _ghost_after(face_index)
		if ghost != null and ghost.faces[face_index] != value:
			title += " → %d" % ghost.faces[face_index]
	_show_face_tooltip(title, _face_tooltip_lines_for(face_index))

## Baut die Zeilen einer Seite - reine Textarbeit, damit die Tests sie ohne
## Layout prüfen können.
func _face_tooltip_lines_for(face_index: int) -> Array[String]:
	var lines: Array[String] = []
	var material_id := _material_of(current_def, face_index)
	if DieMaterial.is_valid_id(material_id):
		lines.append(DieMaterial.face_hint(material_id, current_def.material_level(face_index)))
	for rune_id in current_def.runes_on(face_index):
		var rune := Rune.by_id(rune_id)
		lines.append("%s – %s: %s" % [rune.display_name, rune.kind, rune.short])
	var pointer_target: int = current_def.pointers[face_index] if face_index < current_def.pointers.size() else -1
	if pointer_target >= 0:
		lines.append("Leiterbahn: löst die Seite mit Wert %d zu 50 %% einmal mit aus." % current_def.faces[pointer_target])
	return lines

## Dasselbe Fenster für den Rahmen: dort wohnt die Seele des Würfels.
func _show_essence_info() -> void:
	if current_def == null or not Essence.is_valid_id(current_def.essence_id):
		return
	var essence := Essence.by_id(current_def.essence_id)
	var lines: Array[String] = []
	lines.append(essence.description)
	_show_face_tooltip(essence.display_name, lines)

func _hide_face_tooltip() -> void:
	if face_tooltip != null:
		face_tooltip.visible = false
