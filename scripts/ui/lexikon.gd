class_name Lexikon
extends RefCounted
## Das Nachschlagewerk des Tisches: je Begriff ein Eintrag, dazu einer je Charm,
## Essenz, Material, Rune, Gravur und Klausel (aus den data/-Katalogen erzeugt).
## Die Quelltexte in data/ bleiben unmarkiert - linkify() macht bekannte
## Wortformen erst beim Rendern zu BBCode-Verweisen. Wohnt in ui/, nicht data/:
## der Verweis trägt CasinoStyle.LEXIKON_LINK, und ui/ darf aus data/ lesen.

## Kategorien in Index-Reihenfolge.
const CAT_BEGRIFFE := "Begriffe"
const CAT_CHARMS := "Charms"
const CAT_ESSENZEN := "Essenzen"
const CAT_MATERIALIEN := "Materialien"
const CAT_RUNEN := "Runen"
const CAT_GRAVUREN := "Gravuren"
const CAT_KLAUSELN := "Klauseln"
const CATEGORIES: Array[String] = [CAT_BEGRIFFE, CAT_CHARMS, CAT_ESSENZEN,
	CAT_MATERIALIEN, CAT_RUNEN, CAT_GRAVUREN, CAT_KLAUSELN]

# --- Konzept-ids (Konvention: Konzepte prefixlos, Items "typ:id") ---
const KRIT := "krit"
const MULT := "mult"
const BASISPUNKTE := "basispunkte"
const ENERGIE := "energie"
const AUSLOESUNG := "ausloesung"
const RUNE := "rune"
const GRAVUR := "gravur"
const MATERIAL := "material"
const VEREDELUNG := "veredelung"
const POINTER := "pointer"
const ESSENZ := "essenz"
const CHARM := "charm"
const KOMBINATION := "kombination"
const BENCHMARK := "benchmark"
const UEBERLADUNG := "ueberladung"
const FUMBLE := "fumble"
const STRESSTEST := "stresstest"
const VERTRAG := "vertrag"
const NEBENWETTE := "nebenwette"
const MAGAZIN := "magazin"
const PRESSE := "presse"
const SCHWARZMARKT := "schwarzmarkt"
const UEBERTAKTEN := "uebertakten"

## Alle Konzept-ids - test_lexikon hält Liste und _build_concepts() im Gleichschritt.
const CONCEPT_IDS: Array[String] = [KRIT, MULT, BASISPUNKTE, ENERGIE, AUSLOESUNG,
	RUNE, GRAVUR, MATERIAL, VEREDELUNG, POINTER, ESSENZ, CHARM, KOMBINATION,
	BENCHMARK, UEBERLADUNG, FUMBLE, STRESSTEST, VERTRAG, NEBENWETTE, MAGAZIN,
	PRESSE, SCHWARZMARKT, UEBERTAKTEN]

## Oberflächenformen -> Eintrags-id, NUR für Formen abseits der Titel (Flexion,
## Verb, Kompositum) - Titel und display_names ergänzt _build() automatisch.
## Der Bindestrich zählt nicht als Wortgrenze, darum brauchen Komposita wie
## "Überladungs-Stufe" eigene Zeilen. Jede Ziel-id sichert test_lexikon ab.
const EXTRA_SURFACES := {
	"Krits": KRIT, "kritet": KRIT, "Kritet": KRIT,
	"Basispunkten": BASISPUNKTE,
	"⚡": ENERGIE,
	"Auslösungen": AUSLOESUNG, "auslösen": AUSLOESUNG,
	"Runen": RUNE,
	"Gravuren": GRAVUR,
	"Materialien": MATERIAL,
	"veredelt": VEREDELUNG, "Veredelt": VEREDELUNG,
	"veredelte": VEREDELUNG, "veredelten": VEREDELUNG, "veredelter": VEREDELUNG,
	"Essenzen": ESSENZ, "Seele": ESSENZ, "Seelen": ESSENZ,
	"Charms": CHARM,
	"Kombinationen": KOMBINATION,
	"Überladungs-Stufe": UEBERLADUNG, "Überladungs-Stufen": UEBERLADUNG,
	"Fumbles": FUMBLE,
	"Verträge": VERTRAG, "Klausel": VERTRAG, "Klauseln": VERTRAG,
	"Nebenwetten": NEBENWETTE,
	"Pressung": PRESSE,
	"übertakten": UEBERTAKTEN, "Übertaktung": UEBERTAKTEN, "Übertaktungen": UEBERTAKTEN,
	# Längste Form gewinnt: der Voll-Kompositum schlägt das nackte "Krit(s)".
	"Tscherenkow-Krit": "essence:cherenkov", "Tscherenkow-Krits": "essence:cherenkov",
}

