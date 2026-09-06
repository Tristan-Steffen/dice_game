shader_type spatial;
render_mode blend_add, depth_draw_never, depth_test_disabled, cull_back, unshaded,
	shadows_disabled;

// Die GLUT der Hitze - die ZWEITE Lage neben die_heat.gdshader (der Verzerrung).
// Warum zwei: eine Refraktion muss Pixel ERSETZEN, sie liest dafür den
// Bildschirm-Abzug, und der wird VOR den durchsichtigen Dingen genommen. Zuerst
// gezeichnet wird die Verzerrung darum von den Nachbar-Würfeln übermalt (die
// Hitze fehlte unter dem Würfel, weil dort die nächste Reihe steht), zuletzt
// gezeichnet löschte sie deren Ziffern. Also: die VERZERRUNG liegt zuunterst
// (sie wirkt ohnehin nur auf dem freien Filz), die GLUT liegt ADDITIV zuoberst -
// sie ersetzt nichts, sie hellt nur auf, und darum steht sie RUNDUM.
//
// Die Masken- und Wellen-Rechnung ist die GLEICHE wie in die_heat.gdshader; wer
// eine ändert, ändert beide. Dieselben Uniforms, aus derselben Stelle gesetzt
// (DieFaceDisplay._sync_heat).

uniform float mode = 0.0;
uniform vec2 quad_size = vec2(7.0, 7.0);
uniform float lift = 0.0;
uniform float inner = 1.0;
uniform float reach = 1.9;
uniform float wave_freq = 4.4;
uniform float wave_speed = 0.15;
uniform float blobs = 7.0;
uniform float phase = 0.0;
uniform vec3 tint = vec3(0.95, 0.24, 0.08);
uniform float tint_amount = 0.26;

// Wie schnell die Glut nach INNEN wegfällt. Ihr Höhepunkt liegt AUF der
// Silhouette - sie beginnt an Flächen und Kanten und strahlt nach außen.
const float INWARD = 3.2;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float ring_noise(vec2 p, float period) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float x0 = mod(i.x, period);
	float x1 = mod(i.x + 1.0, period);
	return mix(
		mix(hash21(vec2(x0, i.y)), hash21(vec2(x1, i.y)), f.x),
		mix(hash21(vec2(x0, i.y + 1.0)), hash21(vec2(x1, i.y + 1.0)), f.x), f.y);
}

void vertex() {
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
	vec2 p = (UV - 0.5) * quad_size;
	p.y = -p.y;
	float r = length(p);
	float d = mix(r, max(abs(p.x), abs(p.y)), 0.5) - inner;
	// Höhepunkt AUF der Silhouette (d = 0): nach außen mit reach, nach innen rasch.
	// Eine Maske, die den Körper aussparte, ließ eine LÜCKE zwischen Würfel und
	// Hitze - und dort, wo der Würfel im Bild weit reicht, fehlte sie ganz.
	float field = exp(-max(d, 0.0) * 2.0 / reach) * exp(-max(-d, 0.0) * INWARD);
	float half_span = min(quad_size.x, quad_size.y) * 0.5;
	field *= 1.0 - smoothstep(half_span - 1.4, half_span - 0.2,
		max(abs(p.x), abs(p.y)));
	float ang = (atan(p.y, p.x) / TAU + 0.5) * blobs;

	float front = r - t * wave_speed;
	float wave;
	if (mode < 0.5) {
		wave = sin(front * wave_freq);
	} else if (mode < 1.5) {
		float n = ring_noise(vec2(ang, front * wave_freq * 0.16), blobs);
		wave = smoothstep(0.28, 0.86, n) * 2.0 - 1.0;
	} else {
		float wob = ring_noise(vec2(ang, t * 0.25), blobs) - 0.5;
		wave = sin((front + wob * 1.1) * wave_freq);
	}

	ALBEDO = tint;
	// Additiv: dest + tint × ALPHA. Sie hellt auf, sie ersetzt nie.
	ALPHA = clamp(tint_amount * field * (0.78 + 0.22 * wave), 0.0, 1.0);
}
