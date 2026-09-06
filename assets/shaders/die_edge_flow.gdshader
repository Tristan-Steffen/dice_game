shader_type spatial;
render_mode cull_back;

// Der Kantenrahmen als Röhrensystem: alle 12 Balken liegen in EINEM Mesh, und
// in den Röhren zirkuliert das flüssige Licht der Seele. Je Rarität eine andere
// Erregung DERSELBEN Flüssigkeit: 1 = Strömung (selten, träges Ziehen),
// 2 = Schübe (episch, Ballungen schwellen und teilen sich), 3 = Sieden
// (legendär, das Licht kocht - die Seelenfunken sind seine Tropfen, sie treten
// schon jetzt aus den Kanten aus). 0 = still, exakt das alte Bild.
//
// Welcher Balken und wohin der Fluss steckt in der GEOMETRIE: je Fragment sind
// zwei Achsen am Anschlag (welche Kante), die dritte läuft. Riegel folgen der
// Zirkulation um die Hochachse, Pfosten steigen. An den Pfosten-Enden ist die
// Zuordnung mehrdeutig, aber dort sitzen die Eck-Kappen davor - Fluss gibt es
// nur ab SELTEN, und jede Seele zeigt Kappen.
//
// BESCHATTET wie der alte Rahmen (dunkles Albedo × Muster, Emission × Muster);
// animiert wird allein die EMISSION. Der Lauf ankert um 1.0: die Ballung ist
// heller, die Flüssigkeit dazwischen dunkler, der MITTELWERT bleibt stehen -
// und mit ihm die Rangfolge kahl < Material < Essenz. Bewegung braucht
// Dunkelheit, die ihr gehört: ein WANDERNDES Tal liest sich als Fluss, das
// statische Loch der alten Eck-Lampen las sich als Defekt.

uniform sampler2D surface_tex : source_color, hint_default_white;
// Röhren-Grundton = die Rahmen-Emission (Seelenfarbe bzw. neutrales Neon).
uniform vec3 lamp_color = vec3(0.8, 0.8, 0.83);
// Farbe der Ballungen: meist die Seelenfarbe, für Fast-Schwarz (Vakuum) der
// Void-Boden - sonst flösse dort unsichtbares Licht.
uniform vec3 flow_color = vec3(0.0);
uniform vec3 body_color = vec3(0.05, 0.05, 0.08);
uniform float metallic_amount = 0.35;
uniform float roughness_amount = 0.25;
uniform float flow_style = 0.0;
// Je Würfel eigene Phase - 30 Tray-Würfel fließen nie im Gleichschritt.
uniform float phase = 0.0;
// Atem des Neons: Material-Würfel atmen stärker (DieFaceDisplay.PULSE_AMOUNT*).
uniform float breath_amount = 0.08;
// Auswahl-Farbe der Gravur-Station (a > 0 = aktiv): flach und exakt, der
// Nachfolger von set_edge_tint auf dem alten StandardMaterial.
uniform vec4 flat_tint = vec4(0.0);
// Die LADUNG des Würfels (0-3). Ein EIGENER Kanal neben flow_style, denn der
// gehört der Seelen-Rarität: ab 2 entladen sich Funken längs der Kanten, ab 3
// glüht ihr Kern orange. Die Kanten-FARBE bleibt dabei unberührt (Spieler-Wunsch
// 2026-09-06); Stufe 1 zeichnet hier gar nichts, sie ist die Hitze davor.
uniform float charge_level = 0.0;
uniform vec3 charge_color = vec3(0.86, 0.66, 1.35);
uniform vec3 charge_core = vec3(1.45, 0.72, 0.30);
// Fassung der Entladungen (Autoren-Schalter, Spieler-Wahl offen).
uniform float arc_style = 0.0;

const float BREATH_SPEED = 1.4;

// Wellenzahl (Ballungen je Kantenlänge) und die drei Erregungs-Tempi.
const float FLOW_SCALE = 2.6;
const float DRIFT_SPEED = 1.1;
const float SURGE_SPEED = 1.9;
const float BOIL_SPEED = 4.2;
// Senke/Spitze um den Anker 1.0; die Spitze trägt zusätzlich flow_color.
const float FLOW_DIP = 0.3;
const float FLOW_LIFT = 0.5;

