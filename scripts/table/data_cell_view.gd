class_name DataCellView
extends Node3D
## Die Datenzelle: ein versiegeltes Aufwertungs-Paket als physische Kassette auf
## dem Tisch. Dunkles Gehäuse mit Fensterausschnitt, dahinter ein Kern in der
## Sortenfarbe, davor eine Glasscheibe, an der Unterkante goldene Kontaktfinnen
## und auf dem Glas das Siegelzeichen der Sorte. Rein per Code gebaut wie
## DieBuilder und CapacitorBankView - kein .tscn, kein GLB.
## Drei Regeln des Tisches gelten auch hier: nur EMISSION, keine eigenen Lichter
## (die Bodenkacheln vertragen 16); im Ruhezustand bleibt das Leuchten UNTER der
## Bloom-Schwelle, der Ausbruch (flare) gibt den Kopfraum aus; und die Sortenfarbe
## kommt aus der einen Quelle PackDrawerView.COLORS.
## Bewusst NICHT gespiegelt - dieselbe Regel wie beim Phantomwürfel: sie LIEGT auf
## dem Glas, ihr Spiegelbild fällt also neben sie und schmiert nur den Stapel und
## seine Marke zu (gemessen: ein zweites ×n neben dem echten).
## Der Aufbau ist bewusst schichtweise: das GEHÄUSE bleibt undurchsichtig, allein
## die Scheibe ist alphagemischt und der Kern DAHINTER wieder deckend - der
## Compatibility-Renderer sortiert Durchsichtiges in Durchsichtigem schlecht.

## Zulage über die Würfelkante hinaus: auf Bankdistanz las die Kassette als Karte
## zu klein, Siegel und Kern verschwammen. Ein Drittel mehr ist die Größe, bei der
## beides steht - Möbel neben den Würfeln, immer noch kein Klotz.
const SIZE_FACTOR := 1.35
## Standhöhe, aus der Würfelkante abgeleitet: alles andere hängt an ihr.
const HEIGHT := DieBuilder.HALF_EXTENT * 2.0 * DiceTrayView.DIE_SCALE * SIZE_FACTOR
## Streichholzschachtel-Verhältnis 2 : 3 : 0,28 (Breite : Höhe : Tiefe). Die Zelle
## ist als Einzelstück dünner, als sie sein müsste - gebaut wird sie für den
## STAPEL: fünf davon sollen als flacher Haufen lesen, nicht als Turm.
const UNIT := HEIGHT / 3.0
const WIDTH := UNIT * 2.0
const DEPTH := UNIT * 0.28

## Rahmenbreiten des Gehäuses. Der Fuß ist der breiteste Balken - er trägt die
## Kontaktfinnen und gibt der Zelle ihren Stand.
const SIDE_BAR := WIDTH * 0.14
const TOP_BAR := HEIGHT * 0.14
const FOOT_BAR := HEIGHT * 0.21
## Rückwand: der Ausschnitt ist ein Loch im Rahmen, sie schließt ihn nach hinten.
const BACK_DEPTH := DEPTH * 0.42

## Kontaktfinnen an der Unterkante. Sie stehen vorn UND hinten ein Stück vor -
## echte Steckkontakte sitzen nicht auf einer Seite.
const FIN_COUNT := 5
const FIN_WIDTH := WIDTH * 0.105
const FIN_SPREAD := WIDTH * 0.74
const FIN_DEPTH := DEPTH * 1.10

## Sichtbarer Stapel und sein Achsabstand; darüber zählt allein die Marke. Der
## Stapel wächst entlang der DICKE - liegend ist das der Chip-Turm nach oben,
## stehend die Reihe nach vorn. Der seitliche Versatz ist der Unterschied
## zwischen einem Stapel und einer Zelle: ohne ihn deckt die vorderste Kassette
## alle anderen exakt zu.
const STACK_CAP := 5
const STACK_PITCH := DEPTH * 1.18
const STACK_STAGGER := WIDTH * 0.055

## Ruhelicht des Kerns. Multipliziert mit der Sortenfarbe (hellster Kanal ~1)
## bleibt es unter Rune.IDLE_CEILING - dieselbe Ruheregel wie bei den Runen.
const REST_ENERGY := 0.88
## Der Ausbruch SOLL blühen: Lesen/Einschieben ist der Moment, für den der
## Kopfraum freigehalten wird.
const FLARE_ENERGY := 3.2
const FLARE_TIME := 0.55
## Gedimmt (später die Signatur-Sperre): der Kern verglimmt, der KÖRPER bleibt.
const DIM_ENERGY := 0.16

## Die KAPPE auf der Kopfkante: eine massive Platte in der Sortenfarbe, breiter
## als die Kassette dick ist. Sie ist die ganze Auskunft der stehenden Zelle -
## im Magazin blickt die Kamera von oben in die Grube und sieht NUR sie, also
## trägt sie Farbe, Sortenzeichen und (als Bündel) ihre Stückzahl. Ihre Oberkante
## liegt exakt auf HEIGHT/2: die Zelle bleibt genau so hoch, wie sie war, und die
## Einsink-Rechnung (sunk_drop) stimmt weiter.
const CAP_H := HEIGHT * 0.055
const CAP_WIDTH := WIDTH * 1.02
const CAP_DEPTH := DEPTH * 2.9
## Sie steht eine Spur ÜBER dem Gehäuse: läge ihre Deckfläche auf HEIGHT/2, wäre
## sie deckungsgleich mit den Kopfflächen von Rahmen und Kragen, und von oben
## zerschnitte deren Tiefenkampf die Kappe mit dunklen Nähten.
const CAP_PROUD := DEPTH * 0.16
## Ruhelicht der Kappe: satte Fläche, aber unter Rune.IDLE_CEILING.
const CAP_REST_ENERGY := 0.80
const CAP_DIM_ENERGY := 0.14
## Zeichen und Zahl liegen FLACH auf der Kappe - dunkel auf der Sortenfarbe.
const CAP_INK := Color(0.055, 0.05, 0.09)
const CAP_GLYPH_SHARE := 0.78
const CAP_BADGE_FONT := 64
const CAP_BADGE_HEIGHT := DEPTH * 1.9

