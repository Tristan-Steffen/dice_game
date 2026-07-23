class_name CharmDockView
extends Control
## Charm-Terminal unter der (3D-)Charm-Reihe: je Platz EIN eigener, senkrechter
## Konsolen-Screen mit runden Ecken - OBEN ein runder Projektor (dort tritt der
## 3D-Strahl aus dem Screen), DARUNTER der Bild-Screen mit gerendertem Charm
## (CharmThumb) im Raritätsrahmen. Beim Überfahren (Karte ODER Hologramm) wechselt
## der Bild-Screen dieser EINEN Konsole auf Name + Wirkung - kein geteiltes
## Info-Band, jeder Charm bleibt gekapselt. Umsortieren läuft in 2D über die
## Konsolen (scene_root steuert den Zieh-Automaten über
## pad_index_at/begin_drag/drag_to/drop_target/end_drag).

## Kantenlicht-Glas-Look (statt bunter Vollflächen): dunkles Glas, Platin-
## Haarlinien wie die LED-Leisten, Rarität NUR als dünnes, überhelles Kantenlicht
## (bloomt auf dem HDR-Screen). Hover wärmt die Haarlinie Richtung Casino-Gold.
const PLATINUM := Color(0.75, 0.79, 0.9)               # poliertes Platin (Haarlinie)
const GLASS_FILL := Color(0.02, 0.02, 0.055, 0.9)      # dunkles Glas des Chassis
const CARD_FILL := Color(0.014, 0.014, 0.03, 0.95)     # Bild-Screen, noch dunkler
const LENS_CORE := Color(0.008, 0.008, 0.02, 0.96)     # Linsen-Tiefe
const HAIRLINE_ALPHA := 0.22   # Deckkraft der Platin-Haarlinie
const EDGE_ALPHA := 0.5        # Grund-Deckkraft des Raritäts-Kantenlichts
const RARITY_TINT := 0.06      # winziger Raritäts-Anteil im Karten-Glas
const THUMB_INSET := 0.82  # Bild-Anteil an der Karten-Kante (Rest = Rahmen)
const DRAG_SCALE := 1.12    # gezogene Karte hebt sich leicht ab

## Konsolen-Maße relativ zur Kartengröße (_pad_size). Der Projektor sitzt exakt
## auf der Blenden-Mitte (= Auftreffpunkt des 3D-Strahls) und hat GENAU den
## Durchmesser des Hologramm-Kraftfelds (scene_root setzt projector_radius aus
## dem Beam-Radius). Karten-Abstand + Konsolen-Höhe folgen dem Projektorradius.
const PROJECTOR_GAP := 0.18       # Abstand Projektor-Unterkante -> Kartenoberkante
const PROJECTOR_FALLBACK := 0.24  # Projektor-Radius (Kartenhöhen), bis scene_root den Beam meldet
const CONSOLE_PAD_X := 0.09       # seitlicher Mindest-Rand der Konsole um die Karte
const CONSOLE_PAD_Y := 0.14       # Rand über dem Projektor
const CONSOLE_PAD_BOTTOM := 0.3   # Rand unter der Karte - trägt den Dauer-Chip
const BADGE_GAP := 0.03           # Abstand Kartenunterkante -> Dauer-Chip

## Projektor-Radius in Viewport-Pixeln (= Beam-Radius). Fallback bis scene_root
## ihn setzt: knapp ein Viertel der Kartenhöhe.
var projector_radius := 0.0