// KRIECHSTROM: kleine ELEKTRISCHE ENTLADUNGEN längs der Kanten - zufällig in
// Ort und Zeit, nie ein umlaufender Takt (der las als Karussell). Die Kante
// selbst wird davon NICHT eingefärbt; die Entladung legt sich nur darauf.
// arc_style: 0 Zuckungen, 1 Kriechfunken, 2 Lichtbögen, 3 Prasseln, 4 Gewitter.
const float ARC_GAIN = 1.15;
const float ZUCK_CELLS = 6.0;
const float ZUCK_RATE = 3.6;
const float ZUCK_DENSITY = 0.34;
const float KRIECH_WIDTH = 0.045;
const float BOGEN_RATE = 2.0;
const float BOGEN_DENSITY = 0.5;
const float PRASSEL_CELLS = 15.0;
const float PRASSEL_RATE = 8.0;
const float PRASSEL_DENSITY = 0.15;
const float GEWITTER_RATE = 0.85;
const float GEWITTER_DENSITY = 0.34;

float hash11(float x) {
	return fract(sin(x * 12.9898 + 4.1414) * 43758.5453);
}

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Die Entladung an dieser Stelle (0..1). s = 0..1 längs des Balkens, seed
// unterscheidet die zwölf Kanten, damit sie nie im Gleichschritt zünden.
float discharge(float s, float t, float seed, float style) {
	if (style < 0.5) {
		// ZUCKUNGEN: kurze Segmente springen an zufälligen Stellen an und aus.
		float u = s * ZUCK_CELLS;
		float cell = floor(u) + seed;
		float k = t * ZUCK_RATE + hash11(cell) * 9.0;
		float on = step(1.0 - ZUCK_DENSITY, hash21(vec2(cell, floor(k))));
		float env = pow(max(1.0 - fract(k) * 2.6, 0.0), 2.0);
		return on * env * smoothstep(0.5, 0.12, abs(fract(u) - 0.5));
	}
	if (style < 1.5) {
		// KRIECHFUNKEN: drei Köpfe kriechen mit zufälligem Tempo und Richtung.
		float sum = 0.0;
		for (int i = 0; i < 3; i++) {
			float id = seed + float(i) * 3.7;
			float speed = mix(0.5, 1.8, hash11(id + 7.1));
			float way = hash11(id + 11.3) < 0.5 ? -1.0 : 1.0;
			float gap = abs(s - fract(hash11(id) + t * speed * way));
			gap = min(gap, 1.0 - gap);
			float flick = 0.6 + 0.4 * hash11(floor(t * 18.0) + id);
			sum += exp(-pow(gap / KRIECH_WIDTH, 2.0)) * flick;
		}
		return min(sum, 1.0);
	}
	if (style < 2.5) {
		// LICHTBÖGEN: ein zufälliger Abschnitt der Kante steht kurz unter Strom.
		float k = t * BOGEN_RATE + hash11(seed) * 5.0;
		float slot = floor(k);
		float span = mix(0.1, 0.32, hash21(vec2(seed + 3.0, slot)));
		float on = step(1.0 - BOGEN_DENSITY, hash21(vec2(seed + 9.0, slot)));
		float body = smoothstep(span, span * 0.25, abs(s - hash21(vec2(seed, slot))));
		float flick = 0.35 + 0.65 * hash11(floor(t * 30.0) + slot + seed);
		return on * body * flick * pow(max(1.0 - fract(k) * 1.6, 0.0), 1.5);
	}
	if (style < 3.5) {
		// PRASSELN: viele winzige, sehr kurze Punkte - statisches Knistern.
		float u = s * PRASSEL_CELLS;
		float cell = floor(u) + seed;
		float k = t * PRASSEL_RATE + hash11(cell) * 13.0;
		float on = step(1.0 - PRASSEL_DENSITY, hash21(vec2(cell, floor(k))));
		return on * pow(max(1.0 - fract(k) * 4.0, 0.0), 3.0)
			* smoothstep(0.5, 0.25, abs(fract(u) - 0.5));
	}
	// GEWITTER: selten, dafür schlägt die GANZE Kante auf einmal durch.
	float k = t * GEWITTER_RATE + hash11(seed) * 3.0;
	float slot = floor(k);
	float on = step(1.0 - GEWITTER_DENSITY, hash21(vec2(seed + 21.0, slot)));
	float flick = step(0.35, hash11(floor(t * 45.0) + slot));
	return on * flick * pow(max(1.0 - fract(k) * 2.2, 0.0), 1.2)
		* (0.7 + 0.3 * sin(s * 30.0 + slot));
}

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