## Der Leuchtstreifen unter der Kappe: ein Lichtsaum an ihrer Brüstung. Er bleibt
## in JEDER Richtung KLEINER als die Kappe - ragte er darunter hervor, läse die
## Kopfkante von oben als zweite, tiefer liegende Platte, und die Kassette sähe
## aus wie ein Doppeldecker.
const EDGE_STRIP_H := HEIGHT * 0.030
const EDGE_STRIP_WIDTH := WIDTH * 0.94
const EDGE_STRIP_DEPTH := CAP_DEPTH * 0.90
## Ruhelicht der Kante im Regal - wie der Kern unter Rune.IDLE_CEILING.
const EDGE_REST_ENERGY := 0.62
## Eingesteckt ist der Sliver die ganze Anzeige - hell, aber NICHT weiß: über
## etwa 1,5 kippen alle drei Kanäle ins Clipping und die Sortenfarbe geht verloren
## (dieselbe Grenze wie bei den Zellen der Kondensatorbank).
const EDGE_LIVE_ENERGY := 1.35
const EDGE_DIM_ENERGY := 0.12
## Anteil, mit dem die Kante einen Kern-Ausbruch mitreißt.
const EDGE_FLARE_SHARE := 0.75

## Die GRÖSSEN-Marke auf der Kappe (Pack.TIER_*): je Stufe ein heller Streifen
## rechts neben dem Sortenzeichen - Groß einer, Kolossal zwei. Sie liegen FLACH
## auf dem Deckel, denn von den Tischwinkeln sieht man von einer stehenden
## Kassette nichts als ihn. Geometrie der Kassette selbst bleibt unberührt: das
## eine Kassettenmaß trägt Schlitz und Grube, eine dickere Karte spränge beides.
const TIER_STRIPE_W := CAP_WIDTH * 0.045
const TIER_STRIPE_H := CAP_H * 0.55
const TIER_STRIPE_DEPTH := CAP_DEPTH * 0.66
## Abstand der Streifen zueinander und vom Zeichen weg (nach rechts, wo bis zur
## Bündelzahl frei ist).
const TIER_STRIPE_PITCH := CAP_WIDTH * 0.085
const TIER_STRIPE_X := -CAP_WIDTH * 0.06
## Sie stehen eine Spur über der Kappe - koplanar zerschnitte der Tiefenkampf sie.
const TIER_STRIPE_PROUD := DEPTH * 0.05
## Ihr Licht: heller als die Kappe, aber unter der Grenze, ab der die drei Kanäle
## zu Weiß zusammenlaufen und aus zwei Streifen einer wird.
const TIER_STRIPE_ENERGY := 1.45
## Das Kolossale trägt zusätzlich einen GOLDENEN Kragen - der Rahmen um die Karte,
## nicht die Blende davor: von oben ist er der Umriss, den man ohne Zoom liest.
const TIER_COLLAR_GOLD := 0.62

## Sichtbarer Anteil der Höhe, wenn die Zelle im Leseschlitz steckt: gerade so
## viel, dass Kopfkante und Blende lesen, und so wenig, dass sie IM Tisch steckt.
const SUNK_SHOW := 0.18
## Ganz geschluckt (Dekompression): eine Spur unter dem Glas, sonst flimmerte die
## Kopffläche gegen die Scheibe.
const SUNK_GONE := -0.06
## Der Stand im MAGAZIN: die Grube ist ein echtes Loch, die Zelle steht darin bis
## zur Kappe. Eine Spur UNTER der Tischkante - nichts ruht über dem Rand, und der
## Kragen der Grube deckt die Schnittkante darüber.
const PIT_SHOW := -0.03

## Das Herausziehen unterm Zeiger (wie eine Akte aus der Schublade): Anteil der
## Höhe, um den die Kassette steigt, und die Zeit dafür. Nur so ist ein Griff in
## der Grube überhaupt zu sehen - ein gemalter Schein läge unter dem Loch.
const HOVER_LIFT := 0.42
const HOVER_TIME := 0.16
## Aufgehellt, aber deutlich unter dem Lese-Ausbruch: Greifen ist kein Lesen.
const HOVER_ENERGY := 1.75

## Auftauchen und Abtreten wie ein schwebender Würfel (FloatingDie): der Körper
## wächst an Ort und Stelle aus dem Nichts und schrumpft wieder hinein. Skaliert
## wird der KNOTEN - der Ursprung liegt auf dem Glas, die Zelle sinkt also in die
## Fläche, statt in der Luft zu schrumpfen.
const MATERIALIZE_FROM := 0.12
const MATERIALIZE_TIME := 0.26
const DEMATERIALIZE_TIME := 0.16

## Gehäuse: dunkles Polymer mit Metallanteil. Bei reinem Schwarz bleibt von der
## Kassette auf dem Filz nur eine Silhouette übrig - der Anstrich muss hell genug
## sein, dass das Spill-Licht der Werkbank eine Kante zeichnet.
const SHELL_ALBEDO := Color(0.105, 0.10, 0.152)
const SHELL_EMISSION := Color(0.10, 0.11, 0.20)
const SHELL_EMISSION_ENERGY := 0.30
## Chassis: gebürstetes Hellmetall. Es zeichnet zweierlei - die Blende um das
## Fenster (aus einem Loch wird eine eingelassene Scheibe) und einen schmalen
## Kragen rings um den Körper. Der Kragen ist das, was die Kassette auf dunklem
## Filz vom Scherenschnitt unterscheidet: das Gehäuse darf schwarz bleiben, WEIL
## eine helle Kante seine Silhouette zeichnet. Bewusst farbneutral - die
## Sortenfarbe gehört dem Kern allein.
const BEZEL_LIP := WIDTH * 0.035
const BEZEL_RISE := DEPTH * 0.16
const CHASSIS_RIM := WIDTH * 0.022
const CHASSIS_ALBEDO := Color(0.34, 0.35, 0.42)
const CHASSIS_EMISSION := Color(0.52, 0.58, 0.78)
const CHASSIS_EMISSION_ENERGY := 0.30
## Scheibe: dunkles Rauchglas, damit der Kern DURCH sie leuchtet statt neben ihr.
## Bewusst fast neutral getönt: ein blaustichiges Glas zog den goldenen Kern der
## Runen ins Olive - die Scheibe soll dämpfen, nicht umfärben.
const GLASS_ALBEDO := Color(0.16, 0.16, 0.19, 0.24)
const GLASS_EMISSION_ENERGY := 0.09
## Kontaktgold - dieselbe Marken-Goldquelle wie die ×n-Marke im Regal.
const FIN_EMISSION_ENERGY := 0.30

