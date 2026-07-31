class_name ChipStackView
extends Node3D
## Zeigt den Geldstand als echte Chip-Börse (_wallet: Anzahl je Stückelung) auf
## dem Tisch. Zuwachs kommt in gierig gestückelten Chips herein; bei Zahlung
## wird möglichst exakt bezahlt, sonst mit genau einem Chip zu viel, und das
## Wechselgeld kommt aus dem Tisch zurück (siehe payment_plan). Wächst ein
## Chip-Bestand über STACK_LIMIT Türme, wertet ihn show_wallet automatisch in
## höhere Stückelungen auf (color up, siehe consolidate). Die
## Türme (max. COLUMN_CAP Chips) stehen als Rack in Reihen, nach Stückelung
## gruppiert. Nur der oberste Chip einer Spalte trägt die Wertziffer; ein aus
## dem Index abgeleiteter Versatz lässt die Türme handgesetzt wirken.

## Stückelungen (absteigend für die gierige Zerlegung): Neon-Farbe (Geld-Licht-
## puls/Ziffer) + satter Keramik-Körper + Akzentring + Rand-Punkt-Farbe. Werte
## folgen der Casino-Konvention: $1 blau, $5 rot, $25 grün, $100 schwarz-gold.
const DENOMINATIONS := [
	{
		"value": 100,
		"color": Color("ffcf40"),                 # Gold (Puls/Ziffer)
		"body": Color(0.06, 0.05, 0.08),          # tiefes Anthrazit
		"accent": Color(1.0, 0.80, 0.30),
		"spot": Color(0.86, 0.72, 0.38),          # goldene Rand-Punkte
	},
	{
		"value": 25,
		"color": Color("3ef08a"),                 # Neon-Grün
		"body": Color(0.03, 0.22, 0.11),          # tiefes Tannengrün
		"accent": Color(0.34, 0.95, 0.58),
	},
	{
		"value": 5,
		"color": Color("fe5f55"),                 # Neon-Rot
		"body": Color(0.40, 0.05, 0.09),          # tiefes Burgunder
		"accent": Color(1.0, 0.37, 0.33),
	},
	{
		"value": 1,
		"color": Color("2f9ff0"),                 # Neon-Blau
		"body": Color(0.05, 0.11, 0.32),          # tiefes Kobalt
		"accent": Color(0.24, 0.66, 0.98),
	},
]

const SPOT_COLOR := Color(0.82, 0.79, 0.70)       # gedämpfte Creme-Rand-Punkte (Standard)

const CHIP_RADIUS := 0.9
const CHIP_HEIGHT := 0.28
const COLUMN_CAP := 12
## Übersteigt eine Stückelung mehr als STACK_LIMIT Türme, wird sie automatisch
## gierig in höhere Chips aufgewertet ("color up"), siehe consolidate.
const STACK_LIMIT := 3
const COLUMN_SPACING := CHIP_RADIUS * 2.3         # Turmabstand in der Reihe
const ROW_SPACING := CHIP_RADIUS * 2.15           # Abstand zwischen Reihen
const ROW_LEN := 4                                # Türme je Reihe (Truhenbreite)
const JITTER_XZ := CHIP_RADIUS * 0.05             # winziger Stapelversatz
const COLUMN_JITTER := CHIP_RADIUS * 0.06         # dezenter Versatz ganzer Türme

## Stückelungs-Werte, absteigend (Reihenfolge der gierigen Zerlegung/Anzeige).
const VALUES := [100, 25, 5, 1]

## Prägung/Absorption: ein einzelner Chip steigt am Münzschlitz auf und hüpft im
## Bogen auf den Turm (Zuwachs) bzw. vom Turm in den Schlitz (Ausgabe).
const MINT_TIME := 0.42
const MINT_HOP := CHIP_RADIUS * 2.6               # Bogenhöhe des Hüpfers

## Zwei Münzschlitze (lokaler XZ-Versatz vom Turm-Ursprung): links wird gezahlt
## (Chips sinken hinein), rechts kommt herein/Wechselgeld heraus. scene_root
## setzt beide aus den Weltpositionen der Schlitze auf der Truhe.
var pay_slot_offset := Vector2.ZERO
var receive_slot_offset := Vector2.ZERO

## Die Börse: Anzahl je Stückelung. Einzige Wahrheit der Anzeige; scene_root
## hält sie deckungsgleich mit GameRun.money.
var _wallet := {100: 0, 25: 0, 5: 0, 1: 0}

var _chip_nodes: Array[Node3D] = []
var _mint_nodes: Array[Node3D] = []               # laufende Präge-/Absorptions-Chips
var _top_y := CHIP_HEIGHT                          # Landehöhe über dem höchsten Turm
var _towers: Array = []                            # zuletzt gebaute Türme {value, count, at}

