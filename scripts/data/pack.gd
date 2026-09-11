class_name Pack
extends Resource
## Ein versiegeltes Paket: alles Gravierbare wird SO gehandelt und erst an der
## Presse geöffnet. Der Inhalt wird ERST dort ausgewürfelt - der Kauf entscheidet
## nur die Sorte. Würfel sind keine Paketware: sie liegen offen im Laden und
## fahren gekauft ins Ausgabefach. ids sind Konstanten, damit Tippfehler
## Compilerfehler sind.
##
## Jede Kassette trägt ein PRÄGENETZ (StampNet): sechs Zellen, eine je Würfelseite,
## bei der ERZEUGUNG gewürfelt und ab da fix und sichtbar. Mehrere Kassetten in
## Serie gesteckt summieren ihre Netze und projizieren sie in EINEM Akt auf einen
## Würfel (SeriesResolver) - die Größe entscheidet, wie dicht und wie stark ein
## Netz besetzt ist.

## Paketsorten - alle drei bilden auf Engraving-Kategorien ab (siehe
## engraving_category). Würfel werden NIE versiegelt: sie gehen als Ware direkt
## ins Ausgabefach (GameRun.stash_die), egal ob gekauft, gewonnen oder gewährt.
const TYPE_NUMBER := "number"
const TYPE_MATERIAL := "material"
## Runen-Paket: liegt seit dem Werkstatt-Umbau auch im Regal, nicht mehr nur im
## Automaten.
const TYPE_DICE_MOD := "dice_mod"

## Ein Gravur-Paket = ein Prägenetz. Die Zahl steht als Konstante, damit niemand
## sie an einer Fabrik wieder aufbläht; > 1 heißt Bündel: so viele EINZELNE Karten
## (nur die Hinterzimmer-Auslage), nie mehr Zellen auf einer.
const ENGRAVING_PACK_COUNT := 1

## Die drei PAKETGRÖSSEN. Standard ist die unmarkierte Norm, Groß und Kolossal
## stehen als Adjektiv im Namen. Die Größe entscheidet allein die WURFTABELLE des
## Prägenetzes (StampNet): Dichte und Magnitude der Zellen, sonst nichts.
const TIER_NORMAL := 0
const TIER_GROSS := 1
const TIER_KOLOSSAL := 2

## Adjektiv vor dem Sortennamen - Standard trägt keins, er ist der Normalfall.
## Alle Sortennamen enden auf "-Paket" (sächlich), darum passt eine Form je Größe.
const TIER_ADJECTIVES := {TIER_GROSS: "Großes", TIER_KOLOSSAL: "Kolossales"}
## Dieselben Adjektive im Plural ("2 Große Zahlen-Pakete"). Eigene Tabelle, denn
## ein abgeschnittenes "s" wäre eine Regel, die nur zufällig zweimal stimmt.
const TIER_ADJECTIVES_PLURAL := {TIER_GROSS: "Große", TIER_KOLOSSAL: "Kolossale"}
## Wie die Größe heißt, wo sie ALLEIN steht (Hinweiszeile, Netz-Auskunft).
const TIER_LABELS := {TIER_NORMAL: "Standard", TIER_GROSS: "Groß",
	TIER_KOLOSSAL: "Kolossal"}

## Preisfaktoren der Größen. Der Aufschlag ist der Preis der DICHTE: mehr Zellen
## und höhere Werte auf EINER Karte, also aus einem Magazin-Platz und einem
## Serien-Slot (und die Serie ist kurz).
const TIER_PRICE_FACTORS := [1.0, 3.45, 5.75]
## Auslage-Gewichte der Größen: die Norm liegt meistens da, das Kolossale selten.
const TIER_WEIGHTS := [0.6, 0.3, 0.1]

## Preise je 1er-Paket - Runen sind die teuerste Sorte, sechs Zahlen-Pakete sind
## der Lauf auf den Sechserpasch.
const NUMBER_PRICE := 5
const MATERIAL_PRICE := 6
const DICE_MOD_PRICE := 7

## Auslage-Gewichte der Gravur-Pakete (relativ).
const SHELF_WEIGHTS := {
	TYPE_NUMBER: 6,
	TYPE_MATERIAL: 3,
	TYPE_DICE_MOD: 2,
}

const TYPE_NAMES := {
	TYPE_NUMBER: "Zahlen-Paket",
	TYPE_MATERIAL: "Material-Paket",
	TYPE_DICE_MOD: "Runen-Paket",
}