## Projektor- und Kartenmitten als lokale Offsets (Fenster-relativ), je Platz
## Konsolen-Rect, Rarität und Flash.
var _aperture_offsets: PackedVector2Array = PackedVector2Array()
var _pad_offsets: PackedVector2Array = PackedVector2Array()
var _console_rects: Array[Rect2] = []
var _pad_size := Vector2.ZERO
var _occupied := 0
var _pad_colors: Array[Color] = []
var _flash: Array[float] = []
## Gerenderte Charm-Kacheln (Index = Platz), ihre Ruhe-Position (Dock-lokal) und
## die Charms selbst (für den Hover-Text).
var _thumbs: Array[CharmThumb] = []
var _thumb_home: Array[Vector2] = []
var _charms: Array[Charm] = []
## Zieh-/Hover-Zustand.
var _drag_index := -1
var _drop_hint := -1
var _hover := -1
## Hover-Text (wandert in die überflogene Konsole; nur eine ist je hovert).
var _name_label: Label
var _body_label: Label
## Verkaufs-Chip am Kartenboden der gehoverten Konsole; scene_root prüft Klicks
## über sell_index_at und verkauft dann via GameRun.sell_charm.
var _sell_label: Label
var _sell_rect := Rect2()
var _sell_values: Array[int] = []
## Dauer-Chips mit laufendem Wert UNTER den Karten (Alles-oder-nichts-/Momentum-
## Mult, Lumpensammler-Glückszahl); scene_root füllt sie über set_badges.
## Ein Chip je Platz, leerer Text = versteckt.
var _badge_labels: Array[Label] = []
var _badge_texts := {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_ensure_labels()

## Spannt das Dock über die (Viewport-)Blenden-Mitten auf (dort münden die
## 3D-Strahlen); je Mitte entsteht eine Konsole, die Karte liegt darunter.
## pad_size = Kartengröße, proj_radius = Beam-/Kraftfeld-Radius in px (Projektor).
## NACH dem Platzieren rufen.
func place(aperture_centers_px: PackedVector2Array, pad_size: Vector2, proj_radius := 0.0) -> void:
	if aperture_centers_px.is_empty():
		return
	_ensure_labels()
	_pad_size = pad_size
	projector_radius = proj_radius
	var drop := _card_drop_px()
	var r := _console_rect_for(aperture_centers_px[0])
	for c in aperture_centers_px:
		r = r.merge(_console_rect_for(c))
	position = r.position
	size = r.size
	_aperture_offsets = PackedVector2Array()
	_pad_offsets = PackedVector2Array()
	_console_rects.clear()
	for c in aperture_centers_px:
		_aperture_offsets.append(c - position)
		_pad_offsets.append(c + Vector2(0, drop) - position)
		var console := _console_rect_for(c)
		_console_rects.append(Rect2(console.position - position, console.size))
	_flash.resize(_pad_offsets.size())
	_flash.fill(0.0)
	_style_labels()
	_clear_thumbs()
	_update_badges()
	queue_redraw()

## Projektor-Radius (Beam-Radius, sonst Fallback aus der Kartenhöhe).
func _projector_r() -> float:
	return projector_radius if projector_radius > 0.0 else _pad_size.y * PROJECTOR_FALLBACK

## Pixel-Abstand Blendenmitte -> Kartenmitte (Projektor + Lücke + halbe Karte).
func _card_drop_px() -> float:
	return _projector_r() + _pad_size.y * PROJECTOR_GAP + _pad_size.y * 0.5

## Konsolen-Rect (Viewport-Koordinaten) um eine Blenden-Mitte; breit genug für
## Projektor UND Karte, hoch genug für beide.
func _console_rect_for(aperture: Vector2) -> Rect2:
	var pr := _projector_r()
	var margin := _pad_size.x * CONSOLE_PAD_X
	var half_w := maxf(_pad_size.x * 0.5, pr) + margin
	var top := aperture.y - pr - _pad_size.y * CONSOLE_PAD_Y
	var bottom := aperture.y + _card_drop_px() + _pad_size.y * (0.5 + CONSOLE_PAD_BOTTOM)
	return Rect2(aperture.x - half_w, top, half_w * 2.0, bottom - top)

## Konsolen-Rects in Viewport-Koordinaten (für die Reflexions-Fenstermaske).
func console_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for r in _console_rects:
		out.append(Rect2(position + r.position, r.size))
	return out

## Eck-Radius der Konsolen (auch für die Reflexionsmaske).
func console_corner_radius() -> float:
	return _pad_size.x * 0.16

## Übernimmt Belegung + Raritätsfarben (Reihenfolge = Besitz) und rendert je
## belegtem Platz eine Charm-Kachel. Überzählige Charms (> Plätze) fallen weg.
## sell_values (je Platz, gleiche Reihenfolge) speist den Verkaufs-Chip; ohne
## Werte zeigt der Hover nur Name + Wirkung.
func set_charms(charms: Array[Charm], sell_values: Array[int] = []) -> void:
	set_hover(-1)
	_occupied = mini(charms.size(), _pad_offsets.size())
	_pad_colors.clear()
	_charms = charms.duplicate()
	_sell_values = sell_values.duplicate()
	_clear_thumbs()
	var inner := maxf(1.0, _pad_size.y * THUMB_INSET)
	for i in _occupied:
		_pad_colors.append(Charm.RARITY_COLORS.get(charms[i].rarity,
			Charm.RARITY_COLORS[Charm.RARITY_COMMON]))
		var thumb := CharmThumb.new(charms[i], int(inner), false)
		thumb.pivot_offset = Vector2(inner, inner) / 2.0
		var home := _pad_offsets[i] - Vector2(inner, inner) / 2.0
		thumb.position = home
		add_child(thumb)
		_thumbs.append(thumb)
		_thumb_home.append(home)
	_update_badges()
	queue_redraw()

## Setzt ALLE Dauer-Chips neu (Platz -> Text); Plätze ohne Eintrag bleiben leer.
func set_badges(texts: Dictionary) -> void:
	_badge_texts = texts.duplicate()
	_update_badges()

## Legt je Chip mittig UNTER seine Karte (in den Konsolen-Rand) und hebt ihn über
## die Kacheln; ohne Text/Platz bleibt er versteckt.
func _update_badges() -> void:
	while _badge_labels.size() < _pad_offsets.size():
		var fresh := Label.new()
		fresh.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fresh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fresh.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(fresh)
		_badge_labels.append(fresh)
		_style_badge(fresh)
	var bw := _pad_size.x * 0.62
	var bh := _pad_size.y * 0.2
	for i in _badge_labels.size():
		var label := _badge_labels[i]
		var text: String = str(_badge_texts.get(i, ""))
		var active := text != "" and i < _occupied and i < _pad_offsets.size()
		label.visible = active
		if not active:
			continue
		label.text = text
		var card_bottom := _pad_offsets[i] + Vector2(0, _pad_size.y * 0.5)
		label.position = card_bottom + Vector2(-bw * 0.5, _pad_size.y * BADGE_GAP)
		label.size = Vector2(bw, bh)
		move_child(label, get_child_count() - 1)

## Viewport-Mitte der KARTE i (Quelle des Zähl-Lichts, Zieh-Anker).
func pad_center(i: int) -> Vector2:
	if i < 0 or i >= _pad_offsets.size():
		return position + size / 2.0
	return position + _pad_offsets[i]

## Belegter Platz, dessen KONSOLE unter dem (Viewport-)Pixel liegt (Projektor
## zählt mit - dieselbe Einheit), oder -1.
func pad_index_at(pixel: Vector2) -> int:
	for i in _occupied:
		if Rect2(position + _console_rects[i].position, _console_rects[i].size).has_point(pixel):
			return i
	return -1

## Platz, dessen Verkaufs-Chip unter dem (Viewport-)Pixel liegt - nur die
## gehoverte Konsole zeigt ihn - oder -1.
func sell_index_at(pixel: Vector2) -> int:
	if _hover < 0 or not _sell_label.visible:
		return -1
	return _hover if Rect2(position + _sell_rect.position, _sell_rect.size).has_point(pixel) else -1

## Konsole i hervorheben und ihren Bild-Screen auf Name + Wirkung umschalten
## (Hover über Karte ODER Hologramm); -1 stellt das Bild zurück. Kein Effekt
## während eines Drags (dort führt das Ablageziel).
func set_hover(i: int) -> void:
	if _drag_index >= 0 or i == _hover:
		return
	if _hover >= 0 and _hover < _thumbs.size() and _thumbs[_hover] != null:
		_thumbs[_hover].visible = true
	_hover = i
	if i >= 0 and i < _charms.size():
		if i < _thumbs.size() and _thumbs[i] != null:
			_thumbs[i].visible = false
		_name_label.text = _charms[i].display_name
		_body_label.text = _charms[i].description
		_sell_label.text = ("Verkaufen $%d" % _sell_values[i]) if i < _sell_values.size() else ""
		_place_labels_in_card(i)
	else:
		_name_label.text = ""
		_body_label.text = ""
		_sell_label.text = ""
	_name_label.visible = _hover >= 0
	_body_label.visible = _hover >= 0
	_sell_label.visible = _hover >= 0 and _sell_label.text != ""
	queue_redraw()

## Kurzer Helligkeits-Puls auf Konsole i ("dieser Charm feuert") - Projektor UND
## Karte überstrahlen kurz (bloomt auf dem HDR-Screen), synchron zum
## 3D-flash_charm.
func flash_pad(i: int) -> void:
	if i < 0 or i >= _flash.size():
		return
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void:
		_flash[i] = v
		queue_redraw(), 1.0, 0.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if i < _thumbs.size() and _thumbs[i] != null:
		var thumb := _thumbs[i]
		var mod := create_tween()
		mod.tween_property(thumb, "self_modulate", Color(2.2, 2.2, 2.2), 0.08)
		mod.tween_property(thumb, "self_modulate", Color.WHITE, 0.42)

## --- Umsortieren (2D-Drag, von scene_root gesteuert) ---------------------------

## Hebt die Karte des Platzes i an (nach vorn, leicht vergrößert).
func begin_drag(i: int) -> void:
	if i < 0 or i >= _thumbs.size() or _thumbs[i] == null:
		return
	set_hover(-1)  # Hover-Text schließen, BEVOR der Drag ihn sperrt
	_drag_index = i
	_drop_hint = i
	move_child(_thumbs[i], get_child_count() - 1)
	_thumbs[i].scale = Vector2.ONE * DRAG_SCALE
	queue_redraw()

## Zieht die gehobene Karte zum (Viewport-)Pixel; markiert den nächsten Platz
## (nach x) als Ablageziel.
func drag_to(pixel: Vector2) -> void:
	if _drag_index < 0:
		return
	var thumb := _thumbs[_drag_index]
	thumb.position = (pixel - position) - thumb.size / 2.0
	_drop_hint = _nearest_slot_by_x((pixel - position).x)
	queue_redraw()

## Aktuelles Ablageziel (Platz-Index) oder -1.
func drop_target() -> int:
	return _drop_hint

## Beendet den Drag: Karte zurück auf ihren Platz, Zustand löschen. (Bei echtem
## Umsortieren baut set_charms die Karten ohnehin neu.)
func end_drag() -> void:
	if _drag_index >= 0 and _drag_index < _thumbs.size() and _thumbs[_drag_index] != null:
		_thumbs[_drag_index].scale = Vector2.ONE
		_thumbs[_drag_index].position = _thumb_home[_drag_index]
	_drag_index = -1
	_drop_hint = -1
	queue_redraw()

## Belegter Platz, dessen Karten-Mitte in x am nächsten liegt.
func _nearest_slot_by_x(local_x: float) -> int:
	var best := -1
	var best_dist := INF
	for i in _occupied:
		var dist := absf(_pad_offsets[i].x - local_x)
		if dist < best_dist:
			best_dist = dist
			best = i
	return best

func _ensure_labels() -> void:
	if _name_label != null:
		return
	_name_label = Label.new()
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.visible = false
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_name_label)
	_body_label = Label.new()
	_body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body_label.visible = false
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_body_label)
	_sell_label = Label.new()
	_sell_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sell_label.visible = false
	_sell_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sell_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_sell_label)

