shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded, shadows_disabled;

// HITZE, die vom Würfel wegwabert: das Bild HINTER dem Körper wird wie heiße
// Luft verzerrt (Screen-Refraktion), nach oben ziehend. Kein Licht, keine Fläche -
// nur das Flimmern. Zwei Formen: eine FAHNE (Billboard-Quad über dem Würfel,
// Maske über die Quad-UV: seitlich weich, oben verlöschend) und ein SCHLEIER
// (Box-Hülle um den Würfel, Maske am Silhouettenrand - Fresnel). Die Hülle liegt
// abgehoben und zeigt kein eigenes Bild: sie ist unsichtbar, wo sie nicht verzerrt.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;
// 0 = Fahne (Quad-Maske), 1 = Schleier (Fresnel-Maske)
uniform float mode = 0.0;
// Billboard: das Quad dreht sich zur Kamera, behält aber die Modell-Skalierung.
uniform float billboard = 0.0;
// Versatz im Bild (Anteil der Bildschirmbreite) - die Stärke des Flimmerns.
uniform float strength = 0.025;
uniform float speed = 1.0;
uniform float scale = 5.0;
uniform float phase = 0.0;
// Die GLUT im Flimmern: orange-rot, damit die Hitze als Hitze liest.
// tint_mode: 0 gleichmäßiger Hauch, 1 Glut am Würfel (unten stark, oben aus),
// 2 nur auf den Wellenkämmen des Rauschens, 3 nur am Rand (Schleier-Maske),
// 4 Verlauf von tint (unten) nach tint2 (oben).
uniform vec3 tint = vec3(0.95, 0.24, 0.08);
uniform vec3 tint2 = vec3(1.0, 0.58, 0.16);
uniform float tint_amount = 0.0;
uniform float tint_mode = 0.0;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Wert-Rauschen, weich interpoliert - Hitzeschlieren, keine Kanten.
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	if (billboard > 0.5) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1],
			INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

void fragment() {
	float t = TIME * speed + phase;
	float mask;
	if (mode < 0.5) {
		// Fahne: in der Mitte voll, seitlich weich, oben verlöschend, unten (am
		// Würfel) ohne harte Kante.
		float mx = 1.0 - abs(UV.x - 0.5) * 2.0;
		float side = smoothstep(0.0, 0.6, mx);
		float top = smoothstep(0.0, 0.65, UV.y);
		float foot = smoothstep(1.0, 0.9, UV.y);
		mask = side * top * foot;
	} else {
		// Schleier: nur am Silhouettenrand, wo die Hülle den Blick streift.
		float fres = 1.0 - clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
		mask = pow(fres, 1.6);
	}
	// Zwei Oktaven, beide nach OBEN ziehend (UV.y wächst nach unten).
	vec2 p1 = vec2(UV.x * scale, UV.y * scale + t);
	vec2 p2 = vec2(UV.x * scale * 2.3 + 7.3, UV.y * scale * 2.3 + t * 1.7);
	float n1 = vnoise(p1);
	float n2 = vnoise(p2);
	vec2 offset = (vec2(n1, n2) - 0.5) * 2.0 * strength * mask;
	vec3 seen = texture(screen_texture, SCREEN_UV + offset).rgb;
	// Nähe zum Würfel: die Fahne ist unten (UV.y -> 1) am heißesten, der
	// Schleier überall gleich nah.
	float near = mode < 0.5 ? UV.y * UV.y : 1.0;
	vec3 glow = tint;
	float amount = tint_amount * mask * (0.35 + 0.65 * n1);
	if (tint_mode > 3.5) {
		glow = mix(tint2, tint, mode < 0.5 ? UV.y : 0.6);
	} else if (tint_mode > 2.5) {
		amount = mode < 0.5 ? 0.0 : tint_amount * mask;
	} else if (tint_mode > 1.5) {
		amount = tint_amount * mask * pow(n1, 3.0) * 2.6;
	} else if (tint_mode > 0.5) {
		amount = tint_amount * mask * near * (0.5 + 0.5 * n1);
	}
	ALBEDO = seen + glow * amount;
	ALPHA = 1.0;
}
