class_name PcbDeckView
extends Node2D
## Das Deck als PLATINE: malt aus den Möbel-Rechtecken (Display-Pixel) Massefläche, Freistellung,
## Tochterkarte, unbestückte BGA-Felder und Bestückungsdruck. Leiterzüge trägt es keine - jede
## Verbindung ist eine Licht-Ader (LedStripView), auf der etwas fährt.
## TableScreen backt das Bild einmal und reicht es table_pcb.gdshader.

const PITCH := 13.0
const WIDTH := 5.0
const KEEP := 16.0
const SQ := 0.5858  # 2 - Wurzel 2: Eckschnitt je Versatz
const GHOST_SIZE := Vector2(250, 250)

const LACQUER := Color(0.014, 0.058, 0.048)
const POUR := Color(0.024, 0.096, 0.074)
const MOAT := Color(0.008, 0.035, 0.029)
const GOLD := Color(0.5, 0.385, 0.16)
const SILK := Color(0.5, 0.56, 0.52, 0.75)
const HOLE := Color(0.004, 0.012, 0.012)
## Bauteile mit eigener Art stehen für sich und tragen ihr eigenes Bild.
const KIND_CARD := "card"        # Tochterkarte: die ROM-Bank der Kombinationen
const KIND_SOCKET := "socket"    # CPU-Sockel: die Wurfgrube
const KIND_DISPLAY := "display"  # Anzeige-Modul: die Wertung
const KIND_HUB := "hub"          # der Hub
const KIND_MARKET := "market"    # der Schwarzmarkt: ein Bauteil mit eigenem Körper
## Diese Bauteile tragen ihre eigene 3D-Fassung: das Deck malt unter ihnen kein Feld und keinen Druck.
const STANDING := [KIND_SOCKET, KIND_DISPLAY, KIND_HUB, KIND_MARKET]

var board := Rect2()
var comps: Array[Rect2] = []
var names: Array[String] = []
var kinds: Array[String] = []
## Korridore der Licht-Adern: dort liegt kein BGA-Feld.
var reserved: Array[Rect2] = []
## Gruben mit eigener Fassung (das Magazin): kein Bestückungsdruck um ihr Bauteil.
var bare: Array[Rect2] = []

var _ghosts := 0  # die letzten n Einträge von comps sind unbestückte BGA-Felder

## Der Eckschnitt eines Bündels mit halber Breite half - Adern und Kometen schneiden gleich.
static func chamfer(half: float) -> float:
	return half * SQ + 12.0

## Ein Zug: path um offset versetzt, Ecken zwischen langen Stücken unter 45 Grad geschnitten.
static func track_line(path: PackedVector2Array, offset: float, half: float) -> PackedVector2Array:
	var line := PackedVector2Array()
	var last := path.size() - 1
	if last < 1:
		return line
	var base := chamfer(half)
	for i in path.size():
		if i == 0 or i == last:
			var d := (path[1] - path[0]) if i == 0 else (path[last] - path[last - 1])
			line.append(path[i] + d.normalized().rotated(PI * 0.5) * offset)
			continue
		var d0 := (path[i] - path[i - 1]).normalized()
		var d1 := (path[i + 1] - path[i]).normalized()
		if d0.dot(d1) > 0.99 or d0.dot(d1) < -0.99:
			continue
		var shift := (d0.rotated(PI * 0.5) + d1.rotated(PI * 0.5)) * offset
		var q := path[i] + shift
		var room := minf(path[i].distance_to(path[i - 1]), path[i].distance_to(path[i + 1]))
		if room < base * 2.4:
			line.append(q)
			continue
		var inside := 1.0 if shift.dot(d1 - d0) > 0.0 else -1.0
		var cut := base - inside * absf(offset) * SQ
		line.append(q - d0 * cut)
		line.append(q + d1 * cut)
	return line

## Setzt die BGA-Felder neu (deterministisch aus den Rechtecken) und malt.
func plan() -> void:
	_place_ghosts()
	queue_redraw()

func _gap(a: Rect2, b: Rect2) -> float:
	var dx := maxf(maxf(a.position.x - b.end.x, b.position.x - a.end.x), 0.0)
	var dy := maxf(maxf(a.position.y - b.end.y, b.position.y - a.end.y), 0.0)
	return dx + dy