## Schriftgrößen an der Kartengröße ausrichten (Name in Gold, Wirkung in Creme).
func _style_labels() -> void:
	CasinoStyle.style_score_label(_name_label, int(_pad_size.y * 0.13), CasinoStyle.GOLD)
	CasinoStyle.style_body_label(_body_label, int(_pad_size.y * 0.105), CasinoStyle.CREAM)
	CasinoStyle.style_score_label(_sell_label, int(_pad_size.y * 0.09), CasinoStyle.GOLD)
	var chip := StyleBoxFlat.new()
	chip.bg_color = Color(0.05, 0.035, 0.02, 0.92)
	chip.border_color = Color(CasinoStyle.GOLD.r, CasinoStyle.GOLD.g, CasinoStyle.GOLD.b, 0.55)
	chip.set_border_width_all(maxi(1, int(_pad_size.y * 0.012)))
	chip.set_corner_radius_all(maxi(2, int(_pad_size.y * 0.05)))
	_sell_label.add_theme_stylebox_override("normal", chip)
	for label in _badge_labels:
		_style_badge(label)

## Dauer-Chip: überheller Rand, damit er auf dem HDR-Screen leuchtet.
func _style_badge(label: Label) -> void:
	CasinoStyle.style_score_label(label, int(_pad_size.y * 0.13), CasinoStyle.GOLD)
	var badge := StyleBoxFlat.new()
	badge.bg_color = Color(0.02, 0.02, 0.05, 0.95)
	badge.border_color = Color(CasinoStyle.GOLD.r * 1.6, CasinoStyle.GOLD.g * 1.6, CasinoStyle.GOLD.b * 1.6, 0.9)
	badge.set_border_width_all(maxi(1, int(_pad_size.y * 0.016)))
	badge.set_corner_radius_all(maxi(2, int(_pad_size.y * 0.08)))
	badge.set_content_margin_all(maxf(1.0, _pad_size.y * 0.02))
	label.add_theme_stylebox_override("normal", badge)

