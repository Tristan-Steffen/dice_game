extends GutTest
## Lexikon: Vollständigkeit des Katalogs, Ziel-Treue der Oberflächenformen und
## der Matcher (Flexion, Längste-zuerst, Wortgrenzen, Selbstverweis).


# --- Vollständigkeit ---------------------------------------------------------

func test_every_concept_has_entry() -> void:
	for id in Lexikon.CONCEPT_IDS:
		assert_true(Lexikon.has_entry(id), "Konzept ohne Eintrag: %s" % id)


func test_every_begriff_entry_is_listed_concept() -> void:
	for id in Lexikon.ids_in_category(Lexikon.CAT_BEGRIFFE):
		assert_true(Lexikon.CONCEPT_IDS.has(id),
			"Begriff fehlt in CONCEPT_IDS: %s" % id)


func test_every_charm_has_entry() -> void:
	for charm in Charm.all():
		assert_true(Lexikon.has_entry("charm:%s" % charm.id), charm.id)


func test_every_essence_has_entry() -> void:
	for essence in Essence.all():
		assert_true(Lexikon.has_entry("essence:%s" % essence.id), essence.id)


func test_every_material_has_entry() -> void:
	for material in DieMaterial.all():
		assert_true(Lexikon.has_entry("material:%s" % material.id), material.id)


func test_every_rune_has_entry() -> void:
	for rune in Rune.all():
		assert_true(Lexikon.has_entry("rune:%s" % rune.id), rune.id)


func test_every_engraving_has_entry() -> void:
	# Spiegel-Gravuren (Material/Rune/Sonderposten) lösen als Alias auf.
	for engraving in Engraving.all():
		assert_true(Lexikon.has_entry("engraving:%s" % engraving.id), engraving.id)


func test_every_clause_has_entry() -> void:
	for clause in DealClause.all():
		assert_true(Lexikon.has_entry("clause:%s" % clause.id), clause.id)


func test_entries_carry_title_body_and_known_category() -> void:
	var all: Dictionary = Lexikon.entries()
	for id: String in all:
		var e: Dictionary = all[id]
		var title: String = e["title"]
		var body: String = e["body"]
		var category: String = e["category"]
		assert_false(title.is_empty(), "Titel leer: %s" % id)
		assert_false(body.is_empty(), "Text leer: %s" % id)
		assert_true(Lexikon.CATEGORIES.has(category), "Fremde Kategorie: %s" % id)


func test_mirror_engravings_alias_their_target() -> void:
	var gold: Dictionary = Lexikon.entry("engraving:%s" % DieMaterial.GOLD)
	assert_eq(gold["id"], "material:%s" % DieMaterial.GOLD)
	var afterglow: Dictionary = Lexikon.entry("engraving:rune_%s" % Rune.AFTERGLOW)
	assert_eq(afterglow["id"], "rune:%s" % Rune.AFTERGLOW)
	assert_eq(Lexikon.entry("engraving:%s" % Engraving.POINTER)["id"], Lexikon.POINTER)
	assert_eq(Lexikon.entry("engraving:%s" % Engraving.DOPING)["id"], Lexikon.VEREDELUNG)


# --- Verweis-Integrität ------------------------------------------------------

func test_every_extra_surface_targets_real_entry() -> void:
	for surface: String in Lexikon.EXTRA_SURFACES:
		var target: String = Lexikon.EXTRA_SURFACES[surface]
		assert_true(Lexikon.has_entry(target),
			"Totes Verweisziel: %s -> %s" % [surface, target])


# --- Matcher -----------------------------------------------------------------

func test_inflections_link_krit() -> void:
	for form in ["Krit", "Krits", "kritet"]:
		var marked := Lexikon.linkify("Ein %s zählt." % form)
		assert_string_contains(marked, "[url=krit]", form)


func test_longest_form_wins() -> void:
	var marked := Lexikon.linkify("Tscherenkow-Krits kosten keine Energie.")
	assert_string_contains(marked, "[url=essence:cherenkov]")
	assert_false(marked.contains("[url=krit]"), "Suffix-Treffer trotz Voll-Kompositum")


func test_word_boundary_blocks_partial_match() -> void:
	var marked := Lexikon.linkify("Der Multiplikator wächst.")
	assert_false(marked.contains("[url=mult]"), "Mult zündet mitten im Wort")


func test_hyphen_compound_links_suffix() -> void:
	# Der Bindestrich ist keine Wortgrenze: "Gold-Seite" trifft das Gold.
	var marked := Lexikon.linkify("+$1 je ausgelöster Gold-Seite dieser Nahme.")
	assert_string_contains(marked, "[url=material:gold]")


func test_no_self_link_on_own_page() -> void:
	var body: String = Lexikon.entry(Lexikon.KRIT)["body"]
	var marked := Lexikon.linkify(body, Lexikon.KRIT)
	assert_false(marked.contains("[url=krit]"), "Selbstverweis auf eigener Seite")
	# Fremde Verweise bleiben - der Krit-Text nennt den Mult mit Absicht.
	assert_string_contains(marked, "[url=mult]")


func test_decorate_colors_without_links() -> void:
	var marked := Lexikon.decorate("Jede Rune zahlt Energie.")
	assert_string_contains(marked, "[color=#")
	assert_false(marked.contains("[url="), "decorate darf keine Klicks anbieten")


func test_url_tags_balanced() -> void:
	for id in [Lexikon.ENERGIE, Lexikon.GRAVUR, Lexikon.VERTRAG]:
		var body: String = Lexikon.entry(id)["body"]
		var marked := Lexikon.linkify(body)
		assert_eq(marked.count("[url="), marked.count("[/url]"), id)


func test_glyph_surface_links_energie() -> void:
	var marked := Lexikon.linkify("Kostet 1 ⚡ je Stufe.")
	assert_string_contains(marked, "[url=energie]")


func test_bracket_armored_before_tagging() -> void:
	var marked := Lexikon.linkify("Ein [Test] mit Energie.")
	assert_string_contains(marked, "[lb]Test]")