## Anteil der Sortenfarbe im Albedo des Kerns: er ist ein Leuchtkörper, seine
## Farbe soll aus der Emission kommen, nicht aus dem Anstrich.
const CORE_ALBEDO_SHARE := 0.22
## Der Kern ist kein volles Feld, sondern DREI Riegel mit dunklen Fugen: eine
## Platte hinter Glas liest sich flach, ein Bänkchen hat Tiefe.
const CORE_BARS := 3
const CORE_WIDTH_SHARE := 0.80
const CORE_BAR_SHARE := 0.22
const CORE_BAR_PITCH := 0.29

## ×n-Marke über dem Stapel (Gold wie die Regal-Marke).
const BADGE_FONT := 64
const BADGE_HEIGHT := HEIGHT * 0.26
const BADGE_GAP := HEIGHT * 0.16

## Kantenlänge der gebackenen Siegel-Textur. Das Zeichen liegt auf einer Fläche,
## die kleiner ist als eine Netzkachel - mehr Pixel wären Vorrat für nichts.
const GLYPH_TEXTURE_SIZE := 128

var sort: String = Pack.SHELF_DICE_PACK
## Paketgröße (Pack.TIER_*): sie zeichnet die Streifen auf der Kappe.
var tier: int = Pack.TIER_NORMAL
var tint: Color = PackDrawerView.GOLD

## Alles Gebaute hängt unter _body: die Zelle steht mit ihrem URSPRUNG auf dem
## Glas, und _body trägt die Verschiebung, die aus Stehen Liegen macht.
var _body: Node3D
var _cells: Array[Node3D] = []
var _badge: Label3D
## Die Stückzahl auf der Kappe - die Marke der STEHENDEN Zelle. Die goldene
## Schwebemarke oben bleibt der liegenden Lage; aus der Grube ragte sie heraus.
var _cap_badge: Label3D
## LIEGEND ist die Grundlage: die Tischkameras blicken fast senkrecht nach unten,
## und stehend fällt die Kassette dort zu einem schwarzen Strich zusammen.
var _lying := true
## Mischwert der Lage (0 = liegend, 1 = stehend). Nur damit lässt sich das
## Aufrichten zeigen, statt es zu schalten; beide Enden sind exakt die Posen.
var _pose_blend := 0.0
## Sichtbarer Anteil der Höhe über dem Glas (1 = ganz oben, SUNK_SHOW = gesteckt).
var _show_share := 1.0
var _count := 1
var _dimmed := false
## Anzeige-Maßstab des KÖRPERS: eine Kassette in bloßer Würfelgröße läge in der
## Grube wie in ihrem Leser verloren. Magazin UND Schlitz stehen auf demselben
## Maß (PackDrawerView.CASSETTE_SCALE) - eine Karte behält ihre Größe ihr ganzes
## Leben lang. Der Ursprung bleibt dabei auf dem Glas, skaliert wird darunter.
var _body_scale := 1.0
## Steckt sie in einem Leseschlitz? Dann brennt die Kopfkante.
var _socketed := false
## Der Zeiger liegt auf ihr: sie steigt aus der Grube und leuchtet auf.
var _hovered := false
var _hover_share := 0.0
var _hover_tween: Tween
var _flare_tween: Tween
var _scale_tween: Tween
var _glide_tween: Tween
var _pose_tween: Tween
var _body_scale_tween: Tween

## Geteilte Materialien des ganzen Stapels: Dimmen und Flare treffen so jede
## Kopie zugleich, ohne dass ein Aufrufer sie einzeln kennt.
var _shell_material: StandardMaterial3D
var _bezel_material: StandardMaterial3D
var _glass_material: StandardMaterial3D
var _core_material: StandardMaterial3D
var _edge_material: StandardMaterial3D
var _fin_material: StandardMaterial3D
var _glyph_material: StandardMaterial3D
var _cap_material: StandardMaterial3D
## Dasselbe gebackene Zeichen, nur dunkel getönt: auf der hellen Kappe muss es
## Tinte sein, kein Leuchten. Eine zweite Backung wäre Vorrat für nichts.
var _cap_glyph_material: StandardMaterial3D
var _band_material: StandardMaterial3D
## Die hellen Größen-Streifen und der (beim Kolossalen goldene) Kragen.
var _tier_material: StandardMaterial3D
var _collar_material: StandardMaterial3D
var _glyph_oven: SubViewport

func _init() -> void:
	name = "DataCell"

## Einziger Eingang: baut die Zelle einer Sorte (Pack.SHELF_ORDER) in ihrer
## Paketgröße (Pack.TIER_*) - die Größe zeichnet nur die Kappe, nie den Körper.
func setup(cell_sort: String, cell_tier: int = 0) -> void:
	sort = cell_sort
	tier = maxi(cell_tier, 0)
	tint = PackDrawerView.COLORS.get(sort, PackDrawerView.GOLD)
	_build_materials()
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	_badge = _build_badge()
	_body.add_child(_badge)
	_cap_badge = _build_cap_badge()
	_body.add_child(_cap_badge)
	_apply_pose()
	set_count(_count)

## Der Sonderbestand ist versiegelt: Band quer über das Fenster, kein Kern.
func sealed() -> bool:
	return sort == Pack.SHELF_SPECIAL

## Wie viele Kassetten der Stapel zeigt; darüber zählt nur noch die Marke.
func set_count(n: int) -> void:
	_count = maxi(n, 0)
	if _body == null:
		return  # vor setup nur gemerkt - gebaut wird beim Aufbau
	var shown := mini(_count, STACK_CAP)
	while _cells.size() > shown:
		var spare: Node3D = _cells.pop_back()
		_body.remove_child(spare)
		spare.queue_free()
	while _cells.size() < shown:
		var cell := _build_cell()
		var step := float(_cells.size())
		cell.position = Vector3(step * STACK_STAGGER, 0.0, step * STACK_PITCH)
		_body.add_child(cell)
		_cells.append(cell)
	_place_badge()

func count() -> int:
	return _count

func stack_size() -> int:
	return _cells.size()

## Wie viele Kassetten wirklich zu sehen sind: STEHEND ist ein Bündel EINE Karte
## mit ihrer Zahl auf der Kappe - eine Reihe in die Tiefe läse sich in der Grube
## als Fächer aus Slivern, nicht als Stapel.
func shown_cells() -> int:
	var shown := 0
	for cell in _cells:
		if cell.visible:
			shown += 1
	return shown

func badge_text() -> String:
	return _badge.text if _badge != null else ""

func cap_badge_text() -> String:
	return _cap_badge.text if _cap_badge != null and _cap_badge.visible else ""

