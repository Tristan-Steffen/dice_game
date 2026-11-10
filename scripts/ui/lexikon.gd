class_name Lexikon
extends RefCounted
## Das Nachschlagewerk des Tisches: je Begriff ein Eintrag, dazu einer je Charm,
## Essenz, Material, Rune, Gravur, Klausel und Modul (aus den data/-Katalogen erzeugt).
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
const CAT_MODULE := "Module"
const CATEGORIES: Array[String] = [CAT_BEGRIFFE, CAT_CHARMS, CAT_ESSENZEN,
	CAT_MATERIALIEN, CAT_RUNEN, CAT_GRAVUREN, CAT_KLAUSELN, CAT_MODULE]

# --- Konzept-ids (Konvention: Konzepte prefixlos, Items "typ:id") ---
const KRIT := "krit"
const MULT := "mult"
const BASISPUNKTE := "basispunkte"
const ENERGIE := "energie"
const LADUNG := "ladung"
const AUSLOESUNG := "ausloesung"
const RUNE := "rune"
const GRAVUR := "gravur"
const MATERIAL := "material"
const VEREDELUNG := "veredelung"
const POINTER := "pointer"
const ESSENZ := "essenz"
const CHARM := "charm"
const KOMBINATION := "kombination"
const QUOTA := "quota"
const UEBERLADUNG := "ueberladung"
const FUMBLE := "fumble"
const STRESSTEST := "stresstest"
const VERTRAG := "vertrag"
const NEBENWETTE := "nebenwette"
const MAGAZIN := "magazin"
const PRESSE := "presse"
const PRAEGENETZ := "praegenetz"
const SERIE := "serie"
const VERDICHTUNG := "verdichtung"
const SCHWARZMARKT := "schwarzmarkt"
const STECKPLATZ := "steckplatz"
const GLUECK := "glueck"
const RAMPENLICHT := "rampenlicht"
const KARTE := "karte"
const PAKET := "paket"
const OPTION := "option"

## Alle Konzept-ids - test_lexikon hält Liste und _build_concepts() im Gleichschritt.
const CONCEPT_IDS: Array[String] = [KRIT, MULT, BASISPUNKTE, ENERGIE, LADUNG, AUSLOESUNG,
	RUNE, GRAVUR, MATERIAL, VEREDELUNG, POINTER, ESSENZ, CHARM, KOMBINATION,
	QUOTA, UEBERLADUNG, FUMBLE, STRESSTEST, VERTRAG, NEBENWETTE, MAGAZIN,
	PRESSE, PRAEGENETZ, SERIE, VERDICHTUNG, SCHWARZMARKT, STECKPLATZ, GLUECK, RAMPENLICHT,
	KARTE, PAKET, OPTION]

## Oberflächenformen -> Eintrags-id, NUR für Formen abseits der Titel (Flexion,
## Verb, Kompositum) - Titel und display_names ergänzt _build() automatisch.
## Der Bindestrich zählt nicht als Wortgrenze, darum brauchen Komposita wie
## "Überladungs-Stufe" eigene Zeilen. Jede Ziel-id sichert test_lexikon ab.
const EXTRA_SURFACES := {
	"Krits": KRIT, "kritet": KRIT, "Kritet": KRIT,
	"Basispunkten": BASISPUNKTE,
	"⚡": ENERGIE,
	"Blinds": QUOTA,
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
	"Pressung": PRESSE, "Prägen": PRESSE,
	"Verdichten": VERDICHTUNG, "verdichtet": VERDICHTUNG, "Rohling": VERDICHTUNG,
	"Prägenetz": PRAEGENETZ, "Prägenetze": PRAEGENETZ, "Prägenetzes": PRAEGENETZ,
	"Serien": SERIE, "Serienschaltung": SERIE, "Serienlänge": SERIE,
	"Operator": SERIE, "Operatoren": SERIE, "Multiplikator-Netz": SERIE,
	"Karten": KARTE, "Pakete": PAKET, "Option": OPTION, "Optionen": OPTION,
	"Steckplätze": STECKPLATZ, "Modul": STECKPLATZ, "Module": STECKPLATZ,
	# Längste Form gewinnt: der Voll-Kompositum schlägt das nackte "Krit(s)".
	"Tscherenkow-Krit": "essence:cherenkov", "Tscherenkow-Krits": "essence:cherenkov",
}

