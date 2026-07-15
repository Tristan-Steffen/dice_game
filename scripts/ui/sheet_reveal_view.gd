class_name SheetRevealView
extends Control
## Enthüllungs-Overlay eines gekauften Coupon-Bogens: abgedunkelter
## Hintergrund + Titel + Bogen (CouponSheetView). Ein Klick startet die
## Abschluss-Animation: Geld-Coupons fliegen zum Geldzähler oben links
## (money_coupon_redeemed je Stück), Ätzungen zu Zählern rechts
## (etching_redeemed - hier landen sie endgültig im Inventar), Werbeflächen
## verblassen. Der Besitzer (scene_root) verbucht die Gutschriften.

signal money_coupon_redeemed
signal etching_redeemed(coupon: Coupon)

const MONEY_TARGET := Vector2(72, 148)  # Bildschirmziel der Geld-Coupons (Geldzähler)
const COUNTER_X := 980.0  # linke Kante der Ätzungs-Zähler rechts
const COUNTER_TOP := 250.0
const COUNTER_ROW := 48.0
const SEPARATE_TIME := 0.28
const FLY_TIME := 0.45
const STAGGER := 0.05

const KIND_NAMES := {
	CouponSheet.Kind.SNIPPET: "Schnipsel",
	CouponSheet.Kind.SHEET: "Bogen",
	CouponSheet.Kind.LARGE: "Großbogen",
	CouponSheet.Kind.POSTER: "Plakat",
	CouponSheet.Kind.JUMBO: "Riesenbogen",
}

## Laufender Zähler einer Ätzungs-Sorte während der Abschluss-Animation.
class EtchCounter:
	extends RefCounted

	var label: Label
	var count: int = 0
	var target: Vector2  # Flugziel der Kacheln

var backdrop: ColorRect
var sheet_view: CouponSheetView
var title_label: Label
var animating: bool = false  # Klicks während der Abschluss-Animation ignorieren
var _anim_nodes: Array[Node] = []  # temporäre Animations-Nodes, am Ende freigegeben

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	backdrop = ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.gui_input.connect(_on_backdrop_input)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(column)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	CasinoStyle.style_score_label(title_label, 24, CasinoStyle.GOLD)
	column.add_child(title_label)

	sheet_view = CouponSheetView.new()
	sheet_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# IGNORE: ein Klick auf den Bogen selbst fällt zum Backdrop durch und
	# startet die Abschluss-Animation.
	sheet_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(sheet_view)

## Zeigt einen gekauften Bogen. Die Zellgröße schrumpft bei großen Bögen,
## damit auch ein Riesenbogen samt Titel auf den Schirm passt.
func show_reveal(sheet: CouponSheet, kind: int) -> void:
	title_label.text = "%s (%d×%d)" % [KIND_NAMES.get(kind, "Bogen"), sheet.cols, sheet.rows]
	var cell_px := minf(120.0, 640.0 / float(maxi(sheet.cols, sheet.rows)))
	sheet_view.show_sheet(sheet, cell_px)
	visible = true

func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not animating:
			_play_finish_animation()

