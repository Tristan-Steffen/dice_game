// Fumble-Stoßwelle: EIN roter Ring aus der Grubenmitte über den GANZEN Tisch -
// wächst, bis er jedes Fenster passiert hat (max_radius = entfernteste Ecke).
// Sichtbar NUR auf den Fenstern (dieselben Rechtecke wie screen_glass.gdshader,
// TableScreen._sync_reflection_windows speist beide) - der Filz bleibt dunkel.
// progress außerhalb (0,1) = still (TableScreen._fire_fumble_wave treibt ihn).
shader_type canvas_item;
render_mode blend_add;

uniform vec2 rect_size = vec2(4680.0, 3180.0);
uniform vec2 center = vec2(0.0);
uniform float progress = 1.0;
uniform float max_radius = 5000.0;
uniform float width = 165.0;   // Ringdicke (Gauß-Sigma, px)
uniform vec4 color : source_color = vec4(2.4, 0.16, 0.18, 0.95);

const int MAX_WINDOWS = 20;
uniform int window_count = 0;
uniform vec4 window_rects[MAX_WINDOWS];   // xy = Pixel-Min, zw = Pixel-Max
uniform float window_radius[MAX_WINDOWS]; // Eckenradius in Pixeln

// Abdeckung eines abgerundeten Fenster-Rechtecks am Pixel p (SDF, weiche Kante).
float window_mask(vec2 p, vec4 rect, float radius) {
	vec2 c = (rect.xy + rect.zw) * 0.5;
	vec2 half_size = (rect.zw - rect.xy) * 0.5 - vec2(radius);
	vec2 d = abs(p - c) - half_size;
	float dist = length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - radius;
	return 1.0 - smoothstep(-4.0, 4.0, dist);
}

void fragment() {
	vec3 acc = vec3(0.0);
	if (progress > 0.0 && progress < 1.0) {
		vec2 p = UV * rect_size;
		float r = length(p - center);
		float x = (r - progress * max_radius) / width;
		float ring = exp(-0.5 * x * x);
		// Verliert Kraft beim Auslaufen, bleibt aber bis in die Ecken lesbar.
		float env = 1.0 - 0.68 * progress;
		float glass = 0.0;
		for (int i = 0; i < window_count; i++) {
			glass = max(glass, window_mask(p, window_rects[i], window_radius[i]));
		}
		acc = color.rgb * (ring * env * color.a * glass);
	}
	COLOR = vec4(acc, 1.0);
}