// Ballungs-Anteil an diesem Punkt (0..1), je Erregung anders geformt.
float liquid(float u, float style, float t) {
	if (style > 2.5) {
		// Sieden: drei inkommensurable Wellen - es kocht, statt zu wandern.
		// Wellenzahlen bewusst niedrig: höhere machten aus den Blasen feine
		// Streifen, ein Barcode statt einer kochenden Röhre.
		float s = sin(u * 1.2 - t * BOIL_SPEED) * sin(u * 2.1 + t * 2.9)
			+ 0.5 * sin(u * 3.1 - t * 5.1);
		return clamp(0.5 + 0.45 * s, 0.0, 1.0);
	}
	if (style > 1.5) {
		// Schübe: zwei Tempi ergeben Schwebung - Ballungen schwellen, verschmelzen
		// und teilen sich wieder.
		float s = sin(u - t * SURGE_SPEED) + sin(u * 1.8 - t * SURGE_SPEED * 1.65);
		return clamp(0.5 + 0.4 * s, 0.0, 1.0);
	}
	// Strömung: EINE träge Welle zieht gleichmäßig durch.
	return 0.5 + 0.5 * sin(u - t * DRIFT_SPEED);
}

void fragment() {
	if (flat_tint.a > 0.0) {
		// Flache Auswahl-Farbe: schwarzes Albedo + Emission liefert exakt den
		// Wert, unabhängig vom Szenenlicht - kein Fluss über der Auswahl.
		ALBEDO = vec3(0.0);
		METALLIC = 0.0;
		ROUGHNESS = 1.0;
		EMISSION = flat_tint.rgb;
	} else {
		vec3 pattern = texture(surface_tex, UV).rgb;
		ALBEDO = body_color * pattern;
		METALLIC = metallic_amount;
		ROUGHNESS = roughness_amount;
		float breath = 1.0 + sin(TIME * BREATH_SPEED + phase) * breath_amount;
		vec3 glow = lamp_color;
		// Welcher Balken und wohin: dieselbe Laufrichtung tragen Seelen-Fluss und
		// Ladungs-Funken - EINE Ableitung aus der Geometrie.
		float run = 0.0;
		// ...und WELCHE der zwölf Kanten: aus den beiden festgenagelten Achsen,
		// damit jede ihren eigenen Zufall hat.
		float seed = 0.0;
		if (flow_style > 0.5 || charge_level > 1.5) {
			vec3 a = abs(local_pos);
			if (a.x < a.y && a.x < a.z) {
				run = local_pos.x * sign(local_pos.z);   // Riegel längs X: Zirkulation
				seed = sign(local_pos.y) * 2.0 + sign(local_pos.z) * 5.0;
			} else if (a.z < a.y) {
				run = -local_pos.z * sign(local_pos.x);  // Riegel längs Z: Zirkulation
				seed = sign(local_pos.x) * 2.0 + sign(local_pos.y) * 5.0 + 30.0;
			} else {
				run = local_pos.y;                       // Pfosten: aufwärts
				seed = sign(local_pos.x) * 2.0 + sign(local_pos.z) * 5.0 + 60.0;
			}
		}
		if (flow_style > 0.5) {
			float blob = liquid(run * FLOW_SCALE, flow_style, TIME + phase);
			glow = lamp_color * (1.0 - FLOW_DIP * (1.0 - blob)) + flow_color * blob * FLOW_LIFT;
		}
		EMISSION = glow * pattern * breath;
		if (charge_level > 1.5) {
			float arc = discharge(clamp(run * 0.5 + 0.5, 0.0, 1.0), TIME,
				seed + phase * 3.0, arc_style);
			vec3 tint = charge_level > 2.5 ? mix(charge_color, charge_core, 0.62) : charge_color;
			EMISSION += tint * arc * ARC_GAIN;
		}
	}
}