## Rarität der Charms als Spielerwort (Charm.rarity ist ein String).
const CHARM_RARITY_NAMES := {
	Charm.RARITY_COMMON: "häufig",
	Charm.RARITY_UNCOMMON: "ungewöhnlich",
	Charm.RARITY_RARE: "selten",
	Charm.RARITY_LEGENDARY: "legendär",
}

static var _entries := {}    # id -> {id, title, body, category}
static var _aliases := {}    # id -> kanonische id (Spiegel-Gravuren)
static var _surfaces := {}   # Oberflächenform -> Eintrags-id
static var _pattern: RegEx = null
static var _link_hex := ""

# --- Katalog-API -------------------------------------------------------------

static func entries() -> Dictionary:
	_build()
	return _entries

static func entry(id: String) -> Dictionary:
	_build()
	var canonical: String = _aliases.get(id, id)
	return _entries.get(canonical, {})

static func has_entry(id: String) -> bool:
	return not entry(id).is_empty()

## Eintrags-ids einer Kategorie, alphabetisch nach Titel.
static func ids_in_category(category: String) -> Array[String]:
	_build()
	var ids: Array[String] = []
	for id: String in _entries:
		var e: Dictionary = _entries[id]
		if e["category"] == category:
			ids.append(id)
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ta: String = _entries[a]["title"]
		var tb: String = _entries[b]["title"]
		# sort_custom ist nicht stabil - die id bricht den Titel-Gleichstand.
		return ta < tb if ta != tb else a < b)
	return ids

# --- Verweis-Markierung ------------------------------------------------------

## Bekannte Wortformen als klickbare BBCode-Verweise ([url=<id>]).
## exclude_id unterdrückt Selbstverweise auf der eigenen Eintragsseite.
static func linkify(text: String, exclude_id := "") -> String:
	return _mark(text, exclude_id, true)

## Nur die Farbe, kein [url] - für Flächen, die (noch) keine Klicks bekommen.
static func decorate(text: String, exclude_id := "") -> String:
	return _mark(text, exclude_id, false)

static func _mark(text: String, exclude_id: String, clickable: bool) -> String:
	_build()
	# BBCode-Panzerung, bevor eigene Tags dazukommen (billige Versicherung -
	# heute enthält keine Beschreibung eine Klammer).
	var safe := text.replace("[", "[lb]")
	var result := ""
	var cursor := 0
	for m in _pattern.search_all(safe):
		var id: String = _surfaces[m.get_string()]
		if id == exclude_id:
			continue
		result += safe.substr(cursor, m.get_start() - cursor)
		if clickable:
			result += "[url=%s][color=#%s]%s[/color][/url]" % [id, _link_hex, m.get_string()]
		else:
			result += "[color=#%s]%s[/color]" % [_link_hex, m.get_string()]
		cursor = m.get_end()
	result += safe.substr(cursor)
	return result

# --- Aufbau ------------------------------------------------------------------

static func _build() -> void:
	if not _entries.is_empty():
		return
	_link_hex = CasinoStyle.LEXIKON_LINK.to_html(false)
	_build_concepts()
	_build_items()
	_build_surfaces()
	_compile_pattern()

static func _add(id: String, title: String, body: String, category: String) -> void:
	_entries[id] = {"id": id, "title": title, "body": body, "category": category}

