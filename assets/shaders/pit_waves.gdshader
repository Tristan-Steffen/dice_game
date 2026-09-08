// Rundenpuls der Grube: solange eine Runde läuft, treiben breite, weiche
// Lichtwellen vom Grubenrand einwärts und verklingen lange vor der Mitte -
// die Spielzone mit den Würfeln bleibt dunkel. Kopplung je Welle: breit =
// langsam + blass, schmal = schnell + hell (ein Größenwurf f steuert alles).
// scene_root schaltet über TableScreen.set_round_pulse (intensity 0..1).
shader_type canvas_item;
render_mode blend_add;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec2 rect_size = vec2(800.0, 400.0);
uniform float corner_radius = 40.0;
uniform float reach : hint_range(0.05, 1.0) = 0.3; // Wanderweg als Anteil der halben Fensterhöhe
uniform float gain : hint_range(0.0, 2.0) = 0.5;   // Gesamthelligkeit

// Punkt-Pulse: je Würfel-Gewinn eine schnelle Stoßwelle vom Würfel aus, in der
// Farbe der Punktart (Basis/Mult/Krit) - hell bei Geburt, verklingt beim
// Auslaufen. progress außerhalb (0,1) = Bahn frei (TableScreen.pit_impulse).
const int IMPULSES = 6;
uniform vec2 impulse_pos[IMPULSES];      // lokale Pixel im Overlay
uniform vec4 impulse_color[IMPULSES];
uniform float impulse_progress[IMPULSES];
uniform float impulse_radius = 420.0;    // Endradius in px (setzt place_pit_window)
uniform float impulse_width = 60.0;      // Ringdicke (Gauß-Sigma, px)
uniform float impulse_gain : hint_range(0.0, 4.0) = 1.5;

// HITZEFLIMMERN: EIN Schleier steigt von der Bild-Unterkante zur Oberkante
// (Ladungsstufe 2). progress außerhalb (0,1) = keine Bahn (pit_heat_wave).
uniform float heat_progress = 0.0;
uniform vec4 heat_color = vec4(1.0, 0.35, 0.12, 1.0);
uniform float heat_gain : hint_range(0.0, 4.0) = 0.0; // TableScreen.PIT_HEAT_GAIN setzt ihn
uniform float heat_width : hint_range(0.02, 1.0) = 0.12; // Bandbreite als Anteil der Höhe

const int WAVES = 8;
// Kalte Neon-Familie des Tischs; Violett bleibt der seltene Ausreißer.
const vec3 COL_A = vec3(0.15, 0.85, 1.00);
const vec3 COL_B = vec3(0.31, 0.73, 1.00);
const vec3 COL_C = vec3(0.18, 0.94, 0.84);
const vec3 COL_D = vec3(0.47, 0.59, 1.00);

float hash1(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

void fragment() {
	// Rounded-Rect-SDF: depth = Pixelweg vom Rand ins Innere (außen negativ).
	vec2 p = UV * rect_size - rect_size * 0.5;
	vec2 q = abs(p) - (rect_size * 0.5 - vec2(corner_radius));
	float sd = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner_radius;
	float depth = -sd;
	// Wander-Koordinate: 0 = Rand, 1 = Ende des Wanderwegs (Halbweg-Horizont).
	float u = depth / max(1.0, reach * rect_size.y * 0.5);

	vec3 acc = vec3(0.0);
	for (int i = 0; i < WAVES; i++) {
		float fi = float(i);
		// Stratifizierter Größenwurf: jede Bahn hat ihren festen Charakter,
		// zusammen decken sie das ganze Spektrum schmal-flink bis breit-träge ab.
		float strat = (fi + hash1(fi + 0.13)) / float(WAVES);
		float f = 0.45 + pow(strat, 0.65) * 2.6;
		float dur = 3.2 + f * 3.9;             // breit = langsam
		float off = hash1(fi + 7.7) * dur;
		float t = fract((TIME + off) / dur);
		float cyc = floor((TIME + off) / dur); // je Wiedergeburt neue Farbe/Helligkeit
		float amp = min(1.9, 1.35 / f) * (0.85 + 0.3 * hash1(fi * 3.1 + cyc * 17.7));
		float env = min(1.0, t * 3.0) * pow(1.0 - t, 1.5) * amp;
		float sigma = 0.1 * f + 0.02;          // breit = diffus
		float x = (u - t) / sigma;
		float w = env * exp(-0.5 * x * x);
		float pick = hash1(fi * 5.3 + cyc * 11.3);
		vec3 tint = pick < 0.25 ? COL_A : (pick < 0.5 ? COL_B : (pick < 0.75 ? COL_C : COL_D));
		acc += tint * w;
	}
	// Punkt-Pulse: enger heller Ring, läuft schnell aus und verliert dabei Kraft.
	vec3 imp = vec3(0.0);
	vec2 lp = UV * rect_size;
	for (int i = 0; i < IMPULSES; i++) {
		float pr = impulse_progress[i];
		if (pr <= 0.0 || pr >= 1.0) {
			continue;
		}
		float r = length(lp - impulse_pos[i]);
		float x2 = (r - pr * impulse_radius) / impulse_width;
		float ring = exp(-0.5 * x2 * x2);
		float env = pow(1.0 - pr, 1.6);
		imp += impulse_color[i].rgb * (ring * env * impulse_color[i].a);
	}

	// Hitzeschleier: weiches Gauß-Band um die Bandmitte, dessen Kante seitlich
	// verrauscht ist - so flimmert es, statt zu wischen. Klingt zum Ende aus.
	vec3 heat = vec3(0.0);
	if (heat_progress > 0.0 && heat_progress < 1.0) {
		float band = 1.0 - heat_progress;  // UV.y: 0 = oben, 1 = unten
		// Zwei Sinus plus ein je Zwölftelsekunde neu gewürfelter Spaltenversatz:
		// die Kante zappelt, statt als starres Streifenmuster zu stehen.
		float wob = sin(UV.x * 13.0 + TIME * 5.0) * 0.030
			+ sin(UV.x * 31.0 - TIME * 3.3) * 0.018
			+ (hash1(floor(UV.x * 23.0) + floor(TIME * 12.0) * 0.37) - 0.5) * 0.035;
		float dy = (UV.y - band + wob) / heat_width;
		heat = heat_color.rgb * (exp(-0.5 * dy * dy) * sin(heat_progress * PI) * heat_color.a);
	}

	float mask = step(0.0, depth);
	COLOR = vec4((acc * gain * intensity + imp * impulse_gain + heat * heat_gain) * mask, 1.0);
}
