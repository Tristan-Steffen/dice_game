class_name PressTargeting
extends RefCounted
## Wohin darf ein Beutestück? Reine Ziel-Logik der Platzierung: Ziel-Form je
## Gravur, Eignung je Seite im aktuellen Schritt und der Vorschau-Klon. Kein
## Node, kein Zustand - die Werkbank führt die Klicks, hier steht nur die Regel.
##
## Sie hing früher in der Gravur-Station; seit die Platzierung IM Netz auf der
## Werkbank läuft, hätte sie dort zwei Wirte gehabt.

## Ziel-Form je Gravur - steuert Eignung, Vorschau und Anwendung.
const TARGET_FACE := "face"                    # Kerbe, Materialien, Runen
const TARGET_PAIR_DIRECTED := "pair_directed"  # Meißel, Schleifstein, Pointer
const TARGET_WHOLE_DIE := "whole_die"          # Politur, Überdruck, Aufholen

static func kind_of(engraving_id: String) -> String:
	if DieMaterial.is_valid_id(engraving_id):
		return TARGET_FACE
	match engraving_id:
		Engraving.CHISEL, Engraving.GRINDSTONE, Engraving.POINTER:
			return TARGET_PAIR_DIRECTED
		Engraving.POLISH, Engraving.OVERPRESSURE, Engraving.GROWTH:
			return TARGET_WHOLE_DIE
	return TARGET_FACE

## Braucht diese Gravur überhaupt eine Seite? Ganz-Würfel-Werkzeuge nicht - bei
## ihnen zählt jeder Klick auf den Würfel.
static func needs_face(engraving_id: String) -> bool:
	return kind_of(engraving_id) != TARGET_WHOLE_DIE

## Je Seite: gültiges Ziel im aktuellen Schritt (first_face = erster Klick eines
## gerichteten Paares, -1 = noch keiner). Ohne Werkzeug ist alles gültig.
static func eligible_faces(def: DieDefinition, engraving_id: String,
		first_face: int = -1) -> Array[bool]:
	var e: Array[bool] = []
	e.resize(6)
	if def == null or engraving_id == "":
		e.fill(true)
		return e
	e.fill(false)
	match engraving_id:
		Engraving.GRINDSTONE:
			if first_face == -1:
				for i in 6: e[i] = def.faces[i] > EtchingEffects.MIN_FACE_VALUE  # die −1-Seite
			else:
				for i in 6: e[i] = i != first_face
		Engraving.POINTER:
			# Ziel nur eine NACHBAR-Seite - der Pointer quert genau eine Kante.
			if first_face == -1:
				e.fill(true)
			else:
				for i in 6: e[i] = def.can_point(first_face, i)
		Engraving.DOPING:
			# Sie sättigt ein vorhandenes Material - eine nackte Seite hat nichts
			# zu veredeln, eine veredelte nichts mehr zu gewinnen. Der Einbrand
			# sperrt nur das Übermalen, nie die Glasur darauf.
			for i in 6:
				e[i] = DieMaterial.is_valid_id(def.materials[i]) \
						and def.material_level(i) < DieMaterial.MAX_LEVEL
		_:
			match kind_of(engraving_id):
				TARGET_WHOLE_DIE:
					e.fill(true)
				TARGET_PAIR_DIRECTED:
					if first_face == -1:
						e.fill(true)
					else:
						for i in 6: e[i] = i != first_face
				_:
					if DieMaterial.is_valid_id(engraving_id):
						# Dasselbe Material noch einmal ist kein Ziel; ein Einbrand
						# sperrt das Übermalen.
						for i in 6:
							e[i] = def.materials[i] != engraving_id and not face_burned_in(def, i)
					else:
						e.fill(true)
	return e

static func face_eligible(def: DieDefinition, engraving_id: String, face: int,
		first_face: int = -1) -> bool:
	if face < 0 or face >= 6:
		return false
	return eligible_faces(def, engraving_id, first_face)[face]

## Ist der Wert dieser Seite eingebrannt? Dann lässt sie sich nicht übermalen.
static func face_burned_in(def: DieDefinition, face: int) -> bool:
	return RuneEffects.protects_face_value(def.runes_on(face))

## Platz, auf den das nächste Rune dieser Seite fällt: der erste FREIE (Vakuum
## trägt zwei, mit Glasglocke drei), sonst der erste - er wird ersetzt.
static func free_rune_slot(def: DieDefinition, face: int, extra_slots: int = 0) -> int:
	for slot in def.rune_slots(extra_slots):
		var occupied: String = def.runes[face]
		if slot == 1:
			occupied = def.second_runes[face]
		elif slot == 2:
			occupied = def.third_runes[face]
		if occupied == "":
			return slot
	return 0

## Klon nach Anwendung der Gravur (face = die überfahrene Seite, bei Paaren das
## ZIEL); null, wenn hier keine Augenzahl wandert. Nutzt die echten
## EtchingEffects - kein zweites Regelwerk.
static func ghost_after(def: DieDefinition, engraving_id: String, stufe: int,
		face: int, first_face: int = -1) -> DieDefinition:
	if def == null or engraving_id == "":
		return null
	var g := def.instantiate()
	match engraving_id:
		Engraving.NOTCH:
			if face < 0:
				return null
			EtchingEffects.notch(g, face, stufe)
		Engraving.CHISEL:
			if first_face < 0 or face < 0:
				return null
			EtchingEffects.chisel(g, first_face, _one(face), stufe)
		Engraving.GRINDSTONE:
			if first_face < 0 or face < 0:
				return null
			EtchingEffects.grindstone(g, first_face, face, stufe)
		Engraving.POLISH:
			EtchingEffects.polish(g, stufe)
		Engraving.OVERPRESSURE:
			EtchingEffects.overpressure(g, stufe)
		Engraving.GROWTH:
			EtchingEffects.growth(g, stufe)
		_:
			return null
	return g

## GDScript wandelt ein untypisiertes Literal nicht in Array[int].
static func _one(face: int) -> Array[int]:
	var typed: Array[int] = [face]
	return typed
