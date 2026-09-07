extends GutTest
## Der KIPPHEBEL (LeverView) - der Baustein, den Ladesäule und Paternoster teilen.
## Er bucht nichts: er kippt, fällt in die Ruhelage zurück und MELDET die Richtung.
## Blind steht er grau, fängt den Strahl nicht und meldet nichts.

const PART_UP := "page_up"
const PART_DOWN := "page_down"

var lever: LeverView

func before_each() -> void:
	lever = LeverView.new()
	add_child_autofree(lever)
	lever.setup(PART_UP, PART_DOWN)
	lever.set_armed(true)

func _deltas() -> Array[int]:
	var seen: Array[int] = []
	lever.page_requested.connect(func(delta: int) -> void: seen.append(delta))
	return seen

# --- Die Ruhelage -------------------------------------------------------------------

func test_er_steht_waagerecht() -> void:
	assert_almost_eq(lever.tilt(), 0.0, 0.0001, "die Ruhelage ist waagerecht")

func test_ein_wurf_endet_wieder_in_der_ruhelage() -> void:
	for up in [true, false]:
		lever.flip(up)
		await wait_seconds(LeverView.TIME * 0.5)
		assert_ne(lever.tilt(), 0.0, "unterwegs steht er schief")
		await wait_seconds(LeverView.TIME * 2.6 + LeverView.HOLD + 0.1)
		assert_almost_eq(lever.tilt(), 0.0, 0.001, "und fällt von selbst zurück")

func test_der_endzustand_steht_vor_der_fahrt() -> void:
	# Endzustand zuerst: ein zweiter Wurf setzt die Ruhelage, bevor er neu kippt.
	lever.flip(true)
	await wait_frames(2)
	lever.flip(false)
	assert_almost_eq(lever.tilt(), 0.0, 0.001, "der neue Wurf beginnt in der Ruhe")

func test_die_beiden_seiten_kippen_gegeneinander() -> void:
	lever.flip(true)
	await wait_seconds(LeverView.TIME + 0.02)
	var up := lever.tilt()
	await wait_seconds(LeverView.TIME * 2.6 + LeverView.HOLD)
	lever.flip(false)
	await wait_seconds(LeverView.TIME + 0.02)
	assert_lt(up * lever.tilt(), 0.0, "hinauf und hinab sind Gegenrichtungen")

# --- Die Meldung ---------------------------------------------------------------------

func test_jede_seite_meldet_ihre_richtung() -> void:
	var seen := _deltas()
	assert_true(lever.press(PART_UP), "die obere meldet")
	assert_true(lever.press(PART_DOWN), "die untere auch")
	assert_eq(seen, [1, -1] as Array[int], "+1 hinauf, -1 hinab")

func test_ein_fremdes_teil_meldet_nichts() -> void:
	var seen := _deltas()
	assert_false(lever.press("charge"), "ein fremder Name ist kein Teil von ihm")
	assert_eq(seen, [] as Array[int])
	assert_eq(lever.direction_of("charge"), 0)

func test_blind_klickt_er_nicht() -> void:
	var seen := _deltas()
	lever.set_armed(false)
	assert_false(lever.press(PART_UP), "grau meldet nichts")
	assert_eq(seen, [] as Array[int])
	assert_almost_eq(lever.tilt(), 0.0, 0.001, "und rührt sich auch nicht")

func test_blind_faengt_er_den_strahl_gar_nicht_erst() -> void:
	assert_true(lever.pick_armed(PART_UP), "scharf fängt er")
	assert_true(lever.pick_armed(PART_DOWN))
	lever.set_armed(false)
	assert_false(lever.pick_armed(PART_UP), "blind fängt er nicht")
	assert_false(lever.pick_armed(PART_DOWN))

func test_blind_antwortet_er_dem_zeiger_nicht() -> void:
	lever.set_hovered(PART_UP)
	assert_eq(lever.hovered(), PART_UP)
	lever.set_armed(false)
	assert_eq(lever.hovered(), LeverView.PART_NONE, "grau hebt sich nichts")
	lever.set_hovered(PART_DOWN)
	assert_eq(lever.hovered(), LeverView.PART_NONE)

# --- Die zwei Bauformen ----------------------------------------------------------------

func test_einseitig_traegt_er_genau_ein_teil() -> void:
	var single := LeverView.new("Einseitig")
	add_child_autofree(single)
	single.setup("charge")
	single.set_armed(true)
	assert_true(single.pick_armed("charge"), "der eine Knauf fängt")
	assert_eq(single.direction_of("charge"), 1, "und sein Wurf geht hinauf")
	assert_eq(single.direction_of(LeverView.PART_NONE), 0)

## Die zwei Teile liegen in der TISCHEBENE nebeneinander (Welt-X), nicht
## übereinander - senkrecht gestapelt fielen sie an der 15°-Kamera in einen Fleck.
func test_die_zwei_teile_liegen_in_der_tischebene_nebeneinander() -> void:
	var up := lever.get_node("Rig/Griff_%s" % PART_UP) as Node3D
	var down := lever.get_node("Rig/Griff_%s" % PART_DOWN) as Node3D
	assert_gt(absf(up.position.x - down.position.x), LeverView.ARM_LENGTH,
		"sie stehen quer auseinander")
	assert_almost_eq(up.position.y, down.position.y, 0.0001, "und auf einer Höhe")

# --- Das SCHILD --------------------------------------------------------------------------

func test_das_schild_traegt_seine_aufschrift() -> void:
	assert_eq(lever.sign_text(), "", "ohne Bestellung kein Schild")
	lever.set_sign("Etage 2/5")
	assert_eq(lever.sign_text(), "Etage 2/5")
	lever.flash_sign()  # eine Lieferung auf einer parkenden Etage quittiert hier
	assert_eq(lever.sign_text(), "Etage 2/5", "der Blitz schreibt nichts um")
