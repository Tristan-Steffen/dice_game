class_name ShopController
extends Panel
## Der Shop als eigenständiger Controller auf dem ShopPanel (siehe
## scenes/scene_root.tscn). Übernimmt die komplette Shop-UI und Kauf-Interaktion;
## die Spielzustands-Mutation (Geld, Charms, Pool, Rundenwechsel) bleibt bei
## scene_root, das dem Shop dafür eine schmale API bereitstellt (game.*) und auf
## das closed-Signal reagiert. So wächst scene_root nicht weiter mit, und
## künftige Shop-Kategorien bekommen hier ihren Platz.
##
## Käufe wirken sofort (kein Bestätigen nötig): der Spieler kauft, so viel er
## sich leisten will/kann, und schließt selbst mit "Fertig" ab. Würfel sind
## beliebig oft nachkaufbar, jeder angebotene Charm nur einmal pro Besuch (danach
## besitzt man ihn ja).

## Wird ausgelöst, wenn der Spieler den Shop mit "Fertig" verlässt.
signal closed

const DIE_PRICE := 15  # Preis pro Würfel-Kauf (vor Rabatt-Charms, siehe CharmEffects.die_price)
const CHARM_PRICE := 25  # Preis pro Charm-Kauf

## Vom Besitzer (scene_root) gesetzte Spiel-API (siehe scene_root.gd:
## player_money/owned_charm_ids/purchase_die/purchase_charm). Bewusst untypisiert,
## um keine zyklische class_name-Abhängigkeit mit scene_root zu erzeugen.
var game

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var dice_section_label: Label = $VBoxContainer/DiceSectionLabel
@onready var dice_picker: RotatableDieView = $VBoxContainer/DicePicker
@onready var charm_section_label: Label = $VBoxContainer/CharmSectionLabel
@onready var charm_options_container: HBoxContainer = $VBoxContainer/CharmOptionsContainer
@onready var message_label: Label = $VBoxContainer/ShopMessageLabel
@onready var done_button: Button = $VBoxContainer/DoneButton

var die_options: Array[DieDefinition] = []  # feste Würfel-Kandidaten (Reihenfolge = dice_picker), beliebig oft nachkaufbar
var charm_options: Array[Charm] = []  # Charm-Angebot dieses Besuchs (Reihenfolge = charm_options_container)
var charm_buttons: Array[Button] = []  # dynamisch gebaute Buttons für charm_options
var charm_bought: Array[bool] = []  # welche charm_options in diesem Besuch schon gekauft wurden

func _ready() -> void:
	_style()
	die_options = [
		DieDefinition.fixed(6, "Immer 6"),
		DieDefinition.fixed(5, "Immer 5"),
		DieDefinition.fixed(4, "Immer 4"),
	]
	dice_picker.set_dice(die_options)
	dice_picker.die_clicked.connect(_on_die_clicked)
	done_button.pressed.connect(_on_done_pressed)

## Casino-Look des Shops (siehe CasinoStyle) - der Shop stylt sich selbst, damit
## scene_root._style_ui nichts davon kennen muss.
func _style() -> void:
	CasinoStyle.style_panel(self)
	CasinoStyle.style_score_label(title_label, 22, CasinoStyle.GOLD)
	CasinoStyle.style_chip_label(dice_section_label, 18, CasinoStyle.BLUE)
	CasinoStyle.style_chip_label(charm_section_label, 18, CasinoStyle.PURPLE)
	CasinoStyle.style_body_label(message_label, 15, CasinoStyle.GREEN)
	CasinoStyle.style_button(done_button, CasinoStyle.GOLD, CasinoStyle.GOLD_DARK)

## Öffnet den Shop: Angebot frisch auswürfeln und anzeigen. Sichtbarkeit/
## Spielzustand steuert der Aufrufer (scene_root._on_round_complete).
func open() -> void:
	dice_picker.set_highlighted(-1)
	message_label.text = ""
	# Würfel-Sektionstitel zeigt den (ggf. rabattierten) Effektivpreis.
	dice_section_label.text = "Würfel (je $%d)" % _die_price()
	_populate_charm_options()
	visible = true