## Gedimmt heißt: der Kern verglimmt. Der Körper bleibt stehen - eine gesperrte
## Zelle ist da, sie ist nur nicht anfassbar.
func set_dimmed(on: bool) -> void:
	_dimmed = on
	_kill_flare()
	_set_glow(rest_energy())

func dimmed() -> bool:
	return _dimmed

## Der Zeiger liegt auf ihr: sie zieht sich ein Stück aus der Grube und leuchtet
## auf, wie eine Akte, die man aus der Schublade hebt. Idempotent - der Abgleich
## darf sie je Bild rufen; ein laufendes Gleiten stört sie nicht, der Hub sitzt im
## Körper, nicht im Platz.
func set_hovered(on: bool) -> void:
	if _hovered == on:
		return
	_hovered = on
	_kill_flare()
	_set_glow(rest_energy())
	_kill(_hover_tween)
	_hover_tween = create_tween()
	var lift := _hover_tween.tween_method(_set_hover_share, _hover_share,
		1.0 if on else 0.0, HOVER_TIME)
	lift.set_trans(Tween.TRANS_SINE)
	lift.set_ease(Tween.EASE_OUT)

func hovered() -> bool:
	return _hovered

func hover_share() -> float:
	return _hover_share

func _set_hover_share(value: float) -> void:
	_hover_share = clampf(value, 0.0, 1.0)
	_apply_pose()

## Der Lese-Moment: der Kern schießt über die Ruhegrenze und klingt zurück.
func flare() -> void:
	_kill_flare()
	_set_glow(FLARE_ENERGY)
	_flare_tween = create_tween()
	_flare_tween.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_flare_tween.tween_method(_set_glow, FLARE_ENERGY, rest_energy(), FLARE_TIME)

## Legt die Zelle flach aufs Glas (Grundlage) oder stellt sie hin. Stehend ist sie
## die Steck-Lage: auf dem Regal liegt sie.
func lay_flat(on: bool) -> void:
	_tween_pose(0.0 if on else 1.0, 0.0)

func lying() -> bool:
	return _lying

## Das Aufrichten vor dem Einstecken (Zeit 0 = hart). Der Ursprung bleibt dabei
## auf dem Glas - gekippt wird der Körper, nicht der Platz.
func raise_upright(time: float) -> void:
	_tween_pose(1.0, time)

## Und zurück in die Liegelage, wenn sie heimfährt.
func lay_over(time: float) -> void:
	_tween_pose(0.0, time)

## Das Einstecken: die Zelle fährt SENKRECHT in den Tisch, bis nur noch `show` der
## Höhe über dem Glas steht. Gemessen wird vom jetzigen Stand aus - die Tischfläche
## liegt nicht zwingend auf y = 0.
func plunge(show: float, time: float) -> void:
	var next := clampf(show, SUNK_GONE, 1.0)
	_kill(_glide_tween)
	var target := global_position
	target.y += drop_for(_show_share) - drop_for(next)
	_show_share = next
	_place_badge()
	if time <= 0.0:
		global_position = target
		return
	_glide_tween = create_tween()
	var dive := _glide_tween.tween_property(self, "global_position", target, time)
	dive.set_trans(Tween.TRANS_CUBIC)
	dive.set_ease(Tween.EASE_IN_OUT)

## Anzeige-Maßstab des Körpers (Zeit 0 = hart). Er verschiebt nichts an ihrem
## Platz: der Ursprung liegt auf dem Glas.
func set_body_scale(value: float, time := 0.0) -> void:
	var wanted := maxf(value, 0.01)
	_kill(_body_scale_tween)
	if time <= 0.0 or is_equal_approx(_body_scale, wanted):
		_apply_body_scale(wanted)
		return
	_body_scale_tween = create_tween()
	var grow := _body_scale_tween.tween_method(_apply_body_scale, _body_scale, wanted, time)
	grow.set_trans(Tween.TRANS_SINE)
	grow.set_ease(Tween.EASE_IN_OUT)

func body_scale() -> float:
	return _body_scale

## Der Anzeige-Maßstab verändert die STANDHÖHE, also auch, wie tief die Zelle
## unter ihrem Glaspunkt hängt: die Differenz wird sofort ausgeglichen, sonst
## stünde eine große Kassette aus der Grube heraus.
func _apply_body_scale(value: float) -> void:
	var before := drop_for(_show_share)
	_body_scale = value
	global_position.y += before - drop_for(_show_share)
	_apply_pose()
	_place_badge()

## Hart auf ihren Steckplatz (Glaspunkt): stehend, tief im Tisch, Kopfkante hell.
## Für den idempotenten Schreiber - die Richtigkeit hängt an keinem Tween. Der
## Leseschlitz ist auf das EINE Kassettenmaß geschnitten, also steht sie auch
## darin in genau diesem.
func seat_hard(at: Vector3) -> void:
	_kill(_glide_tween)
	_kill(_pose_tween)
	set_body_scale(PackDrawerView.CASSETTE_SCALE)
	_lying = false
	_show_share = SUNK_SHOW  # vor der Lage: sie entscheidet über die Marke
	_set_pose_blend(1.0)
	set_socketed(true)
	global_position = at - Vector3.UP * drop_for(SUNK_SHOW)

## Hart auf ihren MAGAZIN-Platz: stehend in der Grube, Kopfkante bündig unter der
## Tischkante, nicht gesteckt. Das Gegenstück zu seat_hard - der eine idempotente
## Schreiber des Fachs; der Anzeige-Maßstab bleibt, den setzt das Fach.
func stand_in_pit(glass_at: Vector3) -> void:
	_kill(_glide_tween)
	_kill(_pose_tween)
	_lying = false
	_show_share = PIT_SHOW  # vor der Lage: sie entscheidet über die Marke
	_set_pose_blend(1.0)
	set_socketed(false)
	global_position = glass_at - Vector3.UP * drop_for(PIT_SHOW)

## Wie tief die Zelle unter ihrem Glaspunkt hängt, wenn `show` von ihr übersteht.
## Statisch auf dem Grundmaß (Schlitz und Einschub stehen auf 1) ...
static func sunk_drop(show: float) -> float:
	return HEIGHT * (1.0 - show)

## ... und als Instanz MIT dem Anzeige-Maßstab: eine gewachsene Kassette hängt
## tiefer, sonst ragte ihre Kappe über den Grubenrand.
func drop_for(show: float) -> float:
	return HEIGHT * _body_scale * (1.0 - show)