@export var type: String = TYPE_NUMBER
## Paketgröße (TIER_*). Nur Gravur-Pakete ohne Fixinhalt tragen eine - ein
## Würfel-Paket presst nie, ein Fixinhalt würfelt nichts aus.
@export var tier: int = TIER_NORMAL
@export var display_name: String = ""
@export var description: String = ""
@export var count: int = 1
@export var price: int = 0
## Identität im Lager: GameRun stempelt sie beim Einlagern (_stash_pack). 0 = noch
## nie eingelagert. An ihr hängen Magazin-Platz, Liefer-Vormerkung und Körper.
@export var pack_uid: int = 0
## Genau DIESE Gravur liegt im Paket (Schmuckkästchen, Schwarzmarkt-
## Sonderposten). Ihr Phantomwürfel landet FEST auf diesem Icon und lässt sich
## nicht nachwürfeln - er spielt in der Hand trotzdem mit.
@export var fixed_engraving: Engraving = null
## KATALYSATOR-Kassette (CATALYST_*, "" = keine). Sie trägt gar keinen Inhalt: sie
## verändert die EINE Serie, in der sie steckt, und wird mit ihr verbraucht.
@export var catalyst_id: String = ""
## OPERATOR-Kassette (StampNet.OP_*, "" = keine). Ihr Netz trägt genau eine
## Operator-Zelle; sie ist Sonderbestand, kein Regal-Paket.
@export var operator_id: String = ""
## Das PRÄGENETZ: sechs Zellen (StampNet), bei der Erzeugung gewürfelt und ab da
## fix - es reist mit der Kassette und ist im Laden schon lesbar. Katalysatoren
## tragen ein leeres Netz.
@export var stamp_net: Array = []
## Die REIHE des Regalstapels, in der die Kassette liegt (-1 = noch nicht
## eingelagert). Sie ist Teil der Magazin-Ordnung, also Spielstand: eine Karte
## rutscht nur INNERHALB ihrer Reihe nach, ein Zug darf die Reihe wechseln.
@export var shelf_row: int = -1

static func _make(pack_type: String, amount: int, cost: int, desc: String) -> Pack:
	var pack := Pack.new()
	pack.type = pack_type
	pack.display_name = TYPE_NAMES.get(pack_type, pack_type)
	pack.count = amount
	pack.price = cost
	pack.description = desc
	pack.stamp_net = StampNet.empty_net()
	return pack

## --- Die Paketgröße ---------------------------------------------------------

static func tier_label(pack_tier: int) -> String:
	return String(TIER_LABELS.get(pack_tier, TIER_LABELS[TIER_NORMAL]))

## Das Adjektiv einer Größe im passenden Numerus ("" bei Standard) - eine Quelle
## für den Paketnamen und für jede Anzeige, die Beute in Mehrzahl nennt.
static func tier_adjective(pack_tier: int, amount: int = 1) -> String:
	var table: Dictionary = TIER_ADJECTIVES if amount == 1 else TIER_ADJECTIVES_PLURAL
	return String(table.get(pack_tier, ""))

## Die EINE Formulierung einer Paket-MENGE: Zahl, Größe, Sorte ("2 Große
## Material-Pakete", "1 Zahlen-Paket"). Namensquellen sind TYPE_NAMES und
## tier_adjective - wer Ware in Worten nennt, nennt sie hier und nirgends sonst.
static func amount_phrase(pack_type: String, pack_tier: int, amount: int) -> String:
	var sort := "%s%s" % [String(TYPE_NAMES.get(pack_type, pack_type)),
		"" if amount == 1 else "e"]
	var adjective := tier_adjective(pack_tier, amount)
	if adjective == "":
		return "%d %s" % [amount, sort]
	return "%d %s %s" % [amount, adjective, sort]

static func tier_price_factor(pack_tier: int) -> float:
	if pack_tier < 0 or pack_tier >= TIER_PRICE_FACTORS.size():
		return 1.0
	return float(TIER_PRICE_FACTORS[pack_tier])

## Darf dieses Paket überhaupt eine Größe tragen? Ein Fixinhalt trägt genau seinen
## Inhalt, ein Katalysator gar keinen und ein Operator genau eine Zelle - alle drei
## sind größenlos.
static func tierable(pack: Pack) -> bool:
	return pack != null and pack.fixed_engraving == null and pack.catalyst_id == "" \
		and pack.operator_id == ""