## Geteilte Ressourcen.
var _chip_mesh: CylinderMesh
var _materials: Dictionary = {}   # value -> ShaderMaterial

# --- Börse (Wahrheit der Anzeige) -------------------------------------------

## Setzt die Börse gierig aus einem Betrag neu (Spielstart/Reset oder als
## Sicherheitsnetz bei Abweichung) und zeigt sie sofort.
func seed_wallet(amount: int) -> void:
	_wallet = {100: 0, 25: 0, 5: 0, 1: 0}
	for value in split_gain(amount):
		_wallet[value] += 1
	show_wallet()

## Fügt der Börse Chips hinzu (ohne Neuaufbau - die Anzeige folgt getrennt).
func add_chips(values: Array) -> void:
	for value in values:
		_wallet[int(value)] += 1

## Entnimmt der Börse Chips (ohne Neuaufbau).
func remove_chips(spend: Dictionary) -> void:
	for value in spend:
		_wallet[int(value)] -= int(spend[value])

func wallet() -> Dictionary:
	return _wallet.duplicate()

func wallet_total() -> int:
	var total := 0
	for value in _wallet:
		total += int(value) * int(_wallet[value])
	return total

## Zeigt die aktuelle Börse (Abgleich/Endzustand). Vorher wird color-up
## angewandt: zu hohe Chip-Stapel wandern automatisch in höhere Stückelungen.
func show_wallet() -> void:
	_wallet = consolidate(_wallet)
	_build_pile(_wallet)

## Zeigt einen beliebigen Chip-Bestand (Zwischenbild einer Animation).
func show_counts(counts: Dictionary) -> void:
	_build_pile(counts)

## Baut den Chip-Turm aus einem Bestand {value: count} neu auf.
func _build_pile(counts: Dictionary) -> void:
	_ensure_resources()
	for node in _chip_nodes:
		node.queue_free()
	_chip_nodes.clear()

	var columns: Array = []  # {value, count} je Spalte, höchster Wert zuerst
	for value in VALUES:
		_append_columns(columns, value, int(counts.get(value, 0)))

	var offsets := _rack_offsets(columns.size())
	var tallest := 0
	_towers = []
	for i in columns.size():
		tallest = maxi(tallest, int(columns[i]["count"]))
		_build_column(i, columns[i]["value"], columns[i]["count"], offsets[i])
		_towers.append({"value": columns[i]["value"], "count": columns[i]["count"], "at": offsets[i]})
	_top_y = float(tallest) * CHIP_HEIGHT + CHIP_HEIGHT * 0.5

## Zuletzt gebaute Türme: {value, count, at: Vector2 (lokales XZ)} je Turm.
func towers() -> Array:
	return _towers

## Turm-Index unter einem lokalen XZ-Punkt (-1 = keiner).
func tower_at(local_xz: Vector2) -> int:
	for i in _towers.size():
		if local_xz.distance_to(_towers[i]["at"]) <= CHIP_RADIUS * 1.35:
			return i
	return -1

## Baut einen frei beweglichen Geister-Turm (für die Zieh-Geste zum Schlitz);
## der Aufrufer positioniert und befreit ihn.
func build_ghost_tower(value: int, count: int) -> Node3D:
	_ensure_resources()
	var ghost := Node3D.new()
	for j in count:
		var chip := _build_chip(value, j == count - 1)
		chip.position = Vector3(0.0, CHIP_HEIGHT * (float(j) + 0.5), 0.0)
		chip.rotation.y = _jitter(j, 7) * TAU
		ghost.add_child(chip)
	add_child(ghost)
	return ghost

# --- Stückelungs-Mathematik (rein statisch, testbar) ------------------------

## Gieriger Zerlegung eines Zuwachses in Chip-Werte, höchster zuerst:
## 26 -> [25, 1]; 130 -> [100, 25, 5]. So kommt jeder Gewinn herein und bleibt.
static func split_gain(amount: int) -> Array[int]:
	var values: Array[int] = []
	var rest := maxi(0, amount)
	for value in VALUES:
		while rest >= value:
			rest -= value
			values.append(value)
	return values