## Handgeschriebene Begriffe - mit Absicht voller Querverweis-Wörter, denn die
## Verlinkung fällt aus dem Matcher, nie aus Markup im Text.
static func _build_concepts() -> void:
	_add(KRIT, "Krit",
		"Ein Krit schlägt multiplikativ auf den Mult, statt zu addieren - jeder Schlag ist ein eigener Faktor, und mehrere Krits einer Hand wirken nacheinander. Sie kommen aus veredelten Materialien wie Rubin und Glas, aus Essenzen wie Xenon oder Kugelblitz und aus Charms.",
		CAT_BEGRIFFE)
	_add(MULT, "Mult",
		"Der Multiplikator der Wertung: Punkte = Basispunkte × Mult. Die Kombination bringt ihren Grund-Mult mit; Materialien, Charms und Krits treiben ihn während des Zählens weiter. Gerundet wird erst ganz am Ende, ein einziges Mal.",
		CAT_BEGRIFFE)
	_add(BASISPUNKTE, "Basispunkte",
		"Die linke Hälfte der Wertung: Punkte = Basispunkte × Mult. Die Kombination legt ihre Basis, jeder gezählte Würfel wirft seine Augen darauf, und Materialien wie Bernstein legen nach.",
		CAT_BEGRIFFE)
	_add(ENERGIE, "Energie",
		"Die Betriebswährung des Casinos, angezeigt als ⚡ und gelagert in der Kondensatorbank. Energie entsteht aus abgeräumten Überladungs-Stufen, aus Klauseln, Nebenwetten, der Rune Funkenflug und aus Charms. Ausgegeben wird sie fürs Übertakten, für die Presse und im Schwarzmarkt.",
		CAT_BEGRIFFE)
	_add(AUSLOESUNG, "Auslösung",
		"Ein volles Feuern eines gewerteten Würfels: Augen, Material und Charms zählen einmal. Essenzen wie Argon lassen den ganzen Würfel mehrfach auslösen, die Rune Nachglühen legt je Seite eine Auslösung obendrauf - Würfel-Faktor und Seiten-Faktor multiplizieren sich.",
		CAT_BEGRIFFE)
	_add(RUNE, "Rune",
		"Ein in die Würfelschale geätztes Zeichen, das den Kernlicht-Funken des Würfels anzapft - die Tönung ist die Wirkung. Jede Seite trägt höchstens eine Rune; nur das Vakuum erlaubt zwei. Runen kommen als Gravur aus Runen-Paketen über die Presse.",
		CAT_BEGRIFFE)
	_add(GRAVUR, "Gravur",
		"Die Aufwertungs-Art der Werkstatt. Zahl-Gravuren verändern Augen, Material-Gravuren belegen eine Seite, Würfel-Gravuren (Pointer, Runen) verdrahten den ganzen Würfel. Eine Gravur existiert nur versiegelt im Paket oder angewendet - gepresst in der Presse und von Hand auf die eingespannten Würfel gesetzt.",
		CAT_BEGRIFFE)
	_add(MATERIAL, "Material",
		"Die Belegung einer einzelnen Würfelseite: Rubin, Bernstein, Gold, Knochen, Glas oder Kupfer. Ein Material wirkt, wenn seine Seite in der Kombination liegt. Die Veredelung hebt es in seine starke Form.",
		CAT_BEGRIFFE)
	_add(VEREDELUNG, "Veredelung",
		"Der starke Zustand eines Materials: die Veredelung sättigt die Glasur einer Seite, die schon ein Material trägt - es wirkt fortan in seiner starken Form (Rubin etwa kritet ×2, statt Mult zu addieren). Nackte und schon veredelte Seiten sind kein Ziel. Zu haben als Sonderposten im Laden und im Schwarzmarkt.",
		CAT_BEGRIFFE)
	_add(POINTER, "Pointer",
		"Ein Draht von einer Würfelseite über eine Kante zur Nachbarseite: Wird die Seite gewertet, löst die Zielseite mit 50 % Chance einmal voll mit aus - und von dort geht die Kette weiter. Geätzt als epische Würfel-Gravur, zu haben als Sonderposten.",
		CAT_BEGRIFFE)
	_add(ESSENZ, "Essenz",
		"Die Seele eines Würfels: ein Leuchtgas, beim Guss in der Schale versiegelt. Sie ist angeboren - kein Auftragen, kein Entfernen, kein Tauschen. Die Essenz ist der einzige Faktor auf der Würfel-Achse der Auslösungen, und ihr Glühen färbt die Kanten. Geheime Seelen führt nur der Schwarzmarkt.",
		CAT_BEGRIFFE)
	_add(CHARM, "Charm",
		"Ein Glücksbringer am Dock des Tisches, höchstens sechs zugleich. Würfelgebundene Charms feuern mit ihrem Würfel, statische nach allen Würfeln in Dock-Reihenfolge - die Reihenfolge ist spielentscheidend. Gekauft im Laden, verkauft am Dock.",
		CAT_BEGRIFFE)
	_add(KOMBINATION, "Kombination",
		"Die gewertete Hand eines Wurfs: Pasch, Straße, Full House und Verwandte. Was physisch liegt, gewinnt - die höchste Kategorie zählt, nie die punktreichste. Jede Kombination steht als Chip auf dem Filz und lässt sich dort mit Energie übertakten.",
		CAT_BEGRIFFE)
	_add(BENCHMARK, "Benchmark",
		"Das Rundenziel: die Punktzahl, die die Runde besteht. Der Benchmark wächst von Runde zu Runde, und jede sechste Runde endet im Stresstest. Was über das Ziel hinausgeht, füllt die Überladungs-Stufen.",
		CAT_BEGRIFFE)
	_add(UEBERLADUNG, "Überladung",
		"Die Stufen über dem Benchmark: jede volle Stufe über dem Rundenziel prägt bei der Auszahlung eine Energie in die Kondensatorbank; was nicht mehr in den Speicher passt, zahlt bar. Der Rahmen fasst fünf Stufen - nur Klauseln bewegen ihn.",
		CAT_BEGRIFFE)
	_add(FUMBLE, "Fumble",
		"Ein Wurf, der keine strikt höhere Kombination bringt als die zuletzt gewählte: die Hand verfällt. Nur der Rang entscheidet - mehr Augen retten nichts. Manche Charms und Klauseln federn den ersten Fumble ab, einige zahlen sogar darauf.",
		CAT_BEGRIFFE)
	_add(STRESSTEST, "Stresstest",
		"Die letzte Runde jedes Benchmark-Blocks (Runde 6, 12, ...). Statt der üblichen Verträge liegen nur Malus-Konditionen aus - die Wahl ist, WIE gekämpft wird, nicht wofür. Wer besteht, bekommt ein versiegeltes Würfel-Paket mit garantierter Essenz.",
		CAT_BEGRIFFE)
	_add(VERTRAG, "Vertrag",
		"Ab Runde 2 bietet das Haus drei Verträge: Standardvertrag, Risikovertrag, Knebelvertrag - je eine Bonus- und eine Malusklausel derselben Stufe. Kein Vertrag überlebt seine Runde. Gelegentlich ersetzt ein Werbegeschenk (nur Bonus, kein Malus) einen der Plätze.",
		CAT_BEGRIFFE)
	_add(NEBENWETTE, "Nebenwette",
		"Eine Wette neben dem Rundenziel: ein Einsatz auf eine Bedingung dieser Runde, die Punktziele skalieren mit dem Benchmark. Manche Einsätze kosten nichts im Voraus und besteuern stattdessen jede Hand oder jeden Würfel - reicht das Geld nicht mehr, platzt die Wette.",
		CAT_BEGRIFFE)
	_add(MAGAZIN, "Magazin",
		"Die Grube der Werkstatt, in der jedes versiegelte Paket als eigene Kassette steht. Die Kapazität ist gemessen, nicht gesetzt - ist das Magazin voll, zerfällt eine zugesprochene Prämie zu Geld. Tippen öffnet die Kassette, Ziehen sortiert um.",
		CAT_BEGRIFFE)
	_add(PRESSE, "Presse",
		"Die Maschine der Werkstatt: versiegelte Pakete stecken in den Lesern und werden in einem Griff zu Gravuren gepresst - 1, 3 oder 5 Stück je Paket. Die erste Pressung der Runde ist frei, danach steigt der Preis in Energie. Die Beute liegt auf dem Glas und wird von Hand gesetzt.",
		CAT_BEGRIFFE)
	_add(SCHWARZMARKT, "Schwarzmarkt",
		"Das Hinterzimmer des Casinos, freigeschaltet mit Lizenzstufe 5. Drei Plätze - legendärer Charm, Sonderposten-Bündel, Wildcard - bezahlt in Energie statt Geld. Geheime Essenzen gibt es nur hier.",
		CAT_BEGRIFFE)
	_add(UEBERTAKTEN, "Übertakten",
		"Der Ausbau einer Kombination direkt an ihrem Chip: die nächste Stufe kostet Energie (1 + Stufe, höchstens 5 ⚡) und hebt Basispunkte und Mult. Es gibt kein Stufen-Limit - die Kondensatorbank ist die einzige Bremse.",
		CAT_BEGRIFFE)