## Abschluss-Animation: alle Kacheln lösen sich vom Bogen und fliegen
## gestaffelt an ihre Ziele; danach wird aufgeräumt und geschlossen.
func _play_finish_animation() -> void:
	animating = true
	var views: Array[CouponSheetView.TileView] = sheet_view.tile_views.duplicate()

	# Streuzentrum = Mittel der Kachelmitten.
	var center := Vector2.ZERO
	for view in views:
		center += view.node.global_position + view.node.size * 0.5
	if not views.is_empty():
		center /= float(views.size())

	# Rest des Bogens ausblenden, Hintergrund aufhellen (Geldzähler sichtbar).
	var dim := create_tween()
	dim.set_parallel(true)
	dim.tween_property(sheet_view, "modulate:a", 0.0, 0.22)
	dim.tween_property(title_label, "modulate:a", 0.0, 0.22)
	dim.tween_property(backdrop, "color:a", 0.18, 0.3)

	# Kacheln in die Overlay-Ebene umhängen (Position bleibt).
	for view in views:
		view.node.reparent(self, true)
		view.node.pivot_offset = view.node.size * 0.5
		_anim_nodes.append(view.node)

	# Zähler je Ätzungstyp rechts (Reihenfolge des ersten Auftretens).
	var etch_counters := {}  # display_name -> EtchCounter
	for view in views:
		if view.tile.kind != CouponSheet.TileKind.ETCHING:
			continue
		var nm: String = view.tile.coupon.display_name
		if etch_counters.has(nm):
			continue
		var label := Label.new()
		label.position = Vector2(COUNTER_X, COUNTER_TOP + etch_counters.size() * COUNTER_ROW)
		label.text = "%s  ×0" % nm
		CasinoStyle.style_chip_label(label, 20, CasinoStyle.GREEN)
		label.modulate.a = 0.0
		add_child(label)
		_anim_nodes.append(label)
		var counter := EtchCounter.new()
		counter.label = label
		counter.target = label.position + Vector2(150, 14)
		etch_counters[nm] = counter
		var appear := create_tween()
		appear.tween_property(label, "modulate:a", 1.0, 0.3)

	# Jede Kachel: erst nach außen lösen, dann ans Ziel fliegen. Bei großen
	# Bögen schrumpft der Stagger, damit die Gesamtdauer gedeckelt bleibt.
	var stagger := minf(STAGGER, 2.5 / float(maxi(1, views.size())))
	var last_end := 0.0
	for idx in views.size():
		var view: CouponSheetView.TileView = views[idx]
		var node: Control = view.node
		var home := node.position + node.size * 0.5
		var out_dir := (home - center).normalized() if home.distance_to(center) > 1.0 else Vector2.UP
		var scattered := node.position + out_dir * 46.0
		var delay := idx * stagger

		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_property(node, "position", scattered, SEPARATE_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		match view.tile.kind:
			CouponSheet.TileKind.MONEY:
				tw.tween_property(node, "position", MONEY_TARGET - node.size * 0.5, FLY_TIME) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tw.parallel().tween_property(node, "scale", Vector2(0.18, 0.18), FLY_TIME)
				tw.parallel().tween_property(node, "modulate:a", 0.0, FLY_TIME)
				tw.tween_callback(money_coupon_redeemed.emit)
			CouponSheet.TileKind.ETCHING:
				var counter: EtchCounter = etch_counters[view.tile.coupon.display_name]
				tw.tween_property(node, "position", counter.target - node.size * 0.5, FLY_TIME) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				tw.parallel().tween_property(node, "scale", Vector2(0.28, 0.28), FLY_TIME)
				tw.parallel().tween_property(node, "modulate:a", 0.0, FLY_TIME)
				tw.tween_callback(_redeem_etching.bind(view.tile.coupon, counter))
			_:  # AD: Werbefläche verblasst einfach
				tw.tween_property(node, "scale", Vector2(0.7, 0.7), 0.3)
				tw.parallel().tween_property(node, "modulate:a", 0.0, 0.3)

		last_end = maxf(last_end, delay + SEPARATE_TIME + FLY_TIME)

	var finish := create_tween()
	finish.tween_interval(last_end + 0.25)
	finish.tween_callback(_cleanup_animation)

## Eine Ätzung ist am Zähler angekommen: gutschreiben lassen, hochzählen, pulsen.
func _redeem_etching(coupon: Coupon, counter: EtchCounter) -> void:
	etching_redeemed.emit(coupon)
	counter.count += 1
	counter.label.text = "%s  ×%d" % [coupon.display_name, counter.count]
	_pulse(counter.label)

## Temporäre Nodes freigeben, Overlay schließen, für den nächsten Kauf zurücksetzen.
func _cleanup_animation() -> void:
	for node in _anim_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_anim_nodes.clear()
	visible = false
	sheet_view.modulate.a = 1.0
	title_label.modulate.a = 1.0
	backdrop.color.a = 0.6
	animating = false

## Kurzer elastischer Größen-Puls (Arcade-Pop).
func _pulse(control: Control) -> void:
	control.pivot_offset = control.size / 2.0
	control.scale = Vector2(1.4, 1.4)
	var pulse := create_tween()
	pulse.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pulse.tween_property(control, "scale", Vector2.ONE, 0.35)