## Zahlplan aus der Börse für einen Preis: möglichst exakt (größte Chips zuerst),
## sonst mit GENAU einem Chip zu viel; überflüssige kleine Chips werden wieder
## einbehalten. Liefert {spend: {value: count}, change: int}. change > 0 kommt
## als frische Chips (split_gain) aus dem Tisch zurück. Setzt Zahlbarkeit voraus
## (Preis <= Summe der Börse).
static func payment_plan(wallet_counts: Dictionary, price: int) -> Dictionary:
	var spend := {100: 0, 25: 0, 5: 0, 1: 0}
	var remaining := maxi(0, price)
	for value in VALUES:
		@warning_ignore("integer_division")
		var take: int = mini(int(wallet_counts.get(value, 0)), remaining / value)
		spend[value] += take
		remaining -= take * value
	if remaining > 0:
		# Kein exakter Rest möglich: genau einen Chip drauflegen - den kleinsten
		# verfügbaren, dessen Wert den Rest deckt.
		for value in [1, 5, 25, 100]:
			if value >= remaining and int(wallet_counts.get(value, 0)) > spend[value]:
				spend[value] += 1
				remaining -= value  # jetzt <= 0
				break
	var overpay := -remaining if remaining < 0 else 0
	# Überzahlung mit den größten kleinen Chips wieder abbauen (Wechselgeld
	# minimieren) - die Überschuss-Chips bleiben in der Börse.
	for value in [25, 5, 1]:
		while spend[value] > 0 and overpay >= value:
			spend[value] -= 1
			overpay -= value
	return {"spend": spend, "change": overpay}

## Color-up: übersteigt eine Stückelung (außer der höchsten) mehr als
## STACK_LIMIT Türme, wird ihr GANZER Bestand gierig in höhere Chips
## aufgewertet - der Gesamtwert bleibt gleich. Aufsteigend abgearbeitet, damit
## erzeugte höhere Chips ihrerseits weiter aufsteigen können (Kaskade). Die
## höchste Stückelung ($100) bleibt: für sie gibt es kein Höher.
static func consolidate(counts: Dictionary) -> Dictionary:
	var result := {100: 0, 25: 0, 5: 0, 1: 0}
	for value in counts:
		result[int(value)] += int(counts[value])
	for value in [1, 5, 25]:
		if result[value] > STACK_LIMIT * COLUMN_CAP:
			var upgraded := split_gain(value * result[value])
			result[value] = 0
			for v in upgraded:
				result[v] += 1
	return result

## Umtausch eines ganzen Turms (count Chips zu value) am Schlitz: liefert die
## gierig aufgewerteten Chips - oder leer, wenn kein höherer Chip entsteht
## (dann bleibt der Turm, wie er ist; nichts wird sinnlos geschluckt).
static func exchange_values(value: int, count: int) -> Array[int]:
	var result := split_gain(value * count)
	if result.size() == count:  # gleiche Chipzahl = keine Aufwertung möglich
		return [] as Array[int]
	return result

## Ein Bestand minus einer Chip-Werteliste (für Zwischenbilder der Anzeige).
static func without(counts: Dictionary, values: Array) -> Dictionary:
	var result := counts.duplicate()
	for value in values:
		result[int(value)] = int(result.get(int(value), 0)) - 1
	return result

func _append_columns(columns: Array, value: int, count: int) -> void:
	while count > 0:
		var height := mini(count, COLUMN_CAP)
		columns.append({"value": value, "count": height})
		count -= height

func _build_column(col_i: int, value: int, count: int, at: Vector2) -> void:
	for j in count:
		var top := j == count - 1
		var chip := _build_chip(value, top)
		var dx := _jitter(col_i * 31 + j, 1) * JITTER_XZ
		var dz := _jitter(col_i * 31 + j, 2) * JITTER_XZ
		chip.position = Vector3(at.x + dx, CHIP_HEIGHT * (float(j) + 0.5), at.y + dz)
		chip.rotation.y = _jitter(col_i * 31 + j, 3) * TAU
		add_child(chip)
		_chip_nodes.append(chip)

## Rack-Anordnung für n Türme: Reihen entlang der Truhen-Längsachse (Welt-Z,
## Bildschirm links-rechts), je Reihe bis ROW_LEN Türme, weitere Reihen entlang
## Welt-X; Reihe wie Gesamtblock zentriert. Da die Türme nach Stückelung
## sortiert ankommen (hohe Werte zuerst), entstehen zusammenhängende
## Farbblöcke wie bei einer aufgeräumten Casino-Bank.
static func _rack_offsets(n: int) -> Array[Vector2]:
	var offsets: Array[Vector2] = []  # (x, z) je Turm
	if n <= 0:
		return offsets
	@warning_ignore("integer_division")
	var rows := (n + ROW_LEN - 1) / ROW_LEN
	var i := 0
	for r in rows:
		var in_row := mini(ROW_LEN, n - i)
		var x := (float(r) - float(rows - 1) * 0.5) * ROW_SPACING
		for k in in_row:
			var z := (float(k) - float(in_row - 1) * 0.5) * COLUMN_SPACING
			offsets.append(Vector2(x, z) + Vector2(_jitter(i, 4), _jitter(i, 5)) * COLUMN_JITTER)
			i += 1
	return offsets

## Kurzer elastischer Pop des Turms (Einschlag des Geld-Lichts).
func pulse() -> void:
	scale = Vector3.ONE * 1.18
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector3.ONE, 0.35)

