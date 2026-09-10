extends GutTest
## Die KNOPFLEISTE des Regalstapels: sieben Felder untereinander - oben ▲, darunter
## 1 … 5, unten ▼. Taste n wählt Tablett n, ▲ das darüber, ▼ das darunter; an den
## Enden ist der Pfeil BLIND (kein Umlauf) und fängt den Strahl gar nicht erst.
## Sie bucht nichts: sie MELDET.

const TRAYS := PackDrawerView.TRAYS
const ROOM := 6.0

var bar: ShelfSelectorView
var asked: Array[int] = []

func before_each() -> void:
	bar = ShelfSelectorView.new()
	add_child_autofree(bar)
	bar.setup(Vector3.ZERO, ROOM)
	asked = []
	bar.tray_requested.connect(func(tray: int) -> void: asked.append(tray))

# --- Teile und Richtung -------------------------------------------------------------

func test_jedes_feld_kennt_sich_selbst() -> void:
	for tray in TRAYS:
		var part := ShelfSelectorView.part_key(tray)
		assert_eq(ShelfSelectorView.tray_of_part(part), tray, part)
		assert_eq(ShelfSelectorView.direction_of(part), 0, "eine Zahl zeigt nirgendwohin")
		assert_true(ShelfSelectorView.knows(part))
	assert_eq(ShelfSelectorView.direction_of(ShelfSelectorView.PART_UP), -1,
		"▲ wählt die KLEINERE Nummer")
	assert_eq(ShelfSelectorView.direction_of(ShelfSelectorView.PART_DOWN), 1)
	assert_eq(ShelfSelectorView.tray_of_part(ShelfSelectorView.PART_UP), -1)

## Auf ihrer Pick-Ebene liegt auch die Sicherungs-Fassung: der NAME entscheidet.
func test_ein_fremdes_teil_gehoert_ihr_nicht() -> void:
	assert_eq(ShelfSelectorView.PICK_LAYER, FuseSocketView.PICK_LAYER,
		"dieselbe Ebene ...")
	assert_false(ShelfSelectorView.knows(FuseSocketView.PART_FUSE), "... anderer Name")
	assert_false(ShelfSelectorView.knows("key99"), "kein Tablett 100")
	assert_false(ShelfSelectorView.knows(""))

func test_die_aufschriften_nennen_pfeil_und_zahl() -> void:
	assert_eq(bar.label_of(ShelfSelectorView.PART_UP), ShelfSelectorView.TEXT_UP)
	assert_eq(bar.label_of(ShelfSelectorView.PART_DOWN), ShelfSelectorView.TEXT_DOWN)
	for tray in TRAYS:
		assert_eq(bar.label_of(ShelfSelectorView.part_key(tray)), "%d" % (tray + 1),
			"Taste %d nennt ihre Tablett-Nummer" % (tray + 1))

# --- Der Platz ---------------------------------------------------------------------

## Die fünf Tasten stehen monoton entlang -X (Bild-unten), alle im Fußabdruck.
func test_die_tasten_stehen_monoton_im_fussabdruck() -> void:
	var lo := bar.bounds_min()
	var hi := bar.bounds_max()
	var last := INF
	for tray in TRAYS:
		var at := bar.key_point(tray)
		assert_lt(at.x, last, "Taste %d liegt unter der davor" % (tray + 1))
		last = at.x
		assert_between(at.x, lo.x, hi.x, "Taste %d liegt im Fußabdruck" % (tray + 1))
		assert_between(at.z, lo.y, hi.y)
	assert_almost_eq(hi.x - lo.x, ROOM, 0.0001, "so hoch wie die Grube tief ist")
	assert_almost_eq(bar.field_span() * float(ShelfSelectorView.FIELDS)
		+ ShelfSelectorView.KEY_GAP * float(ShelfSelectorView.FIELDS - 1), ROOM, 0.001,
		"sieben Felder und sechs Fugen teilen die Tiefe")

func test_dieselben_masse_bauen_nichts_neu() -> void:
	var first := bar.key_point(2)
	bar.setup(Vector3.ZERO, ROOM)
	assert_eq(bar.key_point(2), first, "derselbe Platz, byteweise")

# --- Wahl, Blindheit, Meldung ------------------------------------------------------