## Setzt einem Gravur-Paket seine Größe auf: Name, Preis UND Prägenetz wachsen mit.
## Der eine Weg - ein anderswo gesetztes tier bliebe ohne Aufschrift, ohne Preis
## und mit dem Netz der kleinen Größe.
static func tiered(pack: Pack, pack_tier: int, rng: RandomNumberGenerator = null) -> Pack:
	if not tierable(pack) or pack_tier == TIER_NORMAL:
		return pack
	pack.tier = pack_tier
	pack.display_name = "%s %s" % [tier_adjective(pack_tier), pack.display_name]
	pack.price = int(roundf(float(pack.price) * tier_price_factor(pack_tier)))
	pack.stamp_net = StampNet.roll(pack.engraving_category(), pack_tier, rng)
	return pack

## Gewichteter Griff in die Größen-Tabelle (60 / 30 / 10 %).
static func roll_tier(rng: RandomNumberGenerator = null) -> int:
	var roll := rng.randf() if rng != null else randf()
	var sum := 0.0
	for i in TIER_WEIGHTS.size():
		sum += float(TIER_WEIGHTS[i])
		if roll < sum:
			return i
	return TIER_WEIGHTS.size() - 1

## Was auf dem Netz dieser Kassette steht - eine Zeile für Laden und Werkbank.
static func net_line(pack: Pack) -> String:
	if pack == null:
		return ""
	if pack.is_catalyst():
		return catalyst_effect(pack.catalyst_id)
	return StampNet.line(pack.stamp_net)

## Was eine Kassette WIRKT, in voller Länge: ihre Beschreibung und die Zeile ihres
## Prägenetzes. EINE Quelle - Laden-Flanke wie Werkstatt-Info lesen sie.
static func info_body(pack: Pack) -> String:
	if pack == null:
		return ""
	var net := net_line(pack)
	if net == "" or pack.description.contains(net):
		return pack.description
	return "%s\n%s" % [pack.description, net]

static func number_pack(rng: RandomNumberGenerator = null) -> Pack:
	var pack := _make(TYPE_NUMBER, ENGRAVING_PACK_COUNT, NUMBER_PRICE,
		"Ein Prägenetz aus Zahl-Zellen, versiegelt.")
	pack.stamp_net = StampNet.roll(Engraving.CATEGORY_NUMBER, TIER_NORMAL, rng)
	return pack

static func material_pack(rng: RandomNumberGenerator = null) -> Pack:
	var pack := _make(TYPE_MATERIAL, ENGRAVING_PACK_COUNT, MATERIAL_PRICE,
		"Ein Prägenetz aus Material-Zellen, versiegelt.")
	pack.stamp_net = StampNet.roll(Engraving.CATEGORY_MATERIAL, TIER_NORMAL, rng)
	return pack

static func dice_mod_pack(rng: RandomNumberGenerator = null) -> Pack:
	var pack := _make(TYPE_DICE_MOD, ENGRAVING_PACK_COUNT, DICE_MOD_PRICE,
		"Ein Prägenetz aus Runen-Zellen, versiegelt.")
	pack.stamp_net = StampNet.roll(Engraving.CATEGORY_DICE, TIER_NORMAL, rng)
	return pack

## Fester Goldpreis eines Sonderposten-Einzelstücks im normalen Regal - er hängt
## weder an der Sorte noch an der Lizenz. Bündel gibt es nur im Hinterzimmer.
const SPECIAL_PRICE := 30

## Fixinhalt-Paket: sein Netz trägt GENAU EINE Zelle dieses Inhalts. amount > 1 ist
## das BÜNDEL der Hinterzimmer-Auslage - so viele Karten, jede mit einer Zelle; der
## Kauf legt sie einzeln ins Magazin, die Auslage zeigt den Stapel mit seiner Zahl.
## Preis 0 ist der Regelfall: so etwas wird gefunden oder abgegossen; nur der
## Handel setzt einen.
static func fixed_engraving_pack(engraving: Engraving, amount := ENGRAVING_PACK_COUNT,
		cost := 0, rng: RandomNumberGenerator = null) -> Pack:
	if engraving == null:
		return number_pack(rng)
	var many := maxi(amount, 1)
	var text := "%s, versiegelt." % engraving.display_name if many == 1 \
		else "%d Karten %s, versiegelt." % [many, engraving.display_name]
	var pack := _make(pack_type_for_category(engraving.category), many, cost, text)
	pack.display_name = engraving.display_name
	pack.fixed_engraving = engraving
	pack.stamp_net = StampNet.fixed_net(engraving, rng)
	return pack

