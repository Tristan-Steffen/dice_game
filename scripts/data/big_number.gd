class_name BigNumber
extends RefCounted
## Große Zahlen kurz und deutsch: bis 99.999 ausgeschrieben, dann Tsd/Mio/Mrd/Bio, danach
## Zehnerpotenz. Der EINE Helfer für Laufwerte und Etagen-Karte.

## Ab hier wird gekürzt; darunter steht die Zahl ganz.
const SHORT_FROM := 100000.0
## Einheiten von klein nach groß: [Schwelle, Wort].
const UNITS := [[1.0e3, "Tsd"], [1.0e6, "Mio"], [1.0e9, "Mrd"], [1.0e12, "Bio"]]

static func short(value: float) -> String:
	if is_nan(value) or is_inf(value):
		return "–"
	var minus := "-" if value < 0.0 else ""
	var v := absf(value)
	if roundf(v) < SHORT_FROM:
		return minus +grouped(roundi(v))
	for i in range(UNITS.size() - 1, -1, -1):
		var unit: float = UNITS[i][0]
		if v < unit:
			continue
		var mantissa := v / unit
		var digits := 0 if mantissa >= 100.0 else 1
		# Was auf 1000 aufrundet, gehört in die nächste Einheit (bzw. in die Zehnerpotenz).
		if snappedf(mantissa, pow(10.0, -digits)) >= 1000.0:
			if i == UNITS.size() - 1:
				break
			return minus +decimal(v / float(UNITS[i + 1][0]), 1) + " " + String(UNITS[i + 1][1])
		return minus +decimal(mantissa, digits) + " " + String(UNITS[i][1])
	return minus +_power(v)

## Faktor „×3,6“: eine Nachkommastelle (ab 100 keine, ab 100.000 gekürzt).
static func factor(value: float, digits: int = 1) -> String:
	var v := absf(value)
	if roundf(v) >= SHORT_FROM:
		return "×" + short(value)
	if snappedf(v, pow(10.0, -digits)) >= 100.0:
		return "×" + grouped(roundi(value))
	return "×" + decimal(value, digits)

## Ganze Zahl mit Tausenderpunkt („12.345“).
static func grouped(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = "." + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out

## Dezimalzahl mit Komma; nachlaufende Nullen (und das Komma) entfallen.
static func decimal(value: float, digits: int) -> String:
	if digits <= 0:
		return grouped(roundi(value))
	var scale := pow(10.0, digits)
	var scaled := roundf(absf(value) * scale)
	var whole := floori(scaled / scale)
	var frac := str(roundi(scaled - float(whole) * scale)).pad_zeros(digits).rstrip("0")
	var minus := "-" if value < 0.0 and scaled > 0.0 else ""
	return minus +grouped(whole) + ("," + frac if frac != "" else "")

## „1,2e15“: eine Ziffer vor dem Komma, eine dahinter.
static func _power(v: float) -> String:
	var power := floori(log(v) / log(10.0) + 0.000001)
	var lead := v / pow(10.0, power)
	if snappedf(lead, 0.1) >= 10.0:
		power += 1
		lead = v / pow(10.0, power)
	return decimal(lead, 1) + "e" + str(power)
