class_name DieInspectorView
extends Control
## Modales Vorschau-Overlay für einen einzelnen Würfel: erscheint über allem
## anderen, dimmt den Hintergrund ab und zeigt den Würfel groß und frei
## drehbar (siehe RotatableDieView, das hier mit nur einem Würfel benutzt
## wird). Wird von scene_root.gd geöffnet, sobald im gezoomten Pool-/
## Ablage-Tray auf einen sichtbaren Würfel geklickt wird.
##
## Schließt sich bei Klick auf den abgedunkelten Hintergrund, bei erneutem
## Klick auf den Würfel (ohne Ziehen - siehe RotatableDieView.die_clicked)
## oder per Rechtsklick. Rechtsklick läuft über _input() statt _gui_input(),
## damit er auch dann greift, wenn er direkt auf dem Würfel-Viewport landet
## (der selbst nur Linksklicks auswertet) - und markiert das Event als
## behandelt, damit währenddessen nicht gleichzeitig die Kamera rauszoomt.

@onready var backdrop: ColorRect = $Backdrop
@onready var die_view: RotatableDieView = $Center/DieView

func _ready() -> void:
	visible = false
	backdrop.gui_input.connect(_on_backdrop_input)
	die_view.die_clicked.connect(_on_die_clicked)

func show_die(def: DieDefinition) -> void:
	die_view.set_dice([def])
	visible = true

func close() -> void:
	visible = false

func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()

func _on_die_clicked(_index: int) -> void:
	close()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		close()
		get_viewport().set_input_as_handled()
