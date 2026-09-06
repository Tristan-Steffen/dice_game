shader_type spatial;
render_mode blend_mix, depth_draw_never, depth_test_disabled, cull_back, unshaded,
	shadows_disabled;

// HITZE, die AUS dem Würfel kommt: das Bild HINTER dem Feld wird wie heiße Luft
// verzerrt (Screen-Refraktion), in WELLEN, die radial nach außen laufen, und eine
// orange-rote Glut reitet auf ihren Kämmen. EIN Billboard-Quad vor dem Würfel; das
// Feld beginnt an der Silhouette, verlöscht mit dem Abstand und ist vor dem
// Quad-Rand sicher null - ein Rest dort las als Kante. Wo es nichts tut, ist es
// DURCHSICHTIG (ALPHA folgt dem Feld).
//
// KEIN Tiefentest (2026-09-06): das Feld ist eine flache Scheibe in KONSTANTER
// Tiefe, die Tischfläche dagegen eine schräg weglaufende Ebene - UNTERHALB des
// Würfels liegt sie näher an der Kamera und schnitt das Feld weg.
//
// ZWEI LAGEN (2026-09-06, gemessen): diese hier ist die VERZERRUNG und liegt
// ZUUNTERST (render_priority -8), denn sie liest den Bildschirm-Abzug, und der
// wird VOR den durchsichtigen Dingen genommen - zuletzt gezeichnet löschte sie
// die Ziffern. Dafür übermalen die Nachbar-Würfel sie; die GLUT trägt darum die
// zweite Lage (die_heat_glow.gdshader, ADDITIV und zuoberst), und erst dadurch
// steht die Hitze RUNDUM. Masken- und Wellen-Rechnung sind in beiden GLEICH.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;
// Kantenlänge des Quads in Modell-Einheiten (Würfel-Halbmaß = 1).
uniform vec2 quad_size = vec2(7.0, 7.0);
// Vorziehen zur Kamera - 0, denn ohne Tiefentest braucht es das nicht, und ein
// vorgezogenes Quad bildet sich perspektivisch GRÖSSER ab als der Würfel.
uniform float lift = 0.0;
// Die Silhouette (Würfel-Halbmaß) und wie schnell die Hitze mit dem Abstand fällt.
uniform float inner = 1.0;
uniform float reach = 1.9;
// Rest-Verzerrung über dem Körper.
uniform float inside = 0.25;
// Versatz in MODELL-Einheiten (Würfel-Halbmaß = 1), nicht in Bildschirmbreite:
// so schrumpft das Flimmern mit der scheinbaren Größe des Würfels mit, statt aus
// der Ferne gleich stark stehen zu bleiben.
uniform float strength = 0.012;
// Wellenzahl (Fronten je Modell-Einheit) und wie schnell sie auslaufen - das
// Tempo ist bewusst niedrig: eine Front braucht rund zehn Sekunden nach außen.
uniform float wave_freq = 4.4;
uniform float wave_speed = 0.15;
uniform float phase = 0.0;

void vertex() {
	// Billboard mit Modell-Skalierung, dann der Kamera entgegen.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(s, 0.0, 0.0, 0.0), vec4(0.0, s, 0.0, 0.0), vec4(0.0, 0.0, s, 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX[3].z += lift * s;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float t = TIME + phase;
	// Lage im Quad in Modell-Einheiten, y nach OBEN.
	vec2 p = (UV - 0.5) * quad_size;
	p.y = -p.y;
	float r = length(p);
	// Abstand zur Silhouette: halb Kreis, halb Quadrat - der Würfel ist beides.
	float d = mix(r, max(abs(p.x), abs(p.y)), 0.5) - inner;
	// Über dem Körper (d < 0) nur der Rest, ab der Silhouette voll.
	float body = smoothstep(-0.35, 0.05, d);
	float field = exp(-max(d, 0.0) * 2.0 / reach);
	float half_span = min(quad_size.x, quad_size.y) * 0.5;
	field *= 1.0 - smoothstep(half_span - 1.4, half_span - 0.2,
		max(abs(p.x), abs(p.y)));
	vec2 dir = normalize(p + vec2(0.0001, 0.0002));
	// Die WELLE (-1..1) läuft mit r - t nach AUSSEN, in jede Richtung gleich.
	float wave = sin((r - t * wave_speed) * wave_freq);

	// Der Versatz zeigt RADIAL: eine auslaufende Front schiebt das Bild vor sich
	// her. dir.y ist Modell-oben, SCREEN_UV.y läuft nach unten.
	float amp = field * mix(inside, 1.0, body);
	// Modell-Einheiten in Bildschirm-UV: die Ableitung sagt, wie groß der Würfel
	// gerade im Bild steht - aus der Ferne wird der Versatz damit kleiner.
	float uv_per_model = abs(dFdx(SCREEN_UV.x) / max(abs(dFdx(p.x)), 1e-6));
	vec2 offset = vec2(dir.x, -dir.y) * wave * strength * uv_per_model * amp;
	ALBEDO = texture(screen_texture, SCREEN_UV + offset).rgb;
	// Durchsichtig, wo das Feld nichts tut - kein Quadrat.
	ALPHA = clamp(field * 2.5, 0.0, 1.0);
}