## Prägt bzw. absorbiert EINEN Chip an einem Münzschlitz: incoming = er steigt
## am Einzahlungs-Schlitz auf und hüpft auf den Turm; sonst hebt er vom Turm ab
## und sinkt in den Auszahlungs-Schlitz. Der Chip materialisiert/entmaterialisiert
## per Skalierung, damit die Prägung auch ohne Tisch-Verdeckung sauber wirkt.
func mint_chip(value: int, incoming: bool) -> void:
	_ensure_resources()
	if not _materials.has(value):
		return
	var chip := _build_chip(value, true)
	chip.rotation.y = randf() * TAU
	add_child(chip)
	_mint_nodes.append(chip)
	var off := receive_slot_offset if incoming else pay_slot_offset
	var slot := Vector3(off.x, CHIP_HEIGHT * 0.5, off.y)
	var pile := Vector3(0.0, _top_y, 0.0)
	var start := slot if incoming else pile
	var end := pile if incoming else slot

	# Beide Tweens am Chip verankert: clear_mints() tötet sie mit dem Chip,
	# sonst feuern ihre Lambdas weiter auf den toten Chip (Engine-Fehlerflut).
	var move := chip.create_tween()
	move.tween_method(func(a: float) -> void:
		if not is_instance_valid(chip):
			return
		var p := start.lerp(end, a)
		p.y += sin(a * PI) * MINT_HOP
		chip.position = p, 0.0, 1.0, MINT_TIME).set_trans(Tween.TRANS_SINE)
	move.tween_callback(func() -> void:
		_mint_nodes.erase(chip)
		if is_instance_valid(chip):
			chip.queue_free())

	var scale_tw := chip.create_tween()
	if incoming:
		chip.scale = Vector3.ZERO
		scale_tw.tween_property(chip, "scale", Vector3.ONE, MINT_TIME * 0.45) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		scale_tw.tween_interval(MINT_TIME * 0.55)
		scale_tw.tween_property(chip, "scale", Vector3.ZERO, MINT_TIME * 0.45) \
			.set_trans(Tween.TRANS_SINE)

## Bricht laufende Prägungen sofort ab (neue Transaktion / Reset).
func clear_mints() -> void:
	for node in _mint_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_mint_nodes.clear()

## Ein Keramik-Pokerchip (geteiltes Mesh + Shader-Material je Wert). Nur der
## oberste Chip einer Spalte trägt die flache Wertziffer.
func _build_chip(value: int, top: bool) -> Node3D:
	var chip := Node3D.new()

	var body := MeshInstance3D.new()
	body.mesh = _chip_mesh
	body.material_override = _materials[value]
	chip.add_child(body)

	if top:
		var label := Label3D.new()
		label.text = str(value)
		label.font_size = 96
		# Dreistellige Werte (100) schmaler skalieren, damit sie aufs Inlay passen.
		label.pixel_size = 0.006 if value < 100 else 0.0044
		# Flach auf der Oberseite und stets aufrecht ausgerichtet (der Keramik-
		# Körper darunter darf zufällig gedreht sein, die Ziffer bleibt lesbar).
		label.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		label.position.y = CHIP_HEIGHT * 0.5 + 0.01
		label.modulate = Color(0.97, 0.95, 0.88)
		label.outline_modulate = Color(0.02, 0.02, 0.04, 0.8)
		label.outline_size = 14
		chip.add_child(label)

	return chip

## Neon-Farbe einer Stückelung, Weiß als Rückfall.
static func denomination_color(value: int) -> Color:
	for denom in DENOMINATIONS:
		if denom["value"] == value:
			return denom["color"]
	return Color.WHITE

## Deterministischer Pseudo-Zufall (-0.5..0.5) aus zwei Indizes: gleicher Turm
## bleibt bei jedem Neuaufbau gleich versetzt (kein Flimmern bei Geldänderung).
static func _jitter(a: int, b: int) -> float:
	return fposmod(sin(float(a) * 12.9898 + float(b) * 78.233) * 43758.5453, 1.0) - 0.5

func _ensure_resources() -> void:
	if _chip_mesh != null:
		return
	_chip_mesh = CylinderMesh.new()
	_chip_mesh.top_radius = CHIP_RADIUS
	_chip_mesh.bottom_radius = CHIP_RADIUS
	_chip_mesh.height = CHIP_HEIGHT
	_chip_mesh.radial_segments = 48
	_chip_mesh.rings = 1

	var shader := load("res://assets/shaders/chip.gdshader")
	for denom in DENOMINATIONS:
		var value: int = denom["value"]
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("body_color", denom["body"])
		mat.set_shader_parameter("spot_color", denom.get("spot", SPOT_COLOR))
		mat.set_shader_parameter("accent_color", denom["accent"])
		mat.set_shader_parameter("radius", CHIP_RADIUS)
		mat.set_shader_parameter("height", CHIP_HEIGHT)
		_materials[value] = mat