## Ihr GLASPUNKT (der Platz, auf dem sie steht) - der Abgleich vergleicht damit,
## nicht mit der eingesunkenen Position.
func glass_position() -> Vector3:
	return global_position + Vector3.UP * drop_for(_show_share)

## Sichtbarer Höhenanteil (1 = ganz über dem Glas).
func show_share() -> float:
	return _show_share

func sunk() -> bool:
	return _show_share < 1.0

## Fährt gerade etwas an ihr? Der Schreiber lässt eine laufende Geste in Ruhe.
func busy() -> bool:
	return gliding() or (_pose_tween != null and _pose_tween.is_valid())

## Im Leseschlitz brennt die Kopfkante - sie ist dort die einzige Anzeige.
func set_socketed(on: bool) -> void:
	_socketed = on
	_sync_edge(glow_energy())

func socketed() -> bool:
	return _socketed

## Ruhelicht der Kopfkante in ihrem jetzigen Zustand.
func edge_rest_energy() -> float:
	if _dimmed:
		return EDGE_DIM_ENERGY
	return EDGE_LIVE_ENERGY if _socketed else EDGE_REST_ENERGY

func edge_energy() -> float:
	return _edge_material.emission_energy_multiplier if _edge_material != null else 0.0

func _tween_pose(target: float, time: float) -> void:
	_kill(_pose_tween)
	_lying = target < 0.5
	if time <= 0.0:
		_set_pose_blend(target)
		return
	_pose_tween = create_tween()
	var turn := _pose_tween.tween_method(_set_pose_blend, _pose_blend, target, time)
	turn.set_trans(Tween.TRANS_SINE)
	turn.set_ease(Tween.EASE_IN_OUT)

func _set_pose_blend(value: float) -> void:
	_pose_blend = clampf(value, 0.0, 1.0)
	_apply_pose()
	_place_badge()

## Aus dem Nichts an ihren Platz - dieselbe Geste wie beim schwebenden Würfel.
## delay: das Kleinwerden geschieht SOFORT, nur das Wachsen wartet, damit eine
## ganze Regal-Zeile gestaffelt aufgeht, ohne vorher in voller Größe dazustehen.
func materialize(delay: float = 0.0) -> void:
	_kill(_scale_tween)
	visible = true
	scale = Vector3.ONE * MATERIALIZE_FROM
	_scale_tween = create_tween()
	if delay > 0.0:
		_scale_tween.tween_interval(delay)
	var grow := _scale_tween.tween_property(self, "scale", Vector3.ONE, MATERIALIZE_TIME)
	grow.set_trans(Tween.TRANS_BACK)
	grow.set_ease(Tween.EASE_OUT)

## Abtreten, ohne freigegeben zu werden: derselbe Körper steht später wieder auf.
func dematerialize() -> void:
	if not visible:
		return
	_kill(_scale_tween)
	_scale_tween = create_tween()
	var shrink := _scale_tween.tween_property(self, "scale",
		Vector3.ONE * MATERIALIZE_FROM, DEMATERIALIZE_TIME)
	shrink.set_trans(Tween.TRANS_QUAD)
	shrink.set_ease(Tween.EASE_IN)
	_scale_tween.tween_callback(_hide_body)

## Die Zelle wandert an einen anderen Platz (Regal -> Schlitz und zurück). Das Ziel
## ist immer ein GLASPUNKT; wie tief sie darunter hängt, weiß sie selbst. Zeit 0
## setzt sie hart: die Richtigkeit hängt an keinem Tween.
func glide_to(glass_target: Vector3, time: float) -> void:
	_kill(_glide_tween)
	var target := glass_target - Vector3.UP * drop_for(_show_share)
	if time <= 0.0:
		global_position = target
		return
	_glide_tween = create_tween()
	var move := _glide_tween.tween_property(self, "global_position", target, time)
	move.set_trans(Tween.TRANS_SINE)
	move.set_ease(Tween.EASE_IN_OUT)

func gliding() -> bool:
	return _glide_tween != null and _glide_tween.is_valid()

## Ruhelicht dieser Zelle (gedimmt, überfahren oder normal) - Zielwert jedes
## Flare-Ausklangs.
func rest_energy() -> float:
	if _dimmed:
		return DIM_ENERGY
	return HOVER_ENERGY if _hovered else REST_ENERGY

## Ruhelicht der Kappe. Sie ist eine satte Fläche, kein Punkt: sie bleibt auch
## beim Greifen deutlich unter dem Kern, sonst frisst ihr Blühen ihr Zeichen.
func cap_rest_energy() -> float:
	if _dimmed:
		return CAP_DIM_ENERGY
	return CAP_REST_ENERGY * (1.45 if _hovered else 1.0)

## Der leuchtende Teil: Kern, beim Sonderbestand das Siegelband.
func glow_material() -> StandardMaterial3D:
	return _band_material if sealed() else _core_material

func glow_color() -> Color:
	var material := glow_material()
	return material.emission if material != null else Color.BLACK

func glow_energy() -> float:
	var material := glow_material()
	return material.emission_energy_multiplier if material != null else 0.0

func has_core() -> bool:
	return _core_material != null

func has_band() -> bool:
	return _band_material != null

# --- Aufbau ---------------------------------------------------------------------

## Höhe der Fenstermitte über der Gehäusemitte: der Fußbalken ist breiter als der
## Kopfbalken, also sitzt der Ausschnitt höher als die Mitte.
static func opening_center_y() -> float:
	return (FOOT_BAR - TOP_BAR) * 0.5

## Deckfläche der Kappe über der Gehäusemitte - die höchste Fläche der Kassette.
static func cap_top_y() -> float:
	return HEIGHT * 0.5 + CAP_PROUD

static func opening_size() -> Vector2:
	return Vector2(WIDTH - SIDE_BAR * 2.0, HEIGHT - TOP_BAR - FOOT_BAR)

func _apply_pose() -> void:
	if _body == null:
		return
	# Stehend hebt der Ursprung auf halbe Höhe, liegend auf halbe Tiefe: beides
	# setzt die Zelle auf das Glas, nicht hinein. Dazwischen wird schlicht
	# gemischt - die Enden bleiben exakt die beiden Posen.
	var angle := lerpf(-PI * 0.5, 0.0, _pose_blend)
	var lift := lerpf(DEPTH * 0.5, HEIGHT * 0.5, _pose_blend) * _body_scale
	# Der Griff hebt den KÖRPER, nicht den Platz: er überlebt jedes Gleiten und
	# jeden Neuaufbau des Fachs. Nur stehend - liegend gibt es nichts zu ziehen.
	lift += HEIGHT * HOVER_LIFT * _hover_share * _pose_blend * _body_scale
	_body.transform = Transform3D(
		Basis(Vector3.RIGHT, angle).scaled(Vector3.ONE * _body_scale),
		Vector3(0.0, lift, 0.0))

