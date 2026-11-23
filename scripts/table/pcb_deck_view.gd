class_name PcbDeckView
extends Node2D
## Das Deck als GEROUTETE PLATINE: malt aus den Möbel-Rechtecken (Display-Pixel) Massefläche,
## Leiterzug-Bündel mit 45-Grad-Ecken, Pads, Durchkontaktierungen und Bestückungsdruck.
## TableScreen backt das Bild einmal und reicht es table_pcb.gdshader.

const PITCH := 13.0
const WIDTH := 5.0
const KEEP := 16.0
const SQ := 0.5858  # 2 - Wurzel 2: Eckschnitt je Versatz
const GHOST_SIZE := Vector2(250, 250)

const LACQUER := Color(0.014, 0.058, 0.048)
const POUR := Color(0.024, 0.096, 0.074)
const TRACE := Color(0.031, 0.125, 0.096)
const MOAT := Color(0.008, 0.035, 0.029)
const GOLD := Color(0.5, 0.385, 0.16)
const SILK := Color(0.5, 0.56, 0.52, 0.75)
const HOLE := Color(0.004, 0.012, 0.012)

var board := Rect2()
var comps: Array[Rect2] = []
var names: Array[String] = []
## Korridore der Licht-Adern: dort liegt kein Deko-Zug.
var reserved: Array[Rect2] = []

var _bundles: Array[Dictionary] = []  # {pts, n, open}
var _tails: Array[Dictionary] = []    # {from, dir, n, length}
var _used: Array[Rect2] = []
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

## Rechnet das Routing neu (deterministisch aus den Rechtecken) und malt.
func plan() -> void:
	_bundles.clear()
	_tails.clear()
	_used.clear()
	_used.append_array(reserved)
	_place_ghosts()
	var pairs: Array = []
	var seen := {}
	for i in comps.size():
		var near: Array = []
		for j in comps.size():
			if i != j:
				near.append([_gap(comps[i], comps[j]), j])
		near.sort_custom(func(a, b): return a[0] < b[0])
		for k in mini(3, near.size()):
			var j: int = near[k][1]
			var key := "%d_%d" % [mini(i, j), maxi(i, j)]
			if not seen.has(key):
				seen[key] = true
				pairs.append([near[k][0], i, j])
	pairs.sort_custom(func(a, b): return a[0] < b[0])
	for pair in pairs:
		var n := 4 + (int(pair[1]) * 31 + int(pair[2])) % 6
		while n >= 3 and not _route(pair[1], pair[2], n):
			n -= 2
	for i in comps.size():
		_plan_runs(i)
	for i in comps.size():
		_plan_tails(i)
	queue_redraw()

func bundle_count() -> int:
	return _bundles.size()

func _gap(a: Rect2, b: Rect2) -> float:
	var dx := maxf(maxf(a.position.x - b.end.x, b.position.x - a.end.x), 0.0)
	var dy := maxf(maxf(a.position.y - b.end.y, b.position.y - a.end.y), 0.0)
	return dx + dy

func _half(n: int) -> float:
	return float(n - 1) * PITCH * 0.5

## Unbestückte BGA-Felder in den größten freien Flächen: Ziele für lange Bündel.
func _place_ghosts() -> void:
	comps.resize(comps.size() - _ghosts)
	names.resize(comps.size())
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
		_ghosts += 1

## Anschlüsse einer Seite: Punkt und Normale nach außen.
func _ports(rect: Rect2, toward: Vector2, half: float) -> Array:
	var out: Array = []
	for side in [[Vector2(0, -1), true], [Vector2(0, 1), true], [Vector2(-1, 0), false],
			[Vector2(1, 0), false]]:
		var normal: Vector2 = side[0]
		var along: bool = side[1]
		var length := rect.size.x if along else rect.size.y
		if length < half * 2.0 + 30.0:
			continue
		var low := (rect.position.x if along else rect.position.y) + half + 15.0
		var high := low + length - half * 2.0 - 30.0
		for s: float in [lerpf(low, high, 0.5), lerpf(low, high, 0.2), lerpf(low, high, 0.8),
				clampf(toward.x if along else toward.y, low, high)]:
			var p := Vector2(s, rect.position.y if normal.y < 0.0 else rect.end.y) if along \
				else Vector2(rect.position.x if normal.x < 0.0 else rect.end.x, s)
			out.append([p, normal])
	return out