## --- Die OPERATOR-KASSETTEN ---------------------------------------------------
## Sonderbestand mit genau EINER Operator-Zelle (StampNet.OPERATORS). Sie rechnen
## nur im Zahl-Kanal und auf der bis dahin aufgelaufenen Summe - ihre Position in
## der Serie IST ihre Stärke.

static func operator_pack(op_id: String, rng: RandomNumberGenerator = null) -> Pack:
	if not StampNet.is_operator_id(op_id):
		return null
	var pack := _make(TYPE_NUMBER, 1, StampNet.operator_price(op_id),
		"%s. Wirkt an seiner Stelle in der Serie auf die aufgelaufene Summe." \
			% StampNet.operator_effect(op_id))
	pack.display_name = StampNet.operator_name(op_id)
	pack.operator_id = op_id
	pack.stamp_net = StampNet.operator_net(op_id, rng)
	return pack

## --- Die KATALYSATOR-KASSETTEN ------------------------------------------------
## Sonderbestand wie die Gravur-Sonderposten, aber ohne jedes Netz: eine solche
## Kassette prägt nichts, sie verändert die EINE Serie, in der sie steckt, und
## brennt mit ihr aus. Ihr Preis ist der Serien-Slot, den sie besetzt - deshalb
## gibt es keinen eigenen Katalysator-Schacht.

const CATALYST_PROPELLANT := "propellant"
const CATALYST_TIMER := "timer"
const CATALYST_MATRIX := "matrix"
const CATALYST_GROUND := "ground"

## Die EINE Tabelle der vier Karten: Name, Wirkzeile und Ladenpreis. Die Wirkung
## selbst liegt in GameRun.catalyst_terms - hier steht nur, was auf dem Schild
## steht (und die Reihenfolge, in der sie ausgewürfelt werden).
const CATALYSTS := {
	CATALYST_PROPELLANT: {"name": "Treibladung", "price": 14,
		"effect": "+1 auf jede gefüllte Zahl-Zelle des Summen-Netzes"},
	CATALYST_TIMER: {"name": "Taktgeber", "price": 14,
		"effect": "Serienlänge dauerhaft +1",
		"scope": "Wirkt für den ganzen Lauf und wird beim Griff verbraucht."},
	CATALYST_MATRIX: {"name": "Doppelmatrize", "price": 18,
		"effect": "Die Projektion trifft einen zweiten Würfel mit halbierten Zahl-Boni"},
	CATALYST_GROUND: {"name": "Erdungsklemme", "price": 8,
		"effect": "Dieser Griff verbraucht die Pressung der Runde nicht"},
}

## Der Satz, der jede Katalysator-Karte beschließt - eine Quelle, damit Regal,
## Magazin und Hinterzimmer dieselbe Zusage geben. Der Taktgeber schreibt ihn um:
## seine Wirkung überlebt die Serie.
const CATALYST_SCOPE := "Wirkt auf die Serie, in der sie steckt, und wird mit ihr verbraucht."

static func catalyst_scope(id: String) -> String:
	return String(Dictionary(CATALYSTS.get(id, {})).get("scope", CATALYST_SCOPE))

static func catalyst_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(CATALYSTS.keys())
	return ids

static func catalyst_name(id: String) -> String:
	return String(Dictionary(CATALYSTS.get(id, {})).get("name", ""))

## Die Wirkzeile allein (ohne den Zusatz) - Karte, Hover und Test lesen sie hier.
static func catalyst_effect(id: String) -> String:
	return String(Dictionary(CATALYSTS.get(id, {})).get("effect", ""))

static func catalyst_price(id: String) -> int:
	return int(Dictionary(CATALYSTS.get(id, {})).get("price", 0))

## Eine Katalysator-Kassette (null bei unbekannter id - eine namenlose Karte im
## Magazin wäre schlimmer als gar keine).
static func catalyst(id: String) -> Pack:
	if not CATALYSTS.has(id):
		return null
	var pack := _make(TYPE_NUMBER, 1, catalyst_price(id),
		"%s. %s" % [catalyst_effect(id), catalyst_scope(id)])
	pack.display_name = catalyst_name(id)
	pack.catalyst_id = id
	return pack