func _build_materials() -> void:
	_shell_material = StandardMaterial3D.new()
	_shell_material.albedo_color = SHELL_ALBEDO
	_shell_material.metallic = 0.55
	_shell_material.roughness = 0.34
	_shell_material.emission_enabled = true
	_shell_material.emission = SHELL_EMISSION
	_shell_material.emission_energy_multiplier = SHELL_EMISSION_ENERGY

	_bezel_material = StandardMaterial3D.new()
	_bezel_material.albedo_color = CHASSIS_ALBEDO
	_bezel_material.metallic = 0.45
	_bezel_material.roughness = 0.32
	_bezel_material.emission_enabled = true
	_bezel_material.emission = CHASSIS_EMISSION
	_bezel_material.emission_energy_multiplier = CHASSIS_EMISSION_ENERGY

	_glass_material = StandardMaterial3D.new()
	_glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass_material.albedo_color = GLASS_ALBEDO
	_glass_material.metallic = 0.15
	_glass_material.metallic_specular = 0.9
	_glass_material.roughness = 0.06
	_glass_material.emission_enabled = true
	_glass_material.emission = _scaled(tint, 1.0)
	_glass_material.emission_energy_multiplier = GLASS_EMISSION_ENERGY
	_glass_material.cull_mode = BaseMaterial3D.CULL_BACK

	_fin_material = StandardMaterial3D.new()
	_fin_material.albedo_color = _scaled(PackDrawerView.GOLD, 0.85)
	_fin_material.metallic = 1.0
	_fin_material.roughness = 0.24
	_fin_material.emission_enabled = true
	_fin_material.emission = _scaled(PackDrawerView.GOLD, 1.0)
	_fin_material.emission_energy_multiplier = FIN_EMISSION_ENERGY

	_glyph_material = StandardMaterial3D.new()
	_glyph_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glyph_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glyph_material.albedo_texture = _bake_glyph()
	# Vor der Scheibe gezeichnet: zwei alphagemischte Flächen sortiert der
	# Compatibility-Renderer sonst nach Laune.
	_glyph_material.render_priority = 2

	_cap_material = _lit_material(tint)
	_cap_material.albedo_color = _scaled(tint, 0.55)  # satte Fläche, nicht nur Licht
	_cap_material.emission_energy_multiplier = CAP_REST_ENERGY

	_cap_glyph_material = StandardMaterial3D.new()
	_cap_glyph_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cap_glyph_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cap_glyph_material.albedo_texture = _glyph_material.albedo_texture
	_cap_glyph_material.albedo_color = CAP_INK  # dieselbe Backung, dunkel getönt
	_cap_glyph_material.render_priority = 3

	_edge_material = _lit_material(tint)
	_edge_material.emission_energy_multiplier = EDGE_REST_ENERGY

	if tier > Pack.TIER_NORMAL:
		_tier_material = _lit_material(tint.lerp(Color.WHITE, 0.55))
		_tier_material.emission_energy_multiplier = TIER_STRIPE_ENERGY
	# Der Kragen ist beim Kolossalen golden getönt - EIGENES Material, sonst zöge
	# die Tönung die Blende vor der Scheibe mit.
	_collar_material = _bezel_material
	if tier >= Pack.TIER_KOLOSSAL:
		_collar_material = StandardMaterial3D.new()
		_collar_material.albedo_color = CHASSIS_ALBEDO.lerp(PackDrawerView.GOLD,
			TIER_COLLAR_GOLD)
		_collar_material.metallic = 0.85
		_collar_material.roughness = 0.28
		_collar_material.emission_enabled = true
		_collar_material.emission = _scaled(PackDrawerView.GOLD, 1.0)
		# Bewusst kaum heller als der normale Kragen: von oben sieht man von ihm nur
		# schmale Kanten, und die blühten bei starkem Licht zu diagonalen Schlieren
		# über die Nachbarzellen auf. Die Farbe trägt, nicht die Energie.
		_collar_material.emission_energy_multiplier = CHASSIS_EMISSION_ENERGY * 1.2

	if sealed():
		_band_material = _lit_material(tint)
	else:
		_core_material = _lit_material(tint)

func _lit_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = _scaled(color, CORE_ALBEDO_SHARE)
	material.metallic = 0.0
	material.roughness = 0.62
	material.emission_enabled = true
	material.emission = _scaled(color, 1.0)
	material.emission_energy_multiplier = REST_ENERGY
	return material

## Farbe mal Faktor OHNE ihr Alpha anzufassen - ein halbdurchsichtiger Anstrich
## auf einem deckenden Material ist eine stille Falle.
static func _scaled(color: Color, factor: float) -> Color:
	return Color(color.r * factor, color.g * factor, color.b * factor, 1.0)