## Ein Satz je Begriff - die Hover-Karte über einem Schlüsselwort. Items nehmen
## statt dessen die erste Zeile ihres Eintrags (ihre Wirkung).
const SUMMARIES := {
	KRIT: "Multipliziert den Mult, statt zu addieren.",
	MULT: "Der Multiplikator der Wertung: Punkte = Basispunkte × Mult.",
	BASISPUNKTE: "Die linke Hälfte der Wertung: Punkte = Basispunkte × Mult.",
	ENERGIE: "Die Zweitwährung ⚡ für Automaten und Schwarzmarkt.",
	LADUNG: "Hitze eines Würfels von 0 bis 3: je Stufe +1 Mult, an der Spitze droht Durchbrennen.",
	AUSLOESUNG: "Ein Feuern eines gewerteten Würfels: Augen, Material und Charms zählen einmal.",
	RUNE: "Ein Zeichen auf einer Würfelseite mit eigener Wirkung.",
	GRAVUR: "Eine Aufwertung für Würfel, getragen von einer Karte.",
	MATERIAL: "Die Belegung einer Würfelseite, etwa Rubin, Gold oder Glas.",
	VEREDELUNG: "Die starke Form eines Materials.",
	POINTER: "Eine Netz-Zelle, die den Stand ihrer Seite auf die Nachbarseite kopiert.",
	ESSENZ: "Die angeborene Seele eines Würfels mit eigener Wirkung.",
	CHARM: "Ein Glücksbringer am Dock, höchstens sechs zugleich.",
	KOMBINATION: "Die gewertete Hand eines Wurfs, etwa Paar oder Straße.",
	QUOTA: "Die Punktzahl, die eine Runde besteht.",
	UEBERLADUNG: "Jede volle Stufe über dem Blind bringt bei der Auszahlung ⚡.",
	FUMBLE: "Ein Wurf ohne bessere Kombination: die Hand verfällt.",
	STRESSTEST: "Die letzte Runde jedes Blocks, unter einer Boss-Kondition.",
	VERTRAG: "Ein Angebot des Hauses aus Bonus- und Malusklausel.",
	NEBENWETTE: "Ein Einsatz auf eine Bedingung dieser Runde.",
	MAGAZIN: "Die Grube der Werkstatt, in der deine Karten liegen.",
	PRESSE: "Prägt die gesteckte Serie auf einen gewählten Würfel.",
	PRAEGENETZ: "Das Würfelnetz einer Karte: was sie auf jede Seite prägt.",
	SERIE: "Die gesteckten Karten, seitenweise aufaddiert.",
	VERDICHTUNG: "Presst mehrere Karten in einem Rohling zu einer.",
	SCHWARZMARKT: "Das Hinterzimmer: seltene Ware gegen ⚡.",
	STECKPLATZ: "Platz für ein Modul auf einem Kombinations-Chip.",
	GLUECK: "Steigt je geschaffter Runde und hebt die Qualität im Laden.",
	KARTE: "Eine Data-Card mit Prägenetz, die die Presse auf einen Würfel prägt.",
	PAKET: "Versiegelte Ladenware: geöffnet zeigt es Optionen, du nimmst eine Zahl davon.",
	OPTION: "Was ein geöffnetes Paket zeigt; die Wahlen sagen, wie viele du nimmst.",
	RAMPENLICHT: "Je Runde pulst eine Kombination golden; gewertet wächst sie dauerhaft um +1 Mult und +5 Basispunkte.",
}

## Rarität der Charms als Spielerwort (Charm.rarity ist ein String).
const CHARM_RARITY_NAMES := {
	Charm.RARITY_COMMON: "häufig",
	Charm.RARITY_UNCOMMON: "ungewöhnlich",
	Charm.RARITY_RARE: "selten",
	Charm.RARITY_LEGENDARY: "legendär",
}