## Legt die Hover-Texte in die Karten-Fläche der Konsole i; der Wirkungstext
## schrumpft schrittweise, bis er in die verfügbare Höhe passt. Am Kartenboden
## sitzt der Verkaufs-Chip (Treffer-Rect für sell_index_at).
func _place_labels_in_card(i: int) -> void:
	var inset := _pad_size.x * 0.09
	var card_top_left := _pad_offsets[i] - _pad_size / 2.0
	var inner_w := _pad_size.x - inset * 2.0
	var chip_h := _pad_size.y * 0.16 if _sell_label.text != "" else 0.0
	var body_h := _pad_size.y - inset * 1.2 - _pad_size.y * 0.18 - chip_h
	_name_label.position = card_top_left + Vector2(inset, inset * 0.6)
	_name_label.size = Vector2(inner_w, _pad_size.y * 0.18)
	_body_label.position = card_top_left + Vector2(inset, inset * 0.6 + _pad_size.y * 0.18)
	_body_label.size = Vector2(inner_w, body_h)
	_fit_body_font(inner_w, body_h)
	var chip_w := inner_w * 0.9
	_sell_label.position = card_top_left \
		+ Vector2((_pad_size.x - chip_w) * 0.5, _pad_size.y - inset * 0.6 - chip_h)
	_sell_label.size = Vector2(chip_w, chip_h)
	_sell_rect = Rect2(_sell_label.position, _sell_label.size)
	# Text über die Kachel-Kinder heben.
	move_child(_name_label, get_child_count() - 1)
	move_child(_body_label, get_child_count() - 1)
	move_child(_sell_label, get_child_count() - 1)