## Eine Kassette des Stapels. Alle Kopien teilen Meshes und Materialien.
func _build_cell() -> Node3D:
	var cell := Node3D.new()
	cell.name = "Cell%d" % _cells.size()
	var opening := opening_size()
	var mid := opening_center_y()

	# Die Rückwand schließt nur den AUSSCHNITT und sitzt eine Spur vor der
	# Gehäuserückseite: über die volle Fläche lägen ihre Rückflächen deckungs-
	# gleich auf denen der Balken und flimmerten im Tiefenpuffer.
	_add_box(cell, "Back", Vector3(opening.x * 1.02, opening.y * 1.02, BACK_DEPTH),
		Vector3(0.0, mid, -(DEPTH - BACK_DEPTH) * 0.5 + DEPTH * 0.03), _shell_material)
	# Der Kragen ist ein RING um den Körper, kein Block: als Vollkörper schluckte
	# er den Kern, der in derselben Tiefe sitzt.
	var collar := DEPTH * 0.40
	var collar_x := (WIDTH + CHASSIS_RIM) * 0.5
	var collar_y := (HEIGHT + CHASSIS_RIM) * 0.5
	_add_box(cell, "CollarLeft", Vector3(CHASSIS_RIM, HEIGHT + CHASSIS_RIM * 2.0, collar),
		Vector3(-collar_x, 0.0, 0.0), _collar_material)
	_add_box(cell, "CollarRight", Vector3(CHASSIS_RIM, HEIGHT + CHASSIS_RIM * 2.0, collar),
		Vector3(collar_x, 0.0, 0.0), _collar_material)
	_add_box(cell, "CollarTop", Vector3(WIDTH, CHASSIS_RIM, collar),
		Vector3(0.0, collar_y, 0.0), _collar_material)
	_add_box(cell, "CollarFoot", Vector3(WIDTH, CHASSIS_RIM, collar),
		Vector3(0.0, -collar_y, 0.0), _collar_material)
	var side_x := (WIDTH - SIDE_BAR) * 0.5
	_add_box(cell, "BarLeft", Vector3(SIDE_BAR, HEIGHT, DEPTH),
		Vector3(-side_x, 0.0, 0.0), _shell_material)
	_add_box(cell, "BarRight", Vector3(SIDE_BAR, HEIGHT, DEPTH),
		Vector3(side_x, 0.0, 0.0), _shell_material)
	_add_box(cell, "BarTop", Vector3(opening.x, TOP_BAR, DEPTH),
		Vector3(0.0, (HEIGHT - TOP_BAR) * 0.5, 0.0), _shell_material)
	_add_box(cell, "BarFoot", Vector3(opening.x, FOOT_BAR, DEPTH),
		Vector3(0.0, -(HEIGHT - FOOT_BAR) * 0.5, 0.0), _shell_material)

	if _core_material != null:
		var bar := Vector3(opening.x * CORE_WIDTH_SHARE, opening.y * CORE_BAR_SHARE,
			DEPTH * 0.30)
		for i in CORE_BARS:
			var step := float(i) - float(CORE_BARS - 1) * 0.5
			_add_box(cell, "CoreBar%d" % i, bar,
				Vector3(0.0, mid + step * opening.y * CORE_BAR_PITCH, DEPTH * 0.02),
				_core_material)

	# Die Blende steht vor der Gehäusefläche, die Scheibe liegt in ihrem Ring.
	var lip_x := opening.x * 0.5 + BEZEL_LIP * 0.5
	var lip_y := opening.y * 0.5 + BEZEL_LIP * 0.5
	var lip_z := DEPTH * 0.5 + BEZEL_RISE * 0.5
	_add_box(cell, "BezelLeft", Vector3(BEZEL_LIP, opening.y + BEZEL_LIP * 2.0, BEZEL_RISE),
		Vector3(-lip_x, mid, lip_z), _bezel_material)
	_add_box(cell, "BezelRight", Vector3(BEZEL_LIP, opening.y + BEZEL_LIP * 2.0, BEZEL_RISE),
		Vector3(lip_x, mid, lip_z), _bezel_material)
	_add_box(cell, "BezelTop", Vector3(opening.x, BEZEL_LIP, BEZEL_RISE),
		Vector3(0.0, mid + lip_y, lip_z), _bezel_material)
	_add_box(cell, "BezelFoot", Vector3(opening.x, BEZEL_LIP, BEZEL_RISE),
		Vector3(0.0, mid - lip_y, lip_z), _bezel_material)

	var glass := MeshInstance3D.new()
	glass.name = "Glass"
	var pane := QuadMesh.new()
	pane.size = Vector2(opening.x * 1.02, opening.y * 1.02)
	glass.mesh = pane
	glass.material_override = _glass_material
	glass.position = Vector3(0.0, mid, DEPTH * 0.40)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cell.add_child(glass)

	var glyph := MeshInstance3D.new()
	glyph.name = "Glyph"
	var plate := QuadMesh.new()
	var glyph_side := minf(opening.x, opening.y) * (0.52 if sealed() else 0.68)
	plate.size = Vector2(glyph_side, glyph_side)
	glyph.mesh = plate
	glyph.material_override = _glyph_material
	# Beim versiegelten Stück rückt das Zeichen hoch: darunter liegt das Band.
	glyph.position = Vector3(0.0, mid + (opening.y * 0.16 if sealed() else 0.0),
		DEPTH * 0.5 + 0.004)
	glyph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cell.add_child(glyph)

	if _band_material != null:
		_add_box(cell, "Seal", Vector3(WIDTH * 1.04, HEIGHT * 0.16, DEPTH * 1.12),
			Vector3(0.0, mid - opening.y * 0.24, 0.0), _band_material)

	# Die KAPPE: massive Sortenfarbe auf der Kopfkante, ihre Oberfläche exakt auf
	# HEIGHT/2 - so bleibt die Standhöhe die alte und die Einsink-Rechnung stimmt.
	var cap_top := cap_top_y()
	_add_box(cell, "Cap", Vector3(CAP_WIDTH, CAP_H, CAP_DEPTH),
		Vector3(0.0, cap_top - CAP_H * 0.5, 0.0), _cap_material)
	# Das Sortenzeichen liegt FLACH auf der Kappe, links; rechts bleibt Platz für
	# die Bündelzahl. -90° um X dreht die Quad-Fläche nach oben, ihr Oben zeigt
	# dann nach lokal -Z = Bildschirm-oben (die Zelle steht um -90° um Y gedreht).
	var cap_side := CAP_DEPTH * CAP_GLYPH_SHARE
	var cap_glyph := MeshInstance3D.new()
	cap_glyph.name = "CapGlyph"
	var cap_plate := QuadMesh.new()
	cap_plate.size = Vector2(cap_side, cap_side)
	cap_glyph.mesh = cap_plate
	cap_glyph.material_override = _cap_glyph_material
	cap_glyph.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	cap_glyph.position = Vector3(-(CAP_WIDTH * 0.5 - cap_side * 0.62),
		cap_top + 0.002, 0.0)
	cap_glyph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cell.add_child(cap_glyph)

	# Die GRÖSSEN-Streifen: rechts neben dem Zeichen, einer je Stufe über Standard.
	if _tier_material != null:
		for i in mini(tier, Pack.TIER_KOLOSSAL):
			_add_box(cell, "TierStripe%d" % i,
				Vector3(TIER_STRIPE_W, TIER_STRIPE_H, TIER_STRIPE_DEPTH),
				Vector3(TIER_STRIPE_X + float(i) * TIER_STRIPE_PITCH,
					cap_top + TIER_STRIPE_PROUD - TIER_STRIPE_H * 0.5, 0.0),
				_tier_material)

	# Der Lichtsaum unter der Kappe - steckt die Zelle, steht mit ihr nur er über
	# dem Glas; er ragt eine Spur weiter und zeichnet ihre Brüstung nach.
	_add_box(cell, "EdgeStrip",
		Vector3(EDGE_STRIP_WIDTH, EDGE_STRIP_H, EDGE_STRIP_DEPTH),
		Vector3(0.0, cap_top - CAP_H - EDGE_STRIP_H * 0.5, 0.0),
		_edge_material)

	var fin_y := -(HEIGHT * 0.5) + FOOT_BAR * 0.34
	for i in FIN_COUNT:
		var t := 0.0 if FIN_COUNT < 2 else float(i) / float(FIN_COUNT - 1) - 0.5
		_add_box(cell, "Fin%d" % i, Vector3(FIN_WIDTH, FOOT_BAR * 0.44, FIN_DEPTH),
			Vector3(t * FIN_SPREAD, fin_y, 0.0), _fin_material)

	return cell