## Wirk-Phase eines Moduls als Spielerwort.
const PART_PHASE_NAMES := {
	ComboPart.PHASE_COMBO: "Kombination",
	ComboPart.PHASE_DIE: "Würfel",
	ComboPart.PHASE_CRIT: "Krit",
	ComboPart.PHASE_ECONOMY: "Ertrag",
	ComboPart.PHASE_LINK: "Verbindung",
	ComboPart.PHASE_NONE: "keine",
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

## Ein Satz für die Hover-Karte eines Schlüsselworts.
static func summary(id: String) -> String:
	var e := entry(id)
	if e.is_empty():
		return ""
	var key := String(e["id"])
	if SUMMARIES.has(key):
		return SUMMARIES[key]
	return String(e["body"]).get_slice("
", 0)

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

## Der Text als Stücke [{text, id}] - id "" für schlichten Text. Dieselbe
## Erkennung wie linkify, aber ohne BBCode (für LexikonText).
static func spans(text: String, exclude_id := "") -> Array[Dictionary]:
	_build()
	var out: Array[Dictionary] = []
	var cursor := 0
	for m in _pattern.search_all(text):
		var id: String = _surfaces[m.get_string()]
		if id == exclude_id:
			continue
		if m.get_start() > cursor:
			out.append({"text": text.substr(cursor, m.get_start() - cursor), "id": ""})
		out.append({"text": m.get_string(), "id": id})
		cursor = m.get_end()
	if cursor < text.length():
		out.append({"text": text.substr(cursor), "id": ""})
	return out

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
		"Die Betriebswährung des Casinos, angezeigt als ⚡ und gelagert im Energie-Ring. Energie entsteht aus abgeräumten Überladungs-Stufen, aus Klauseln, Nebenwetten, der Rune Funkenflug und aus Charms. Ausgegeben wird sie an den Automaten und im Schwarzmarkt.",
		CAT_BEGRIFFE)
	_add(LADUNG, "Ladung",
		"Jeder Würfel trägt eine Ladung von 0 bis 3 (Glimmen, Kriechstrom, Überschlag), und jede Ladung ist +1 Mult für seine Hand. Jede Auslösung eines gewerteten Würfels würfelt auf +1; wer mit Überschlag in eine Hand geht, würfelt statt dessen aufs Durchbrennen. Ein durchgebrannter Würfel zählt weiter für die Kombination, liefert aber keine Augen und feuert nichts - erst die goldene Generalüberholung aus dem Schwarzmarkt holt ihn beim Prägen in der Werkstatt zurück; Kühlrippe und Kältebad senken die Ladung nach dem Prägen, durchgebrannte Würfel retten sie nicht. Wer eine Runde lang nicht gewertet hat, verliert eine Stufe.",
		CAT_BEGRIFFE)
	_add(AUSLOESUNG, "Auslösung",
		"Ein volles Feuern eines gewerteten Würfels: Augen, Material und Charms zählen einmal. Essenzen wie Argon lassen den ganzen Würfel mehrfach auslösen, die Rune Nachglühen legt je Seite eine Auslösung obendrauf - Würfel-Faktor und Seiten-Faktor multiplizieren sich.",
		CAT_BEGRIFFE)
	_add(RUNE, "Rune",
		"Ein in die Würfelschale geätztes Zeichen, das den Kernlicht-Funken des Würfels anzapft - die Tönung ist die Wirkung. Jede Seite trägt höchstens eine Rune; nur das Vakuum erlaubt zwei. Runen kommen als Gravur von Runen-Karten über die Presse.",
		CAT_BEGRIFFE)
	_add(GRAVUR, "Gravur",
		"Die Aufwertungs-Art der Werkstatt. Zahl-Gravuren verändern Augen, Material-Gravuren belegen eine Seite, Würfel-Gravuren (Pointer, Runen) wirken über die Seite hinaus. Eine Gravur existiert nur auf einer Karte oder angewendet - gepresst in der Presse und von Hand auf die eingespannten Würfel gesetzt.",
		CAT_BEGRIFFE)
	_add(MATERIAL, "Material",
		"Die Belegung einer einzelnen Würfelseite: Rubin, Bernstein, Gold, Knochen, Glas oder Kupfer. Ein Material wirkt, wenn seine Seite in der Kombination liegt. Die Veredelung hebt es in seine starke Form.",
		CAT_BEGRIFFE)
	_add(VEREDELUNG, "Veredelung",
		"Der starke Zustand eines Materials: die Veredelung sättigt die Glasur einer Seite, die schon ein Material trägt - es wirkt fortan in seiner starken Form (Rubin etwa kritet ×2, statt Mult zu addieren). Nackte und schon veredelte Seiten sind kein Ziel. Zu haben als Sonderposten im Laden und im Schwarzmarkt.",
		CAT_BEGRIFFE)
	_add(POINTER, "Pointer",
		"Eine Zelle im Prägenetz, die über eine Kante zur Nachbarseite zeigt: Beim Prägen kopiert sie alles, was die Serie bis zu ihrer Etage auf ihre Seite gelegt hat - Zahl, Material, Runen, Veredelung, nie die Grundaugen - auf die Zielseite und überdeckt dort. Alle Pointer einer Karte lesen den Stand vor der Karte; über mehrere Etagen lassen sie sich zu Ketten legen. Trägt die Seite noch nichts, verpufft er. Zu haben als epischer Sonderposten.",
		CAT_BEGRIFFE)
	_add(ESSENZ, "Essenz",
		"Die Seele eines Würfels: ein Leuchtgas, beim Guss in der Schale versiegelt. Sie ist angeboren - kein Auftragen, kein Entfernen, kein Tauschen. Die Essenz ist der einzige Faktor auf der Würfel-Achse der Auslösungen, und ihr Glühen färbt die Kanten. Geheime Seelen führt nur der Schwarzmarkt.",
		CAT_BEGRIFFE)
	_add(CHARM, "Charm",
		"Ein Glücksbringer am Dock des Tisches, höchstens sechs zugleich. Würfelgebundene Charms feuern mit ihrem Würfel, statische nach allen Würfeln in Dock-Reihenfolge - die Reihenfolge ist spielentscheidend. Gekauft im Laden, verkauft am Dock.",
		CAT_BEGRIFFE)
	_add(KOMBINATION, "Kombination",
		"Die gewertete Hand eines Wurfs: Pasch, Straße, Full House und Verwandte. Was physisch liegt, gewinnt - die höchste Kategorie zählt, nie die punktreichste. Jede Kombination steht als Chip auf dem Filz und trägt drei Steckplätze für Module.",
		CAT_BEGRIFFE)
	_add(QUOTA, "Blind",
		"Die Punktzahl, die eine Runde besteht. Er startet bei 150 und wächst je Runde um 10 % im ersten Block, um 15 % im zweiten, 20 % im dritten und so fort; gezeigt wird er abgerundet auf volle 5. Verträge heben oder senken ihn DAUERHAFT, jede sechste Runde ist eine Boss-Runde. Was über das Ziel hinausgeht, füllt die Überladungs-Stufen.",
		CAT_BEGRIFFE)
	_add(UEBERLADUNG, "Überladung",
		"Die Stufen über dem Blind: jede volle Stufe über dem Rundenziel prägt bei der Auszahlung eine Energie in den Energie-Ring; was nicht mehr in den Speicher passt, zahlt bar. Der Rahmen fasst fünf Stufen - nur Klauseln bewegen ihn.",
		CAT_BEGRIFFE)
	_add(FUMBLE, "Fumble",
		"Ein Wurf, der keine strikt höhere Kombination bringt als die zuletzt gewählte: die Hand verfällt. Nur der Rang entscheidet - mehr Augen retten nichts. Jeder echte Fumble zählt im Lauf mit, der Zähler sinkt nie: Charms wie Pechvogel oder Fumble-Rente, Module wie der Fehlerspeicher und die Automaten lesen ihn. Manche Charms und Klauseln federn den ersten Fumble ab - ein verziehener zählt nicht.",
		CAT_BEGRIFFE)
	_add(STRESSTEST, "Boss-Runde",
		"Die letzte Runde jedes Blocks (Runde 6, 12, ...). Statt der üblichen Verträge liegen nur Malus-Konditionen aus - die Wahl ist, WIE gekämpft wird, nicht wofür. Wer besteht, bekommt einen Würfel mit garantierter Essenz.",
		CAT_BEGRIFFE)
	_add(VERTRAG, "Vertrag",
		"Ab Runde 2 bietet das Haus drei Verträge: Standardvertrag, Risikovertrag, Knebelvertrag - je eine Bonus- und eine Malusklausel derselben Stufe. Die meisten Klauseln gelten nur ihre Runde, aber Blind-Aufschläge und Eichung verändern den Blind DAUERHAFT, und Glücks-Klauseln drehen am Glück. Gelegentlich ersetzt ein Werbegeschenk (nur Bonus, kein Malus) einen der Plätze.",
		CAT_BEGRIFFE)
	_add(NEBENWETTE, "Nebenwette",
		"Eine Wette neben dem Rundenziel: ein Einsatz auf eine Bedingung dieser Runde, ihre Zielwerte skalieren mit dem Blind. Manche Einsätze kosten nichts im Voraus und besteuern stattdessen jede Hand oder jeden Würfel - reicht das Geld nicht mehr, platzt die Wette.",
		CAT_BEGRIFFE)
	_add(MAGAZIN, "Magazin",
		"Die Grube der Werkstatt, in der jede Karte als eigene Kassette liegt. Die Kapazität ist gemessen, nicht gesetzt - ist das Magazin voll, zerfällt eine zugesprochene Prämie zu Geld. Tippen öffnet die Kassette, Ziehen sortiert um.",
		CAT_BEGRIFFE)
	_add(PRESSE, "Presse",
		"Die Maschine der Werkstatt: die gesteckten Kassetten bilden eine Serie, und EIN Prägen projiziert ihr Summen-Netz auf einen selbst gewählten Würfel. Es wird nichts mehr gewürfelt - die Vorschau zeigt vorher genau das Ergebnis. Geprägt wird so oft man will, aber jedes Prägen heizt den Zielwürfel um eine Ladung auf.",
		CAT_BEGRIFFE)
	_add(PRAEGENETZ, "Prägenetz",
		"Das aufgedruckte Würfelnetz einer Kassette: sechs Zellen, eine je Würfelseite, und je Zelle genau eines - ein Zahl-Bonus, ein Material, eine Rune, eine Veredelung, ein Pointer oder ein Operator. Es wird bei der Herstellung gewürfelt, steht ab da fest und liegt im Laden offen: der Zufall lebt im Angebot, nicht an der Maschine. Wie dicht und wie stark ein Netz besetzt ist, entscheidet die Kartengröße (Standard, Groß, Kolossal).",
		CAT_BEGRIFFE)
	_add(SERIE, "Serie",
		"Die Schaltung der Werkstatt: bis zu mehrere Kassetten stecken nebeneinander, und ihre Prägenetze werden seitenweise von links nach rechts aufaddiert. Ein Operator (×2, Spiegel, Sammler) und ein lilanes Multiplikator-Netz rechnen auf der bis dahin aufgelaufenen Summe - die Grundzahl des Würfels vervielfachen sie nie, die Reihenfolge ist darum die Entscheidung. Die Reihe hat SECHS Slots, und das Prägen zündet schon mit einer Karte. Liegt statt eines Würfels ein Rohling auf dem Podest, VERDICHTET dieselbe Reihe statt zu prägen.",
		CAT_BEGRIFFE)
	_add(VERDICHTUNG, "Verdichtung",
		"Mehrere Kassetten werden zu EINER dichteren gepresst. Das Ziel ist ein ROHLING - eine leere Kassette, die es nur im Schwarzmarkt gibt; er liegt dabei auf dem Podest und WIRD die neue Karte, das Futter ist verbraucht. Zahlen und Multiplikatoren ADDIEREN sich dabei (×4 und ×4 werden ×8) und stehen danach als Rechnung auf der Zelle, etwa \"4x+9\": vier mal die aufgelaufene Summe, plus neun. Material und Rune dürfen zusammen auf einer Seite liegen; ein zweites Material verdrängt das erste. Operatoren lassen sich nicht verdichten.",
		CAT_BEGRIFFE)
	_add(SCHWARZMARKT, "Schwarzmarkt",
		"Das Hinterzimmer des Casinos, offen ab Runde 1. Drei Plätze - legendärer Charm, Sonderposten-Bündel, Wildcard - bezahlt in Energie statt Geld. Geheime Essenzen und die goldene Generalüberholung, die einen durchgebrannten Würfel repariert, gibt es nur hier.",
		CAT_BEGRIFFE)
	_add(GLUECK, "Glück",
		"Der Gradmesser des Laufs: jede geschaffte Runde bringt +1 Glück, Glücks-Klauseln in den Verträgen mehr oder weniger. Je 3 Glück steigt die Fortschrittsstufe - sie hebt die Seltenheit im Laden, die Wetten, die Würfel-Angebote und die Automaten.",
		CAT_BEGRIFFE)
	_add(STECKPLATZ, "Steckplatz",
		"Jeder Kombinations-Chip hat drei Steckplätze für Module - Punkte, Mult, zusätzliche Auslösungen und mehr. Flache Module gibt es im Laden, vervielfachende nur im Schwarzmarkt. Gesteckt wird nach dem Kauf, umgesteckt im Laden und vor der Unterschrift.",
		CAT_BEGRIFFE)
	_add(KARTE, "Karte",
		"Eine einzelne Data-Card: sie trägt ein Prägenetz und liegt im Magazin, bis die Presse sie auf einen Würfel prägt. Karten gibt es als Zahlen-, Material- und Runen-Karte in drei Größen - Standard, Groß, Kolossal -, dazu Sonderposten, Operatoren und Katalysatoren. Der Laden verkauft sie in Paketen und auf dem Sonderposten-Platz einzeln; Schwarzmarkt, Automaten, Nebenwetten und Charms liefern auch einzelne.",
		CAT_BEGRIFFE)
	_add(PAKET, "Paket",
		"Versiegelte Ware des Ladens: von außen sieht man nur Art, Sorte und Größe, nie den Inhalt. Karten-Pakete (Zahlen, Material, Runen, Misch) und Würfel-Pakete (Kraft, Serien, Seelen, Material, Misch). Gekauft öffnet es sich in der Wurfgrube und zeigt Optionen: Klein 3 (1 Wahl), Normal 4 (1), Groß 5 (2, mindestens eine Große Karte), Riesig 5 (2, mindestens eine Kolossale). Glück kann eine Wahl mehr bringen, das Riesige selten alle. Gewählte Karten gehen ins Magazin, gewählte Würfel sofort in den Vorrat; Ungewähltes verfällt. Nebenwetten zahlen manchmal ein Paket aus.",
		CAT_BEGRIFFE)
	_add(OPTION, "Option",
		"Was ein geöffnetes Paket in der Wurfgrube zeigt. Erst fallen die Optionen hinein, dann klettert der Zähler auf die Zahl der Wahlen - so viele darfst du nehmen, weniger auch. Neu mischen würfelt die Optionen einmal je Paket neu (1 Energie), die Zahl der Wahlen bleibt.",
		CAT_BEGRIFFE)
	_add(RAMPENLICHT, "Rampenlicht",
		"Je Runde pulst eine Kombination golden. Wertest du sie, wächst sie dauerhaft um +1 Mult und +5 Basispunkte - einmal je Runde. Das Rampenlicht kommt vom gleichnamigen Charm oder aus einer Klausel; eine gedrosselte Kombination steht nie darin.",
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
	for part in ComboPart.all():
		_add("part:%s" % part.id, part.display_name, part_body(part), CAT_MODULE)

## Wirkung, Phase, Seltenheit und Bezugsquelle eines Moduls.
static func part_body(part: ComboPart) -> String:
	var where := "Schwarzmarkt (⚡)" if part.secret else "Laden"
	return "%s\nPhase: %s · Seltenheit: %s\nErhältlich: %s." % [part.description,
		PART_PHASE_NAMES.get(part.phase, part.phase), part.rarity_name(), where]

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
