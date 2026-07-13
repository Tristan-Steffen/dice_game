extends GutTest
## Tier-2-Test gegen Drift zwischen der auf dem Tisch angezeigten Kombinationsliste
## und der Wertungslogik. Die 13 Zeilen-Labels liegen als feste Nodes in
## scene_root.tscn (Kinder des Combinations-Ankers, je nach DiceScoring-Key
## benannt, Text fest im .tscn - siehe scene_root.gd: _collect_combo_labels).
## Ändert jemand in DiceScoring einen Hand-Namen oder -Multiplikator, würde die
## Tischliste sonst still veralten. Dieser Test lädt die Szene (ohne sie in den
## Baum zu hängen, also ohne _ready/Spiellogik) und vergleicht jeden Label-Text
## mit label_for(key) + mult_for(key).

const SceneRootScene := preload("res://scenes/scene_root.tscn")

func test_every_combo_label_exists_and_matches_scoring():
	var scene: Node = autofree(SceneRootScene.instantiate())
	var combos := scene.get_node_or_null("Combinations")
	assert_not_null(combos, "Combinations-Anker fehlt in der Szene")
	if combos == null:
		return
	for key in DiceScoring.HAND_PRIORITY:
		var label: Label3D = combos.get_node_or_null(NodePath(key))
		assert_not_null(label, "Kombinations-Label fehlt: Combinations/%s" % key)
		if label != null:
			var expected := "%s  ×%d" % [DiceScoring.label_for(key), DiceScoring.mult_for(key)]
			assert_eq(label.text, expected, "Tisch-Text weicht von DiceScoring ab bei '%s'" % key)

func test_label_count_matches_hand_priority():
	var scene: Node = autofree(SceneRootScene.instantiate())
	var combos := scene.get_node_or_null("Combinations")
	assert_not_null(combos)
	if combos != null:
		assert_eq(combos.get_child_count(), DiceScoring.HAND_PRIORITY.size(),
			"genau ein Label je Kombination")
