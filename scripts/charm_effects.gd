class_name CharmEffects
## Reine Effekt-Logik der Charms (siehe Charm) - keine Nodes, nur Rechnen,
## analog zu DiceScoring. Jeder Charm wirkt über seine id (Charm.id) und wird
## hier zentral per match aufgelöst, damit ein neuer Charm nur hier + als neue
## Fabrikmethode in charm.gd ergänzt werden muss.

## Augenwert, den face_value (ein tatsächlich gewürfelter Wert) nach allen
## aktiven Charms zur Punktsumme beiträgt (siehe DiceScoring._sum und die
## Pasch-Zweige von score_category) - wirkt NICHT auf die Kategorie-Erkennung
## (Paare, Straßen, ...), die bleibt am tatsächlich gewürfelten Wert; nur wie
## stark er zählt, ändert sich. Mehrere Charms wirken nacheinander, ihre
## Effekte stapeln sich also.
static func eye_value(face_value: int, charm_ids: Array[String]) -> int:
	var value := face_value
	for charm_id in charm_ids:
		value = _apply(charm_id, face_value, value)
	return value

static func _apply(charm_id: String, face_value: int, value: int) -> int:
	match charm_id:
		"rabbits_foot":
			return value + face_value if face_value == 6 else value
		"lucky_cigarettes":
			return 6 if face_value == 1 else value
		_:
			return value