func test_ein_druck_auf_eine_zahl_meldet_ihr_tablett() -> void:
	assert_true(bar.press(ShelfSelectorView.part_key(3)))
	assert_eq(asked, [3] as Array[int], "gemeldet, nicht gesetzt")
	assert_eq(bar.selected(), 0, "sie setzt NICHTS selbst - das tut scene_root")

func test_die_pfeile_zaehlen_von_der_wahl_aus() -> void:
	bar.set_selected(2)
	assert_true(bar.press(ShelfSelectorView.PART_UP))
	assert_eq(asked, [1] as Array[int], "▲ ist das Tablett darüber")
	asked.clear()
	assert_true(bar.press(ShelfSelectorView.PART_DOWN))
	assert_eq(asked, [3] as Array[int], "▼ das darunter")

func test_an_den_enden_ist_der_pfeil_blind() -> void:
	bar.set_selected(0)
	assert_false(bar.live_for(ShelfSelectorView.PART_UP), "über Tablett 1 ist nichts")
	assert_false(bar.press(ShelfSelectorView.PART_UP), "blind meldet nichts")
	assert_true(asked.is_empty())
	assert_false(bar.pick_armed(ShelfSelectorView.PART_UP), "und fängt nicht")
	assert_true(bar.live_for(ShelfSelectorView.PART_DOWN))
	bar.set_selected(TRAYS - 1)
	assert_false(bar.live_for(ShelfSelectorView.PART_DOWN), "unter Tablett 5 auch nicht")
	assert_false(bar.press(ShelfSelectorView.PART_DOWN))
	assert_true(bar.live_for(ShelfSelectorView.PART_UP))

func test_blind_klickt_die_ganze_leiste_nicht() -> void:
	bar.set_live(false)
	for tray in TRAYS:
		var part := ShelfSelectorView.part_key(tray)
		assert_false(bar.live_for(part))
		assert_false(bar.press(part))
		assert_false(bar.pick_armed(part), "Taste %d fängt nicht" % (tray + 1))
	assert_true(asked.is_empty(), "grau meldet nichts")
	bar.set_live(true)
	assert_true(bar.pick_armed(ShelfSelectorView.part_key(0)), "scharf fängt sie wieder")

func test_der_zeiger_antwortet_nur_auf_lebenden_teilen() -> void:
	bar.set_selected(0)
	bar.set_hovered(ShelfSelectorView.PART_UP)
	assert_eq(bar.hovered(), ShelfSelectorView.PART_NONE, "der blinde Pfeil hebt nicht")
	bar.set_hovered(ShelfSelectorView.part_key(2))
	assert_eq(bar.hovered(), ShelfSelectorView.part_key(2))
	bar.set_live(false)
	assert_eq(bar.hovered(), ShelfSelectorView.PART_NONE, "grau vergißt den Zeiger")

## Die GEWÄHLTE Taste leuchtet Gold, die übrigen stehen dunkel.
func test_die_gewaehlte_taste_leuchtet_gold() -> void:
	bar.set_selected(2)
	var chosen := bar.get_node("Feld_%s/Taste" % ShelfSelectorView.part_key(2)) \
		as MeshInstance3D
	var other := bar.get_node("Feld_%s/Taste" % ShelfSelectorView.part_key(4)) \
		as MeshInstance3D
	var gold := chosen.material_override as StandardMaterial3D
	var rest := other.material_override as StandardMaterial3D
	assert_eq(gold.emission, ShelfSelectorView.LIVE_TINT)
	assert_eq(rest.emission, ShelfSelectorView.REST_TINT)
	assert_gt(gold.emission_energy_multiplier, rest.emission_energy_multiplier)
	bar.set_live(false)
	assert_eq((chosen.material_override as StandardMaterial3D).emission,
		ShelfSelectorView.DEAD_TINT, "blind ist alles grau")

func test_der_blitz_faellt_auf_die_ruheenergie_zurueck() -> void:
	var key := bar.get_node("Feld_%s/Taste" % ShelfSelectorView.part_key(3)) \
		as MeshInstance3D
	var material := key.material_override as StandardMaterial3D
	var rest := material.emission_energy_multiplier
	bar.flash_key(3)
	assert_gt(material.emission_energy_multiplier, rest, "sie blitzt auf")
	await wait_seconds(ShelfSelectorView.FLASH_TIME + 0.1)
	assert_almost_eq(material.emission_energy_multiplier, rest, 0.01,
		"und steht danach wieder ruhig")