## Würfelt die Charm-Angebote dieses Besuchs aus - alle Charm-Archetypen (siehe
## Charm.all), die der Spieler noch nicht besitzt, max. zwei Stück. Baut die
## Charm-Buttons komplett neu auf, da sich das Angebot bei jedem Besuch ändert.
func _populate_charm_options() -> void:
	for button in charm_buttons:
		button.queue_free()
	charm_buttons.clear()

	var owned_ids: Array[String] = game.owned_charm_ids()
	var available: Array[Charm] = []
	for charm in Charm.all():
		if not owned_ids.has(charm.id):
			available.append(charm)
	available.shuffle()

	charm_options = []
	for i in mini(2, available.size()):
		charm_options.append(available[i])
	charm_bought = []
	charm_bought.resize(charm_options.size())
	charm_bought.fill(false)

	charm_section_label.visible = not charm_options.is_empty()
	for i in charm_options.size():
		var charm := charm_options[i]
		var button := Button.new()
		button.text = "%s\n%s\n$%d" % [charm.display_name, charm.description, CHARM_PRICE]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(280, 84)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = charm.description
		button.pressed.connect(_on_charm_clicked.bind(i))
		CasinoStyle.style_button(button, CasinoStyle.PURPLE, CasinoStyle.PURPLE_DARK, 14)
		charm_options_container.add_child(button)
		charm_buttons.append(button)
	_refresh_charm_afford_state()

## Effektiver Würfelpreis nach Rabatt-Charms (Trickdieb-Manschette).
func _die_price() -> int:
	return CharmEffects.die_price(DIE_PRICE, game.owned_charm_ids())

## Kauft eine unabhängige Kopie des angeklickten Würfels in den Pool (siehe
## game.purchase_die) - beliebig oft wiederholbar, solange genug Geld da ist.
func _on_die_clicked(index: int) -> void:
	var def := die_options[index]
	var price := _die_price()
	if game.player_money() < price:
		message_label.text = "Nicht genug Geld für %s ($%d)." % [def.display_name, price]
		return
	game.purchase_die(def, price)
	dice_picker.set_highlighted(index)
	message_label.text = "Gekauft: %s (-$%d)" % [def.display_name, price]
	_refresh_charm_afford_state()

## Kauft den angeklickten Charm sofort (siehe game.purchase_charm) - je Charm
## nur einmal pro Besuch. Der Button ist bei fehlendem Geld schon deaktiviert
## (siehe _refresh_charm_afford_state), Godot liefert für deaktivierte Buttons
## kein pressed-Signal - ein Klick kann hier also nur bei ausreichend Geld ankommen.
func _on_charm_clicked(index: int) -> void:
	if charm_bought[index]:
		return
	var charm := charm_options[index]
	game.purchase_charm(charm, CHARM_PRICE)
	charm_bought[index] = true
	charm_buttons[index].disabled = true
	charm_buttons[index].text = "%s (gekauft)\n%s" % [charm.display_name, charm.description]
	message_label.text = "Gekauft: %s (-$%d)" % [charm.display_name, CHARM_PRICE]
	_refresh_charm_afford_state()

## Deaktiviert alle noch nicht gekauften Charm-Buttons, sobald das Geld für
## CHARM_PRICE nicht mehr reicht - Geld sinkt innerhalb eines Besuchs nur (kein
## Einkommen mittendrin), ein deaktivierter Button muss also nie reaktiviert werden.
func _refresh_charm_afford_state() -> void:
	var can_afford: bool = game.player_money() >= CHARM_PRICE
	for i in charm_buttons.size():
		if not charm_bought[i]:
			charm_buttons[i].disabled = not can_afford

func _on_done_pressed() -> void:
	visible = false
	closed.emit()