## Item-Einträge aus den data/-Katalogen. Spiegel-Gravuren (Material/Rune/
## Sonderposten) werden ALIAS statt Dublette: ihr Eintrag IST der des Ziels.
static func _build_items() -> void:
	for charm in Charm.all():
		var rarity: String = CHARM_RARITY_NAMES.get(charm.rarity, "?")
		_add("charm:%s" % charm.id, charm.display_name,
			"%s\nSeltenheit: %s" % [charm.description, rarity], CAT_CHARMS)
	for essence in Essence.all():
		var body := "%s\nSeltenheit: %s" % [essence.description, Essence.rarity_name(essence.rarity)]
		if essence.secret:
			body += "\nSchwarzmarktware."
		_add("essence:%s" % essence.id, essence.display_name, body, CAT_ESSENZEN)
	for material in DieMaterial.all():
		var body := material.description
		if material.description_doped != "":
			body += "\nVeredelt: %s" % material.description_doped
		_add("material:%s" % material.id, material.display_name, body, CAT_MATERIALIEN)
	for rune in Rune.all():
		_add("rune:%s" % rune.id, rune.display_name,
			"%s\nKlasse: %s" % [rune.description, rune.kind], CAT_RUNEN)
	for engraving in Engraving.all():
		var id := "engraving:%s" % engraving.id
		if Engraving.is_rune_id(engraving.id):
			_aliases[id] = "rune:%s" % Engraving.rune_id_of(engraving.id)
		elif DieMaterial.is_valid_id(engraving.id):
			_aliases[id] = "material:%s" % engraving.id
		elif engraving.id == Engraving.POINTER:
			_aliases[id] = POINTER
		elif engraving.id == Engraving.DOPING:
			_aliases[id] = VEREDELUNG
		else:
			_add(id, engraving.display_name,
				"%s\nZahl-Gravur, %s." % [engraving.description,
					Engraving.rarity_name(engraving.rarity)], CAT_GRAVUREN)
	for clause in DealClause.all():
		var kind := "Bonusklausel" if clause.kind == DealClause.Kind.BONUS else "Malusklausel"
		_add("clause:%s" % clause.id, clause.display_name,
			"%s\n%s eines Vertrags mit dem Haus." % [DealClause.text_for(clause.id, 1), kind],
			CAT_KLAUSELN)