## Schlüssel des Sonderposten-Wurfs, der KEIN Katalysator und kein Operator ist.
const SPECIAL_ENGRAVING := "engraving"

## Gewichte des Sonderposten-Platzes (Prozent). Die beiden Gravur-Sonderposten
## bleiben mit 30 % die Schlagzeile, Katalysatoren und Operatoren teilen sich den
## Rest zu gleichen Teilen - EINE Tabelle, an der Wurf und Test hängen.
const SPECIAL_ROLL_WEIGHTS := {
	SPECIAL_ENGRAVING: 30,
	CATALYST_PROPELLANT: 10,
	CATALYST_TIMER: 10,
	CATALYST_MATRIX: 10,
	CATALYST_GROUND: 10,
	StampNet.OP_DOUBLER: 10,
	StampNet.OP_MIRROR: 10,
	StampNet.OP_COLLECTOR: 10,
}

## Sonderposten fürs normale Regal: welche der DREI Familien, entscheidet der
## Wurf - dass überhaupt einer ausliegt, entscheidet GameRun.shop_special_chance.
static func roll_special_pack() -> Pack:
	var key := _roll_special_key()
	if key != SPECIAL_ENGRAVING:
		var card := catalyst(key)
		if card == null:
			card = operator_pack(key)
		if card != null:
			return card
	return roll_special_engraving_pack()

## Nur die Gravur-Familie des Sonderbestands. Der Weg jeder QUELLE, die einen
## Sonderposten VERSPRICHT (Füllhorn, Reinraum): dort ist "ein Sonderposten" die
## Zusage, und eine Katalysator-Kassette hielte sie nicht.
static func roll_special_engraving_pack() -> Pack:
	var special := Engraving.by_id(String(Engraving.SPECIAL_IDS.pick_random()))
	if special == null:
		return roll_engraving_pack()
	return fixed_engraving_pack(special, ENGRAVING_PACK_COUNT, SPECIAL_PRICE)

static func _roll_special_key() -> String:
	var total := 0
	for weight: int in SPECIAL_ROLL_WEIGHTS.values():
		total += weight
	var pick := randi() % maxi(total, 1)
	for key: String in SPECIAL_ROLL_WEIGHTS:
		pick -= int(SPECIAL_ROLL_WEIGHTS[key])
		if pick < 0:
			return key
	return SPECIAL_ENGRAVING

## Paketsorte einer Gravur-Kategorie (Umkehrung von engraving_category).
static func pack_type_for_category(category: String) -> String:
	match category:
		Engraving.CATEGORY_MATERIAL:
			return TYPE_MATERIAL
		Engraving.CATEGORY_DICE:
			return TYPE_DICE_MOD
	return TYPE_NUMBER

## Kanonische Auslage der Gravur-Pakete.
static func all_engraving_packs() -> Array[Pack]:
	return [number_pack(), material_pack(), dice_mod_pack()]

## Frisches Gravur-Paket zur Sorte - damit Tabellen (Hub-Belohnung) mit Typ-ids
## arbeiten können statt mit Fabrik-Referenzen.
static func by_type(pack_type: String) -> Pack:
	match pack_type:
		TYPE_MATERIAL:
			return material_pack()
		TYPE_DICE_MOD:
			return dice_mod_pack()
	return number_pack()

# --- Magazin-Taxonomie: welcher Sorte ein Paket im Lager zugehört -----------------
# Wohnt in data/, weil auch GameRun (tidy_packs) danach sortiert; die Farben dazu
# hält die UI (PackDrawerView.COLORS spiegelt die Schlüssel, Rune.tint-Regel).

## Pseudo-Sorte der Sonderposten (Engraving.SPECIAL_IDS): sie trägt keine
## Gravur-Kategorie, braucht aber ihren Platz im Magazin.
const SHELF_SPECIAL := "special"

## Kanonische Sorten-Reihenfolge - EINE Quelle für Magazin, tidy und Siegel.
const SHELF_ORDER := [Engraving.CATEGORY_NUMBER, Engraving.CATEGORY_MATERIAL,
	Engraving.CATEGORY_DICE, SHELF_SPECIAL]