## Verkleinert die Wirkungs-Schrift, bis der umgebrochene Text in die Karten-
## Fläche passt (gemessen über die Font-Metrik, nicht per Frame-Layout).
func _fit_body_font(width: float, height: float) -> void:
	var font := _body_label.get_theme_font("font")
	if font == null:
		return
	var font_size := int(_pad_size.y * 0.105)
	var min_size := maxi(8, int(_pad_size.y * 0.055))
	while font_size > min_size:
		var text_size := font.get_multiline_string_size(_body_label.text,
			HORIZONTAL_ALIGNMENT_LEFT, width, font_size)
		if text_size.y <= height:
			break
		font_size -= 2
	_body_label.add_theme_font_size_override("font_size", font_size)

func _clear_thumbs() -> void:
	for thumb in _thumbs:
		if thumb != null:
			thumb.queue_free()
	_thumbs.clear()
	_thumb_home.clear()

## Platin-Haarlinie; leer schwächer, bei Hover Richtung Casino-Gold gewärmt.
func _hairline(occupied: bool, lit: bool) -> Color:
	var a := HAIRLINE_ALPHA if occupied else HAIRLINE_ALPHA * 0.5
	if lit:
		var g := CasinoStyle.GOLD
		return Color(lerpf(PLATINUM.r, g.r, 0.7), lerpf(PLATINUM.g, g.g, 0.7),
			lerpf(PLATINUM.b, g.b, 0.7), a + 0.28)
	return Color(PLATINUM.r, PLATINUM.g, PLATINUM.b, a)