## Titel + Zusatzformen -> ids. Bei Namenskollision (z. B. Rampenlicht als Charm
## UND Klausel) gewinnt der zuerst Eingetragene - Konzepte vor Items, Items in
## Katalog-Reihenfolge; der Verlierer bleibt als Eintrag über den Index erreichbar.
static func _build_surfaces() -> void:
	for surface: String in EXTRA_SURFACES:
		_surfaces[surface] = EXTRA_SURFACES[surface]
	for category in CATEGORIES:
		for id: String in _entries:
			var e: Dictionary = _entries[id]
			if e["category"] != category:
				continue
			var title: String = e["title"]
			if not _surfaces.has(title):
				_surfaces[title] = id

## EIN Muster für alle Formen: Alternation längste zuerst (der erste Treffer
## gewinnt, also gewinnt der längste), Wortgrenzen als Lookarounds über deutsche
## Buchstaben - der Bindestrich zählt NICHT, damit "Gold-Seite" das Gold trifft.
static func _compile_pattern() -> void:
	var forms: Array = _surfaces.keys()
	forms.sort_custom(func(a: String, b: String) -> bool:
		return a.length() > b.length() if a.length() != b.length() else a < b)
	var escaped: Array[String] = []
	for form: String in forms:
		escaped.append(_regex_escape(form))
	var boundary := "A-Za-z0-9ÄÖÜäöüß"
	_pattern = RegEx.new()
	_pattern.compile("(?<![%s])(?:%s)(?![%s])" % [boundary, "|".join(escaped), boundary])

static func _regex_escape(text: String) -> String:
	var out := ""
	for ch in text:
		var code := ch.unicode_at(0)
		# Alle ASCII-Sonderzeichen panzern; Buchstaben, Ziffern und Unicode nicht.
		if code < 128 and not ((code >= 48 and code <= 57) or (code >= 65 and code <= 90)
				or (code >= 97 and code <= 122) or ch == "_"):
			out += "\\"
		out += ch
	return out
