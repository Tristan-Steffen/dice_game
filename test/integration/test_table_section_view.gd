extends GutTest
## DIE TISCHSEKTION unter dem Ziel-Netz: buendig IST sie die Anzeige, beim Verdichten
## SINKT sie ganz unter die Schnittkante und FAEHRT dann nach Bild-rechts (Welt +Z)
## in ihre Tasche. Was bleibt, ist die Vertiefung fuer den Rohling.

const SPAN := Vector2(3.8, 6.1)

var section: TableSectionView

func before_each() -> void:
	section = TableSectionView.new()
	add_child_autofree(section)
	section.seat(Vector3.ZERO, SPAN)

func _plate() -> Node3D:
	return section.get_node("Platte") as Node3D

func test_buendig_steht_sie_auf_null() -> void:
	assert_eq(_plate().position, Vector3.ZERO, "0/0 ist der buendige Stand")
	var top := section.get_node("Platte/DeckTop") as MeshInstance3D
	assert_lt(top.position.y, 0.0, "die Deckhaut haengt GANZ unter der Nullebene")
	assert_almost_eq(top.position.y * -2.0, TableSectionView.DECK * 0.12, 0.0001,
		"zwei koplanare Deckflaechen stritten sonst im Tiefenpuffer")

## Erst sinken, dann fahren - und gesunken steht sie GANZ unter der Kante, sonst
## schraemte sie beim Fahren am Glas.
func test_erst_sinken_dann_fahren() -> void:
	section.place(0.5, 0.0)
	assert_almost_eq(_plate().position.y, -TableSectionView.SINK * 0.5, 0.0001)
	assert_almost_eq(_plate().position.z, 0.0, 0.0001, "noch faehrt sie nicht")
	section.place(1.0, 0.0)
	assert_almost_eq(_plate().position.y, -TableSectionView.SINK, 0.0001)
	assert_lte(_plate().position.y + TableSectionView.DECK * 0.0, 0.0)
	assert_gt(TableSectionView.SINK, TableSectionView.DECK,
		"ihre Oberkante steht unter der Schnittkante, nicht nur buendig")
	section.place(1.0, 1.0)
	assert_almost_eq(_plate().position.z, section.reach(), 0.0001)
	assert_gt(section.reach(), SPAN.y, "sie faehrt ihre ganze Laenge plus Luft")

func test_der_stand_bleibt_in_seinen_grenzen() -> void:
	section.place(-3.0, -3.0)
	assert_eq(_plate().position, Vector3.ZERO, "unter 0 gibt es keinen Stand")
	section.place(9.0, 9.0)
	assert_almost_eq(_plate().position.y, -TableSectionView.SINK, 0.0001)
	assert_almost_eq(_plate().position.z, section.reach(), 0.0001)

## Die TASCHE steht STILL - nur die Platte faehrt in sie hinein -, und sie ist
## geschlossen: ohne sie fuehre die Sektion in ein schwarzes Nichts unter dem Filz.
func test_die_tasche_steht_still_und_ist_geschlossen() -> void:
	var pocket := section.get_node("Tasche") as Node3D
	var before := pocket.position
	section.place(1.0, 1.0)
	assert_eq(pocket.position, before, "sie faehrt nicht mit")
	for part in ["Decke", "Boden", "Rueckwand", "Flanke0", "Flanke1"]:
		assert_not_null(pocket.get_node_or_null(part), part)
	var back := pocket.get_node("Rueckwand") as Node3D
	assert_gt(back.position.z, section.reach(), "die Rueckwand steht HINTER der Fahrt")

## Die DECKHAUT wird von aussen gemeldet (TableScreen.display_skin) - ohne Meldung
## bleibt die Platte Maschine wie ihre Flanken.
func test_die_deckhaut_wird_gemeldet() -> void:
	var top := section.get_node("Platte/DeckTop") as MeshInstance3D
	assert_not_null(top.material_override, "ohne Haut traegt sie das Maschinen-Material")
	var skin := StandardMaterial3D.new()
	section.deck_skin = skin
	assert_eq(top.material_override, skin, "die gemeldete Haut landet auf der Deckflaeche")
	section.deck_skin = null
	assert_ne(top.material_override, skin, "und faellt zurueck, wenn sie abbestellt wird")

## Dieselben Masse bauen nichts neu - sie ist Moebel, keine Fahrt.
func test_dieselben_masse_bauen_nichts_neu() -> void:
	var before := _plate()
	section.seat(Vector3.ZERO, SPAN)
	assert_eq(_plate(), before, "derselbe Knoten")
	section.seat(Vector3(0.0, 0.0, 2.0), SPAN)
	assert_ne(_plate(), before, "ein anderer Platz ist ein neuer Bau")