func _route(a: int, b: int, n: int) -> bool:
	var half := _half(n)
	var stub := half + KEEP + 22.0
	var cands: Array = []
	for pa in _ports(comps[a], comps[b].get_center(), half):
		for pb in _ports(comps[b], comps[a].get_center(), half):
			var e1: Vector2 = pa[0] + pa[1] * stub
			var e2: Vector2 = pb[0] + pb[1] * stub
			var mids: Array = [[], [Vector2(e2.x, e1.y)], [Vector2(e1.x, e2.y)]]
			for f: float in [0.5, 0.25, 0.75]:
				var mx := lerpf(e1.x, e2.x, f)
				var my := lerpf(e1.y, e2.y, f)
				mids.append([Vector2(mx, e1.y), Vector2(mx, e2.y)])
				mids.append([Vector2(e1.x, my), Vector2(e2.x, my)])
			for mid: Array in mids:
				var pts: Array[Vector2] = [pa[0], e1]
				for m: Vector2 in mid:
					pts.append(m)
				pts.append(e2)
				pts.append(pb[0])
				pts = _clean(pts)
				var score := _score(pts, pa[1], pb[1], n)
				if score >= 0.0:
					cands.append([score, pts])
	cands.sort_custom(func(x, y): return x[0] < y[0])
	for cand in cands.slice(0, 400):
		var rects := _swept(cand[1], half)
		if _clear(rects, a, b):
			_used.append_array(rects)
			_bundles.append({"pts": cand[1], "n": n, "open": false})
			return true
	return false

func _clean(pts: Array[Vector2]) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p in pts:
		if out.is_empty() or out[-1].distance_to(p) > 0.5:
			out.append(p)
	var i := 1
	while i < out.size() - 1:
		var d0 := (out[i] - out[i - 1]).normalized()
		var d1 := (out[i + 1] - out[i]).normalized()
		if d0.dot(d1) > 0.99:
			out.remove_at(i)
		else:
			i += 1
	return out

## Länge plus Ecken-Strafe; -1 = unbrauchbar (U-Bogen, mehr als zwei Ecken, zu kurze Stücke).
func _score(pts: Array[Vector2], na: Vector2, nb: Vector2, n: int) -> float:
	if pts.size() < 2 or pts.size() > 4 or na.dot(nb) > 0.9:
		return -1.0
	var need := chamfer(_half(n)) + _half(n) * SQ + 3.0
	var total := 0.0
	for i in pts.size() - 1:
		var seg := pts[i + 1] - pts[i]
		if absf(seg.x) > 0.5 and absf(seg.y) > 0.5:
			return -1.0
		var ends := (0 if i == 0 else 1) + (0 if i == pts.size() - 2 else 1)
		if seg.length() < need * float(ends) + 6.0:
			return -1.0
		if i > 0 and seg.normalized().dot((pts[i] - pts[i - 1]).normalized()) < -0.5:
			return -1.0
		total += seg.length()
	if (pts[1] - pts[0]).normalized().dot(na) < 0.9:
		return -1.0
	if (pts[-2] - pts[-1]).normalized().dot(nb) < 0.9:
		return -1.0
	return total + 450.0 * float(pts.size() - 2)

func _swept(pts: Array[Vector2], half: float) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for i in pts.size() - 1:
		out.append(Rect2(pts[i], Vector2.ZERO).expand(pts[i + 1]).grow(half + WIDTH + 5.0))
	return out

func _clear(rects: Array[Rect2], a: int, b: int) -> bool:
	var inner := board.grow(-50.0)
	for i in rects.size():
		var r := rects[i]
		if not inner.encloses(r):
			return false
		for c in comps.size():
			if (i == 0 and c == a) or (i == rects.size() - 1 and c == b):
				continue
			if comps[c].grow(KEEP).intersects(r):
				return false
		for u in _used:
			if u.intersects(r):
				return false
	return true

## Lange Bündel von einem Möbel an den Platinenrand, gerade oder mit EINEM Versatz.
func _plan_runs(index: int) -> void:
	var n := 5 + (index * 17 + 5) % 6
	var half := _half(n)
	var reach := 52.0 + half + WIDTH + 8.0
	var placed := 0
	for port in _ports(comps[index], board.get_center(), half):
		if placed >= 3:
			return
		var p: Vector2 = port[0]
		var normal: Vector2 = port[1]
		var far := 0.0
		if normal.x != 0.0:
			far = (board.end.x - p.x if normal.x > 0.0 else p.x - board.position.x) - reach
		else:
			far = (board.end.y - p.y if normal.y > 0.0 else p.y - board.position.y) - reach
		if far < 260.0:
			continue
		var tangent := normal.rotated(PI * 0.5)
		for jog: float in [0.0, 170.0, -170.0]:
			var first := far * (0.3 + 0.1 * float((index + placed) % 4))
			var pts: Array[Vector2] = [p, p + normal * first]
			if jog != 0.0:
				pts.append(p + normal * first + tangent * jog)
			pts.append(p + normal * far + tangent * jog)
			pts = _clean(pts)
			if _score(pts, normal, -normal, n) < 0.0:
				continue
			var rects := _swept(pts, half)
			if _clear(rects, index, -1):
				_used.append_array(rects)
				_bundles.append({"pts": pts, "n": n, "open": true})
				placed += 1
				break

