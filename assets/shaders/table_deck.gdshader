shader_type canvas_item;
// Das DECK: der 2D-Grund der Tisch-Anzeige (TableScreen._build_content). Alles AUSSERHALB der
// Fenster liest als dunkles gefrästes Metall mit Platten-Fugen. Die Fugen rechnen in WELT-
// Koordinaten - dieselbe Rechnung wie table_body.gdshader, so laufen sie über den Rand der
// Anzeige in den Deck-Ring der Wanne durch.

uniform vec3 deck_color : source_color = vec3(0.0645, 0.0688, 0.086);
uniform float seam = 9.0;            // Platten-Teilung in Welt
uniform float seam_depth : hint_range(0.0, 1.0) = 0.5;
uniform float grain_strength : hint_range(0.0, 0.5) = 0.05;
// Pixel -> Welt: x = origin.x - py / px_per_world, z = origin.y + px / px_per_world.
uniform vec2 world_origin = vec2(42.4, -62.4);
uniform float px_per_world = 37.5;

// Unter den leicht durchscheinenden Fenstergründen bleibt das Deck glatt (dieselben Rechtecke
// wie screen_glass.gdshader, TableScreen._sync_reflection_windows speist beide).
uniform vec2 rect_size = vec2(4680.0, 3180.0);
const int MAX_WINDOWS = 24;
uniform int window_count = 0;
uniform vec4 window_rects[MAX_WINDOWS];   // xy = Pixel-Min, zw = Pixel-Max
uniform float window_radius[MAX_WINDOWS];

float window_mask(vec2 p, vec4 rect, float radius) {
	vec2 c = (rect.xy + rect.zw) * 0.5;
	vec2 half_size = (rect.zw - rect.xy) * 0.5 - vec2(radius);
	vec2 d = abs(p - c) - half_size;
	float dist = length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - radius;
	return 1.0 - smoothstep(-4.0, 4.0, dist);
}

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 p = UV * rect_size;
	float glass = 0.0;
	for (int i = 0; i < window_count; i++) {
		glass = max(glass, window_mask(p, window_rects[i], window_radius[i]));
	}
	float metal = 1.0 - glass;
	vec2 w = vec2(world_origin.x - p.y / px_per_world, world_origin.y + p.x / px_per_world);
	vec2 g = abs(fract(w / seam - 0.5) - 0.5) * seam;
	float line = 1.0 - step(0.07, min(g.x, g.y));
	// Bürststriche längs Bild-rechts.
	float grain = hash21(vec2(floor(p.x / 24.0), floor(p.y / 2.0)));
	vec3 deck = deck_color * (1.0 - seam_depth * line * metal);
	deck *= 1.0 + (grain - 0.5) * 2.0 * grain_strength * metal;
	COLOR = vec4(deck, 1.0);
}
