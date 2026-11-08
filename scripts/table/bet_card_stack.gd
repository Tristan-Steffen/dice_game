class_name BetCardStack
extends Node3D
## Der Gewinn einer Karten-Wette in ihrer Grube: JEDE Karte liegt einzeln da, mit
## ihrem schon feststehenden Prägenetz, leicht gefächert übereinander. Der Ursprung
## ist der Glaspunkt des Plots - die Hebebühne fährt den Stapel als EINEN Körper.

## Wie weit eine Karte die nächste höchstens freigibt (Anteil der Kartenlänge).
const FAN_MAX_SHARE := 0.22
## Luft zwischen zwei gestapelten Karten über ihrer Dicke.
const LAYER_AIR := 0.02

var cards: Array[DataCellView] = []
var packs: Array[Pack] = []

func _init() -> void:
	name = "BetCardStack"

## Baut je Paket eine Karte; fan_span = die Plot-Länge in Welt (Bild-waagerecht = +Z).
func setup(card_packs: Array[Pack], fan_span: float) -> void:
	packs = card_packs.duplicate()
	var cell_scale := PackDrawerView.CASSETTE_SCALE
	var length := DataCellView.HEIGHT * cell_scale
	var count := packs.size()
	var step := 0.0
	if count > 1:
		step = clampf((fan_span - length) / float(count - 1), 0.0, length * FAN_MAX_SHARE)
	var lift := DataCellView.lying_over(cell_scale) + LAYER_AIR
	for i in count:
		var pack := packs[i]
		var cell := DataCellView.new()
		add_child(cell)
		cell.setup(Pack.shelf_of(pack), pack.tier, pack.stamp_net, pack.is_repair(),
			pack.from_blank())
		cell.rotation.y = -PI / 2.0  # Bildschirm-oben = Welt+X, wie jede liegende Karte
		cell.badge_on_face = true
		cell.set_count(1)
		cell.set_body_scale(cell_scale)
		cell.position = Vector3(0.0, float(i) * lift,
			(float(i) - float(count - 1) * 0.5) * step)
		cell.set_layer_depth(i)
		cards.append(cell)

## Wie hoch der Stapel über dem Glas aufragt - der Schacht muß ihn ganz schlucken.
func body_height() -> float:
	var lift := DataCellView.lying_over(PackDrawerView.CASSETTE_SCALE) + LAYER_AIR
	return DataCellView.DEPTH * PackDrawerView.CASSETTE_SCALE \
		+ float(maxi(cards.size() - 1, 0)) * lift

func seat_hard(at: Vector3) -> void:
	global_position = at

func materialize() -> void:
	for cell in cards:
		cell.materialize()

func flare() -> void:
	for cell in cards:
		cell.flare()

func set_hovered(on: bool) -> void:
	for cell in cards:
		cell.set_hovered(on)