## Raritäts-Kantenlicht: überhelle Raritätsfarbe (bloomt), Hover/Flash heben an.
func _edge_light(rarity: Color, lit: bool, flash: float) -> Color:
	var b := 1.7 + flash * 2.2 + (0.5 if lit else 0.0)
	var a := EDGE_ALPHA + flash * 0.4 + (0.18 if lit else 0.0)
	return Color(rarity.r * b, rarity.g * b, rarity.b * b, clampf(a, 0.0, 1.0))

## Projektor als Glaslinse: dunkler Kern (Tiefe), Platin-Linsenringe, innen ein
## überhelles Raritäts-Ringlicht - dort tritt der Strahl aus.
func _draw_lens(c: Vector2, pr: float, rarity: Color, occupied: bool, lit: bool,
		flash: float, hair: Color, hair_w: float, edge_w: float) -> void:
	draw_circle(c, pr, GLASS_FILL)
	draw_circle(c, pr * 0.62, LENS_CORE)
	draw_arc(c, pr, 0.0, TAU, 64, hair, hair_w)
	draw_arc(c, pr * 0.72, 0.0, TAU, 48, Color(hair.r, hair.g, hair.b, hair.a * 0.6), hair_w * 0.7)
	if occupied:
		draw_arc(c, pr * 0.86, 0.0, TAU, 64, _edge_light(rarity, lit, flash), edge_w)

func _draw() -> void:
	if _pad_offsets.is_empty():
		return
	var radius := console_corner_radius()
	var hair_w := maxf(1.5, _pad_size.y * 0.014)   # Haarlinie statt Klotz-Rahmen
	var edge_w := maxf(2.0, _pad_size.y * 0.02)
	var card_radius := int(_pad_size.y * 0.16)
	for i in _pad_offsets.size():
		var occupied := i < _occupied
		var rarity: Color = _pad_colors[i] if occupied else PLATINUM
		var lit := occupied and (i == _hover or (i == _drop_hint and _drag_index >= 0))
		var flash: float = _flash[i] if i < _flash.size() else 0.0
		var hair := _hairline(occupied, lit)
		var card_rect := Rect2(_pad_offsets[i] - _pad_size / 2.0, _pad_size)

		# Chassis: gleicher Fenster-Grund wie alle Screens; Linse und Karte bleiben
		# dunkler (Kraftfeld-Generator bzw. Bild/Text). Platin-Haarlinie.
		var chassis := StyleBoxFlat.new()
		chassis.bg_color = TableScreen.FRAME_BG
		chassis.border_color = hair
		chassis.set_border_width_all(int(hair_w))
		chassis.set_corner_radius_all(int(radius))
		draw_style_box(chassis, _console_rects[i])

		_draw_lens(_aperture_offsets[i], _projector_r(), rarity, occupied, lit, flash,
			hair, hair_w, edge_w)

		# Bild-Screen: dunkles Glas (Hauch Rarität), Platin-Haarlinie.
		var card_fill := CARD_FILL
		if occupied:
			card_fill = CARD_FILL.lerp(Color(rarity.r, rarity.g, rarity.b, CARD_FILL.a), RARITY_TINT)
		var card := StyleBoxFlat.new()
		card.bg_color = card_fill
		card.border_color = hair
		card.set_border_width_all(int(hair_w))
		card.set_corner_radius_all(card_radius)
		draw_style_box(card, card_rect)
		# Raritäts-Kantenlicht: dünne, überhelle Innenlinie (kantenbeleuchtetes Acryl).
		if occupied:
			var inset := edge_w * 1.6
			var edge_box := StyleBoxFlat.new()
			edge_box.draw_center = false
			edge_box.border_color = _edge_light(rarity, lit, flash)
			edge_box.set_border_width_all(int(edge_w))
			edge_box.set_corner_radius_all(maxi(1, card_radius - int(inset * 0.5)))
			draw_style_box(edge_box, card_rect.grow(-inset))