## Kurze Bündel ins Freie, die in versetzten Durchkontaktierungen enden.
func _plan_tails(index: int) -> void:
	var placed := 0
	var n := 3 + (index * 7 + 3) % 5
	var half := _half(n)
	for port in _ports(comps[index], board.get_center(), half):
		if placed >= 2:
			return
		var length := 90.0 + float((index * 13 + placed * 41) % 110)
		var p: Vector2 = port[0]
		var tip: Vector2 = p + port[1] * (length + 14.0)
		var sweep: Array[Rect2] = [Rect2(p + port[1] * (KEEP + 2.0), Vector2.ZERO).expand(tip)
			.grow(half + WIDTH + 5.0)]
		if _clear(sweep, -1, -1):
			_used.append_array(sweep)
			_tails.append({"from": p, "dir": port[1], "n": n, "length": length})
			placed += 1

func _draw() -> void:
	draw_rect(board, POUR)
	# Freistellung: Rand der Platine und ein Graben um jedes Möbel.
	draw_rect(board.grow(-14.0), LACQUER * 0.7, false, 28.0)
	for i in comps.size() - _ghosts:
		draw_rect(comps[i].grow(KEEP - 4.0), LACQUER * 0.7)
	_draw_stitching()
	for moat in [true, false]:
		var color := MOAT if moat else TRACE
		var width := WIDTH + 9.0 if moat else WIDTH
		for bundle in _bundles:
			_draw_bundle(bundle["pts"], bundle["n"], color, width, not moat, bundle["open"])
		for tail in _tails:
			_draw_tail(tail, color, width, not moat)
	for i in range(comps.size() - _ghosts, comps.size()):
		_draw_bga(comps[i])
	_draw_mounts()
	_draw_silk()

func _draw_bundle(pts: Array[Vector2], n: int, color: Color, width: float, pads: bool,
		open: bool) -> void:
	var path := PackedVector2Array(pts)
	for k in n:
		var offset := (float(k) - float(n - 1) * 0.5) * PITCH
		var line := track_line(path, offset, _half(n))
		draw_polyline(line, color, width, true)
		if not pads:
			continue
		_pad(line[0], (line[1] - line[0]).normalized())
		var back := (line[-2] - line[-1]).normalized()
		if open:
			_via(line[-1] + back * (18.0 if k % 2 == 1 else 0.0))
		else:
			_pad(line[-1], back)

func _pad(at: Vector2, dir: Vector2) -> void:
	draw_line(at + dir, at + dir * 15.0, GOLD, WIDTH + 4.0)

func _via(at: Vector2, radius: float = 7.5) -> void:
	draw_circle(at, radius, GOLD)
	draw_circle(at, radius * 0.42, HOLE)

func _draw_tail(tail: Dictionary, color: Color, width: float, pads: bool) -> void:
	var n: int = tail["n"]
	var dir: Vector2 = tail["dir"]
	for k in n:
		var offset := (float(k) - float(n - 1) * 0.5) * PITCH
		var from: Vector2 = tail["from"] + dir.rotated(PI * 0.5) * offset
		var to: Vector2 = from + dir * (float(tail["length"]) - (22.0 if k % 2 == 1 else 0.0))
		draw_line(from, to, color, width, true)
		if pads:
			_pad(from, dir)
			_via(to)

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

func _draw_silk() -> void:
	var font := ThemeDB.fallback_font
	for i in comps.size():
		var rect := comps[i].grow(KEEP + 4.0)
		var arm := minf(26.0, minf(rect.size.x, rect.size.y) * 0.2)
		for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			var at := rect.position + rect.size * corner
			draw_line(at, at + Vector2(arm * (1.0 - corner.x * 2.0), 0), SILK, 3.0)
			draw_line(at, at + Vector2(0, arm * (1.0 - corner.y * 2.0)), SILK, 3.0)
		draw_circle(rect.position + Vector2(-9.0, rect.size.y + 9.0), 4.5, SILK)
		if i < names.size() and names[i] != "":
			draw_string(font, rect.position + Vector2(arm + 8.0, -7.0),
				"U%d %s" % [i + 1, names[i]], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24, SILK)