## Ein Fixinhalt-Paket mit Sonderposten gehört zum Sonderbestand, und die
## Katalysatoren wie die Operatoren liegen als weitere Familien daneben; alles
## andere zählt zu seiner Gravur-Sorte.
static func pack_belongs(pack: Pack, shelf: String) -> bool:
	if pack == null:
		return false
	if pack.is_catalyst() or pack.is_operator():
		return shelf == SHELF_SPECIAL
	var fixed := pack.fixed_engraving
	if fixed != null and Engraving.is_special_id(fixed.id):
		return shelf == SHELF_SPECIAL
	return pack.engraving_category() == shelf

## Die Magazin-Sorte dieses Pakets ("" = keine).
static func shelf_of(pack: Pack) -> String:
	for shelf: String in SHELF_ORDER:
		if pack_belongs(pack, shelf):
			return shelf
	return ""

## Die Umkehrung: der Pakettyp, dessen Siegel diese Sorte zeichnet ("" = der
## Sonderbestand, dessen Zeichen der Eckrahmen ist). EINE Zuordnung, in beide
## Richtungen gelesen - eine zweite Tabelle liefe auseinander.
static func pack_type_of_shelf(shelf: String) -> String:
	for pack_type: String in [TYPE_NUMBER, TYPE_MATERIAL, TYPE_DICE_MOD]:
		if shelf_for_pack_type(pack_type) == shelf:
			return pack_type
	return ""

## Sorte, in der ein Paket dieses Typs landet (Lieferweg des Ladens - dort ist
## nur der Typ bekannt, nie ein Fixinhalt).
static func shelf_for_pack_type(pack_type: String) -> String:
	match pack_type:
		TYPE_MATERIAL:
			return Engraving.CATEGORY_MATERIAL
		TYPE_DICE_MOD:
			return Engraving.CATEGORY_DICE
	return Engraving.CATEGORY_NUMBER

## Name einer Magazin-Sorte: die Paketsorte, die dort wohnt - der Sonderbestand
## trägt keine und nennt sich selbst.
const SHELF_NAME_SPECIAL := "Sonderbestand"

static func shelf_name(shelf: String) -> String:
	if shelf == SHELF_SPECIAL:
		return SHELF_NAME_SPECIAL
	return String(TYPE_NAMES.get(pack_type_of_shelf(shelf), shelf))

## Engraving-Kategorie hinter einer Gravur-Paketsorte ("" bei Würfel-Paketen).
func engraving_category() -> String:
	match type:
		TYPE_NUMBER:
			return Engraving.CATEGORY_NUMBER
		TYPE_MATERIAL:
			return Engraving.CATEGORY_MATERIAL
		TYPE_DICE_MOD:
			return Engraving.CATEGORY_DICE
	return ""

## Eine Katalysator-Kassette? Sie prägt nichts - sie verändert die Serie, in der
## sie steckt.
func is_catalyst() -> bool:
	return catalyst_id != ""

## Eine Operator-Kassette? Ihr Netz trägt genau eine Rechen-Zelle.
func is_operator() -> bool:
	return operator_id != ""

## Sorte des Prägenetzes: die Gravur-Kategorie, aus deren Vorrat seine Zellen
## gewürfelt wurden.
func press_sort() -> String:
	return engraving_category()

## Zufällige Gravur-Paketsorte für einen Auslage-Platz. Bewusst OHNE Hub-Stufe:
## die Sorte entscheiden allein die Regal-Gewichte - stark wird eine Kassette an
## ihrem Netz (Größe, Seltenheits-Gewichte), nicht an der Lizenz.
## Die GRÖSSE kommt von außen: der Laden würfelt sie, jede Prämie prägt Standard.
static func roll_engraving_pack(pack_tier: int = TIER_NORMAL,
		rng: RandomNumberGenerator = null) -> Pack:
	return tiered(by_type(roll_engraving_type()), pack_tier, rng)

## Nur die SORTE, ohne ein Paket zu bauen - dieselben Regal-Gewichte. Der Wett-Tresen
## würfelt sie beim Auslegen und NENNT seinen Gewinn danach beim Namen.
static func roll_engraving_type() -> String:
	var pool: Array[String] = []
	var weights: Array[int] = []
	for pack_type: String in SHELF_WEIGHTS:
		pool.append(pack_type)
		weights.append(SHELF_WEIGHTS[pack_type])
	var total := 0
	for w in weights:
		total += w
	var pick := randi() % total
	for i in pool.size():
		pick -= weights[i]
		if pick < 0:
			return pool[i]
	return TYPE_NUMBER