func _add_box(host: Node3D, box_name: String, box_size: Vector3, at: Vector3,
		material: StandardMaterial3D) -> void:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var instance := MeshInstance3D.new()
	instance.name = box_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	host.add_child(instance)

func _build_badge() -> Label3D:
	var badge := Label3D.new()
	badge.name = "CountBadge"
	badge.font_size = BADGE_FONT
	badge.pixel_size = BADGE_HEIGHT / float(BADGE_FONT)
	badge.modulate = PackDrawerView.GOLD
	badge.outline_size = 10
	badge.outline_modulate = CasinoStyle.INK
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.text = ""
	return badge

## Die Bündelzahl auf der Kappe: flach liegend, dunkel auf der Sortenfarbe, am
## rechten Ende - links steht das Sortenzeichen.
func _build_cap_badge() -> Label3D:
	var badge := Label3D.new()
	badge.name = "CapBadge"
	badge.font_size = CAP_BADGE_FONT
	badge.pixel_size = CAP_BADGE_HEIGHT / float(CAP_BADGE_FONT)
	badge.modulate = CAP_INK
	badge.outline_size = 0
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	badge.position = Vector3(CAP_WIDTH * 0.28, cap_top_y() + 0.004, 0.0)
	badge.text = ""
	badge.visible = false
	return badge

## Die Marke sitzt über der OBERSTEN Kassette und in DEREN Ebene: einen halben
## Stapel weiter vorn gesetzt läuft ihr die Perspektive davon und legt sie mitten
## auf die Kassette statt darüber.
func _place_badge() -> void:
	if _badge == null:
		return
	_sync_stack()
	var standing := _pose_blend >= 0.5
	if _cap_badge != null:
		# STEHEND liegt die Zahl flach auf der Kappe: aus der Grube ragte eine
		# schwebende Marke heraus, und ein Bündel steht dort als EINE Karte.
		_cap_badge.text = "×%d" % _count if _count > 1 else ""
		_cap_badge.visible = _count > 1 and standing
	_badge.text = "×%d" % _count if _count > 1 else ""
	# Eine steckende Zelle zeigt keine Schwebemarke: sie ist einzeln, und die Zahl
	# stünde als einziges Stück Schrift aus dem Tisch heraus.
	_badge.visible = _count > 1 and not standing and not sunk()
	var top := maxf(float(_cells.size()) - 1.0, 0.0)
	if _pose_blend < 0.5:
		# Liegend ist der Stapel ein Turm - die Marke sitzt auf seiner Spitze.
		_badge.position = Vector3(top * STACK_STAGGER, HEIGHT * 0.5 + BADGE_GAP,
			top * STACK_PITCH + DEPTH)
		return
	# Stehend wächst der Stapel in die TIEFE, und von schräg oben projizieren
	# seine hinteren Deckel höher als seine vorderen. Die Marke muss deshalb um
	# die ganze Stapeltiefe steigen, sonst legt sie sich auf den Deckel.
	_badge.position = Vector3(top * STACK_STAGGER * 0.5,
		HEIGHT * 0.5 + BADGE_GAP + top * STACK_PITCH, top * STACK_PITCH * 0.5)

## Stehend ist ein Bündel EINE Karte (die Zahl steht auf ihrer Kappe); liegend
## liegt der Stapel als flacher Haufen da. Eine Reihe stehender Sliver läse sich
## in der Grube als Fächer, nicht als Stück.
func _sync_stack() -> void:
	var standing := _pose_blend >= 0.5
	for i in _cells.size():
		_cells[i].visible = not standing or i == 0

## Backt das Siegelzeichen der Sorte EINMAL in eine Textur - dieselbe Zeichnung
## wie im Regal (PackIconRenderer), nie ein zweites Zeichen.
func _bake_glyph() -> Texture2D:
	_glyph_oven = SubViewport.new()
	_glyph_oven.name = "GlyphOven"
	_glyph_oven.size = Vector2i(GLYPH_TEXTURE_SIZE, GLYPH_TEXTURE_SIZE)
	_glyph_oven.transparent_bg = true
	_glyph_oven.render_target_update_mode = SubViewport.UPDATE_ONCE
	var icon := PackIconRenderer.for_type(Pack.pack_type_of_shelf(sort))
	icon.size = Vector2(GLYPH_TEXTURE_SIZE, GLYPH_TEXTURE_SIZE)
	_glyph_oven.add_child(icon)
	add_child(_glyph_oven)
	return _glyph_oven.get_texture()

func _set_glow(energy: float) -> void:
	var material := glow_material()
	if material != null:
		material.emission_energy_multiplier = energy
	_sync_edge(energy)
	_sync_cap(energy)

## Die Kappe steht wie die Kopfkante auf ihrem EIGENEN Zustand und reißt beim
## Lesen nur mit.
func _sync_cap(core_energy: float) -> void:
	if _cap_material == null:
		return
	var over := maxf(core_energy - rest_energy(), 0.0)
	_cap_material.emission_energy_multiplier = (cap_rest_energy()
		+ over * EDGE_FLARE_SHARE)

## Die Kopfkante steht auf ihrem eigenen Zustand und reißt bei einem Kern-Ausbruch
## nur mit - anders bliebe der gesteckte Sliver beim Lesen stumm.
func _sync_edge(core_energy: float) -> void:
	if _edge_material == null:
		return
	var over := maxf(core_energy - rest_energy(), 0.0)
	_edge_material.emission_energy_multiplier = (edge_rest_energy()
		+ over * EDGE_FLARE_SHARE)

func _hide_body() -> void:
	visible = false

func _kill_flare() -> void:
	_kill(_flare_tween)

func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
