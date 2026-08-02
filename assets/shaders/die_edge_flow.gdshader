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

const float BREATH_SPEED = 1.4;

// Wellenzahl (Ballungen je Kantenlänge) und die drei Erregungs-Tempi.
const float FLOW_SCALE = 2.6;
const float DRIFT_SPEED = 1.1;
const float SURGE_SPEED = 1.9;
const float BOIL_SPEED = 4.2;
// Senke/Spitze um den Anker 1.0; die Spitze trägt zusätzlich flow_color.
const float FLOW_DIP = 0.3;
const float FLOW_LIFT = 0.5;

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
		if (flow_style > 0.5) {
			vec3 a = abs(local_pos);
			float run;
			if (a.x < a.y && a.x < a.z) {
				run = local_pos.x * sign(local_pos.z);   // Riegel längs X: Zirkulation
			} else if (a.z < a.y) {
				run = -local_pos.z * sign(local_pos.x);  // Riegel längs Z: Zirkulation
			} else {
				run = local_pos.y;                       // Pfosten: aufwärts
			}
			float blob = liquid(run * FLOW_SCALE, flow_style, TIME + phase);
			glow = lamp_color * (1.0 - FLOW_DIP * (1.0 - blob)) + flow_color * blob * FLOW_LIFT;
		}
		EMISSION = glow * pattern * breath;
	}
}
