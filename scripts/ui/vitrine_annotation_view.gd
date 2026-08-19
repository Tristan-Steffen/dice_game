class_name VitrineAnnotationView
extends PanelContainer
## Die BESCHRIFTUNG eines Vitrinen-Stücks - EINE Karte, verankert über dem Stück
## und in die Buchtfläche geklemmt. Sie liegt auf der SCHEIBE, nicht im Raum:
## alles, was das Spiel sagt, sagt es auf einer Anzeige.
## Inhalt und Reihenfolge sind die des alten Laden-Tooltips (Titel, Wirkung mit
## Lexikon-Verweisen, Würfelnetz, Preiszeile in price_tint) - neu ist allein, wo
## sie steht. In der Bucht selbst hängt kein Preisschild: die Schalen-Regel
## ("Hinsehen nennt den Preis") gilt jetzt für den ganzen Laden.

## Ein Schlüsselwort wurde geklickt - der Laden reicht es ans Lexikon weiter.
signal lexikon_requested(entry_id: String)

## Luft zwischen Stück und Karte, und der Rand, den sie zur Buchtkante hält.
const ANCHOR_GAP := 1.0
const FIELD_MARGIN := 0.8
## Breite der Karte in Einheiten - schmal genug, dass sie neben einem Stück in
## der Bucht Platz lässt, breit genug für eine Wirkungszeile ohne Silbensalat.
const WIDTH := 34.0

var title_label: Label
var body_label: RichTextLabel
var net_stage: CenterContainer
var price_label: Label

var _u := 8.0

func _init() -> void:
	name = "VitrineAnnotation"
	visible = false
	# STOP: die Schlüsselwörter sind Klickziele, die Karte fängt sie ein.
	mouse_filter = Control.MOUSE_FILTER_STOP

func _ready() -> void:
	if title_label == null:
		build(_u)

## Baut die Karte im gegebenen Einheitsmaß. Idempotent - ein zweiter Ruf setzt
## nur die Maße nach.
func build(unit: float) -> void:
	_u = maxf(unit, 1.0)
	if title_label != null and is_instance_valid(title_label):
		_apply_metrics()
		return
	CasinoStyle.style_panel(self)
	custom_minimum_size = Vector2(_u * WIDTH, 0.0)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", int(_u * 0.4))
	add_child(box)

	title_label = Label.new()
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title_label)

	body_label = RichTextLabel.new()
	body_label.bbcode_enabled = true
	body_label.fit_content = true
	body_label.scroll_active = false
	# STOP, nicht PASS: die Karte liegt in keinem Knopf, es gibt nichts weiterzureichen.
	body_label.mouse_filter = Control.MOUSE_FILTER_STOP
	body_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	body_label.meta_clicked.connect(_on_meta_clicked)
	box.add_child(body_label)

	net_stage = CenterContainer.new()
	net_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	net_stage.visible = false
	box.add_child(net_stage)

	price_label = Label.new()
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_label.visible = false
	box.add_child(price_label)
	_apply_metrics()

func _apply_metrics() -> void:
	custom_minimum_size = Vector2(_u * WIDTH, 0.0)
	CasinoStyle.style_score_label(title_label, maxi(8, int(_u * 2.6)), CasinoStyle.GOLD)
	CasinoStyle.style_rich_body(body_label, maxi(8, int(_u * 1.9)))
	body_label.custom_minimum_size = Vector2(_u * (WIDTH - 4.0), 0.0)
	CasinoStyle.style_score_label(price_label, maxi(8, int(_u * 2.2)), CasinoStyle.GOLD)

## Zeigt die Auskunft eines Stücks. data kommt vom Laden (vitrine_annotation):
## title, body, price (-1 = keiner), money, net (DieDefinition oder null),
## blocked (Text statt Preis, etwa "MAGAZIN VOLL") und charge (Preis in ⚡ statt
## in $ - das Hinterzimmer zahlt in Energie, die Kaufbarkeits-Färbung bleibt).
func show_item(data: Dictionary, unit: float) -> void:
	build(unit)
	title_label.text = String(data.get("title", ""))
	# EIN Engpass für die Schlüsselwörter - wie im Laden-Tooltip.
	body_label.text = Lexikon.linkify(String(data.get("body", "")))
	for child in net_stage.get_children():
		net_stage.remove_child(child)
		child.queue_free()
	var net_def: DieDefinition = data.get("net")
	net_stage.visible = net_def != null
	if net_def != null:
		net_stage.add_child(DieNetView.build(net_def, -1, _u * 2.2))
	var blocked := String(data.get("blocked", ""))
	var price := int(data.get("price", -1))
	price_label.visible = blocked != "" or price >= 0
	if blocked != "":
		price_label.text = blocked
		price_label.add_theme_color_override("font_color", CasinoStyle.RED)
	elif price >= 0:
		price_label.text = ("⚡ %d" % price) if bool(data.get("charge", false)) \
			else ShopController.price_text(price)
		price_label.add_theme_color_override("font_color",
			ShopController.price_tint(price, int(data.get("money", 0))))
	visible = true
	reset_size()

func hide_card() -> void:
	visible = false

## Setzt die Karte über den Ankerpunkt (Buchten-lokale Pixel) und klemmt sie in
## die Buchtfläche - nach unten, wenn oben kein Platz ist. Die Bucht ist flach,
## also darf sie in beide Richtungen ausweichen.
func place_over(anchor: Vector2, field: Vector2) -> void:
	reset_size()
	var gap := _u * ANCHOR_GAP
	var margin := _u * FIELD_MARGIN
	var above := anchor.y - size.y - gap
	var below := anchor.y + gap
	var pos := Vector2(anchor.x - size.x * 0.5, above)
	if above < margin:
		pos.y = below
	pos.x = clampf(pos.x, margin, maxf(margin, field.x - size.x - margin))
	pos.y = clampf(pos.y, margin, maxf(margin, field.y - size.y - margin))
	position = pos

func _on_meta_clicked(meta: Variant) -> void:
	lexikon_requested.emit(String(meta))
