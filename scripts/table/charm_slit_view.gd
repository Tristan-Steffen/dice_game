class_name CharmSlitView
extends Node3D
## Ein SCHLITZ im Laden-Tisch, durch den eine Charm-Diskette hochkant geht (2026-11-20):
## dunkler Spalt mit Lichtsaum knapp über der Anzeige, er geht auf, hält und schließt
## sich selbst. Ursprung = Schlitzmitte auf dem Tisch, lang entlang Welt-Z.

const LENGTH := CharmDiskView.SIZE.z + 0.4
const GAP := CharmDiskView.SIZE.y + 0.16
const RIM := 0.07
const OPEN_TIME := 0.12
const RIM_COLOR := Color(0.25, 0.9, 1.0)
const RIM_ENERGY := 1.3

func _ready() -> void:
	_bar("Saum", Vector3(GAP + RIM * 2.0, 0.004, LENGTH + RIM * 2.0), 0.008,
		CharmDiskView._unshaded(CharmDiskView.energized(RIM_COLOR, RIM_ENERGY)))
	_bar("Spalt", Vector3(GAP, 0.004, LENGTH), 0.014, CharmDiskView._unshaded(Color(0.0, 0.0, 0.0)))
	scale = Vector3(0.001, 1.0, 1.0)

func _bar(part: String, size: Vector3, lift: float, material: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = part
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position.y = lift
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)

## Auf, hold Sekunden offen, zu, fort.
func play(hold: float) -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale:x", 1.0, OPEN_TIME)
	tween.tween_interval(maxf(hold, 0.0))
	tween.tween_property(self, "scale:x", 0.001, OPEN_TIME)
	tween.tween_callback(queue_free)