## Unbestückte BGA-Felder in den größten freien Flächen.
func _place_ghosts() -> void:
	comps.resize(comps.size() - _ghosts)
	names.resize(comps.size())
	kinds.resize(comps.size())
	_ghosts = 0
	for round_index in 4:
		var best := Vector2.ZERO
		var best_room := 150.0
		var y := board.position.y + 260.0
		while y < board.end.y - 260.0:
			var x := board.position.x + 260.0
			while x < board.end.x - 260.0:
				var probe := Rect2(Vector2(x, y) - GHOST_SIZE * 0.5, GHOST_SIZE)
				var room := 99999.0
				for rect in comps:
					room = minf(room, _gap(probe, rect))
				for rect in reserved:
					room = minf(room, _gap(probe, rect) + 100.0)
				if room > best_room:
					best_room = room
					best = Vector2(x, y)
				x += 90.0
			y += 90.0
		if best == Vector2.ZERO:
			return
		comps.append(Rect2(best - GHOST_SIZE * 0.5, GHOST_SIZE))
		names.append("BGA")
		kinds.append("")
		_ghosts += 1

func _draw() -> void:
	draw_rect(board, POUR)
	# Freistellung nur am Rand der Platine: um die Möbel bleibt die Massefläche.
	draw_rect(board.grow(-14.0), LACQUER * 0.7, false, 28.0)
	_draw_stitching()
	for i in range(comps.size() - _ghosts, comps.size()):
		_draw_bga(comps[i])
	_draw_mounts()
	_draw_silk()

func _draw_stitching() -> void:
	var inner := board.grow(-58.0)
	var dim := Color(GOLD.r * 0.6, GOLD.g * 0.6, GOLD.b * 0.6)
	var spots: Array[Vector2] = []
	var x := inner.position.x
	while x <= inner.end.x:
		spots.append(Vector2(x, inner.position.y))
		spots.append(Vector2(x, inner.end.y))
		x += 96.0
	var y := inner.position.y + 96.0
	while y < inner.end.y:
		spots.append(Vector2(inner.position.x, y))
		spots.append(Vector2(inner.end.x, y))
		y += 96.0
	for at in spots:
		draw_circle(at, 4.5, dim)
		draw_circle(at, 1.8, HOLE)

func _draw_mounts() -> void:
	var inner := board.grow(-120.0)
	for at: Vector2 in [inner.position, Vector2(inner.end.x, inner.position.y), inner.end,
			Vector2(inner.position.x, inner.end.y)]:
		var free := true
		for rect in comps:
			if rect.grow(60.0).has_point(at):
				free = false
		if free:
			draw_circle(at, 40.0, LACQUER * 0.7)
			draw_circle(at, 33.0, GOLD)
			draw_circle(at, 19.0, HOLE)

func _draw_bga(rect: Rect2) -> void:
	var inner := rect.grow(-22.0)
	for iy in 10:
		for ix in 10:
			draw_circle(inner.position + inner.size * Vector2(float(ix) / 9.0, float(iy) / 9.0),
				6.0, GOLD)

func _kind(index: int) -> String:
	return kinds[index] if index < kinds.size() else ""

## Bestückungs-Winkel an den vier Ecken; gibt die Schenkellänge zurück.
func _silk_corners(rect: Rect2) -> float:
	var arm := minf(26.0, minf(rect.size.x, rect.size.y) * 0.2)
	for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
		var at := rect.position + rect.size * corner
		draw_line(at, at + Vector2(arm * (1.0 - corner.x * 2.0), 0), SILK, 3.0)
		draw_line(at, at + Vector2(0, arm * (1.0 - corner.y * 2.0)), SILK, 3.0)
	return arm

func _is_bare(rect: Rect2) -> bool:
	for pit in bare:
		if rect.intersects(pit):
			return true
	return false

func _draw_silk() -> void:
	var font := ThemeDB.fallback_font
	var cards := 0
	for i in comps.size():
		if _kind(i) == KIND_CARD:
			cards += 1
			_silk_corners(comps[i])
			draw_string(font, comps[i].position + Vector2(14.0, -12.0),
				"A%d  %s" % [cards, names[i]], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20, SILK)
			continue
		if _kind(i) in STANDING or _is_bare(comps[i]):
			continue
		var rect := comps[i].grow(KEEP + 4.0)
		var arm := _silk_corners(rect)
		draw_circle(rect.position + Vector2(-9.0, rect.size.y + 9.0), 4.5, SILK)
		if i < names.size() and names[i] != "":
			draw_string(font, rect.position + Vector2(arm + 8.0, -7.0),
				"U%d %s" % [i + 1, names[i]], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, SILK)
