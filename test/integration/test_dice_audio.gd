extends GutTest
## Tier-2-Tests des Würfel-Sounds (DiceAudio): Kontaktmeldung wird beim Setup
## aktiviert, Aufpralle wählen die richtige Bank (Würfel/Boden/Wand), skalieren
## mit der Geschwindigkeit (zu langsam = stumm), der Cooldown verhindert
## Maschinengewehr-Klicks, und das Settle-Wackeln feuert genau auf der Flanke
## "kommt zur Ruhe". Abgespielt wird über den Player-Pool - die Asserts lesen
## Streams/Startzeiten statt echter Audioausgabe, damit der Test headless läuft.

var audio: DiceAudio
var world: Node3D
var body: RigidBody3D

func before_each() -> void:
	world = Node3D.new()
	add_child_autofree(world)

	body = RigidBody3D.new()
	world.add_child(body)

	audio = DiceAudio.new()
	world.add_child(audio)
	audio.setup([body], null)

## Anzahl der Pool-Player, die schon einmal gespielt haben.
func _voices_started() -> int:
	var count := 0
	for started in audio._player_started_ms:
		if started > 0:
			count += 1
	return count

## Der Stream des zuletzt gestarteten Players (null = nichts gespielt).
func _last_stream() -> AudioStream:
	var best := -1
	var best_ms := 0
	for i in audio._player_started_ms.size():
		if audio._player_started_ms[i] > best_ms:
			best_ms = audio._player_started_ms[i]
			best = i
	return null if best < 0 else audio._players[best].stream

func _static_in_group(group: String) -> StaticBody3D:
	var other := StaticBody3D.new()
	if group != "":
		other.add_to_group(group)
	world.add_child(other)
	return other

# --- Setup ---------------------------------------------------------------------

func test_setup_enables_contact_monitoring():
	assert_true(body.contact_monitor, "Kontaktmeldung muss aktiv sein, sonst feuert body_entered nie")
	assert_gt(body.max_contacts_reported, 0)

func test_setup_builds_player_pool():
	assert_eq(audio._players.size(), DiceAudio.PLAYER_POOL_SIZE)

func test_banks_are_loaded():
	for bank in ["click", "floor", "wall", "tick", "settle"]:
		assert_true(audio._streams.has(bank), "Bank '%s' fehlt - Platzhalter-WAVs nicht importiert?" % bank)

# --- Aufprall-Klassifikation ----------------------------------------------------

func test_fast_floor_impact_plays_floor_bank():
	body.linear_velocity = Vector3(0, -10, 0)
	audio._on_die_contact(_static_in_group("pit_floor"), 0)
	assert_eq(_voices_started(), 1)
	assert_eq(_last_stream(), audio._streams["floor"])

func test_wall_impact_plays_wall_bank():
	body.linear_velocity = Vector3(8, 0, 0)
	audio._on_die_contact(_static_in_group("pit_wall"), 0)
	assert_eq(_last_stream(), audio._streams["wall"])

func test_die_impact_plays_click_bank():
	var other := RigidBody3D.new()
	world.add_child(other)
	body.linear_velocity = Vector3(6, 0, 0)
	other.linear_velocity = Vector3(-6, 0, 0)
	audio._on_die_contact(other, 0)
	assert_eq(_last_stream(), audio._streams["click"])

func test_slow_impact_stays_silent():
	body.linear_velocity = Vector3(0, -DiceAudio.MIN_IMPACT_SPEED * 0.5, 0)
	audio._on_die_contact(_static_in_group("pit_floor"), 0)
	assert_eq(_voices_started(), 0, "unterhalb MIN_IMPACT_SPEED übernimmt das Roll-Ticken")

func test_cooldown_swallows_immediate_second_impact():
	body.linear_velocity = Vector3(0, -10, 0)
	audio._on_die_contact(_static_in_group("pit_floor"), 0)
	audio._on_die_contact(_static_in_group("pit_wall"), 0)
	assert_eq(_voices_started(), 1, "zweiter Aufprall innerhalb IMPACT_COOLDOWN_MS bleibt stumm")

# --- Settle-Flanke ---------------------------------------------------------------

## Baut einen echten Würfel (DieBuilder) samt DiceController und ein frisches
## DiceAudio darauf - before_each-Instanz wird ersetzt, damit setup() nicht
## zweimal auf demselben Objekt läuft.
func _fresh_audio_with_die() -> DiceController:
	var die := DieBuilder.build()
	world.add_child(die)
	var die_roots: Array[Node3D] = [die]
	var die_bodies: Array[RigidBody3D] = [die.get_node("RigidBody3D") as RigidBody3D]
	var displays: Array[DieFaceDisplay] = [die.get_node("RigidBody3D/Faces") as DieFaceDisplay]
	var controller := DiceController.new(die_roots, die_bodies, displays)
	audio = DiceAudio.new()
	world.add_child(audio)
	audio.setup(die_bodies, controller)
	return controller

func test_settle_plays_once_on_coming_to_rest():
	var controller := _fresh_audio_with_die()
	controller.roots[0].visible = true

	controller.settled[0] = false
	audio._process_settle(0)  # Flanke scharf stellen (prev = false)
	assert_eq(_voices_started(), 0)

	controller.settled[0] = true
	audio._process_settle(0)
	assert_eq(_voices_started(), 1)
	assert_eq(_last_stream(), audio._streams["settle"])

	audio._process_settle(0)
	assert_eq(_voices_started(), 1, "ohne neue Flanke kein zweites Wackeln")

func test_settle_of_invisible_die_stays_silent():
	var controller := _fresh_audio_with_die()

	controller.settled[0] = false
	audio._process_settle(0)
	controller.settled[0] = true
	audio._process_settle(0)  # reset() lässt unsichtbare Würfel "einrasten" - kein Sound
	assert_eq(_voices_started(), 0)
