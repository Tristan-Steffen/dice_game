shader_type canvas_item;
// Das DECK: der 2D-Grund der Tisch-Anzeige (TableScreen._build_content) ist eine PLATINE in
// dunklem Nachtgrün (Spieler-Wahl 2026-11-23). Das Muster rechnet in WELT-Koordinaten
// (pcb_pattern.gdshaderinc) und läuft so in den Deck-Ring der Wanne durch.

#include "res://assets/shaders/pcb_pattern.gdshaderinc"

uniform vec3 deck_color : source_color = vec3(0.012, 0.05, 0.044);
uniform float grain_strength : hint_range(0.0, 0.5) = 0.02;
// Pixel -> Welt: x = origin.x - py / px_per_world, z = origin.y + px / px_per_world.
uniform vec2 world_origin = vec2(42.4, -62.4);
uniform float px_per_world = 37.5;

// Unter den leicht durchscheinenden Fenstergründen bleibt der Lack glatt (dieselben
// Rechtecke wie screen_glass.gdshader, TableScreen._sync_reflection_windows speist beide).
uniform vec2 rect_size = vec2(4680.0, 3180.0);
const int MAX_WINDOWS = 24;
uniform int window_count = 0;
uniform vec4 window_rects[MAX_WINDOWS];   // xy = Pixel-Min, zw = Pixel-Max
uniform float window_radius[MAX_WINDOWS];
// Weitere ruhige Felder: Schirme, die nicht spiegeln, und der Speicher mit seinen Zügen.
const int MAX_QUIET = 12;
uniform int quiet_count = 0;
uniform vec4 quiet_rects[MAX_QUIET];

float window_mask(vec2 p, vec4 rect, float radius) {
	vec2 c = (rect.xy + rect.zw) * 0.5;
	vec2 half_size = (rect.zw - rect.xy) * 0.5 - vec2(radius);
	vec2 d = abs(p - c) - half_size;
	float dist = length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - radius;
	return 1.0 - smoothstep(-4.0, 4.0, dist);
}

void fragment() {
	vec2 p = UV * rect_size;
	float calm = 0.0;
	for (int i = 0; i < window_count; i++) {
		calm = max(calm, window_mask(p, window_rects[i], window_radius[i]));
	}
	for (int i = 0; i < quiet_count; i++) {
		calm = max(calm, window_mask(p, quiet_rects[i], 8.0));
	}
	float board = 1.0 - calm;
	vec2 w = vec2(world_origin.x - p.y / px_per_world, world_origin.y + p.x / px_per_world);
	vec3 deck = pcb_paint(deck_color, w, 1.2 / (px_per_world * PCB_TILE), board);
	float grain = pcb_hash(floor(p / 3.0));
	deck *= 1.0 + (grain - 0.5) * 2.0 * grain_strength * board;
	COLOR = vec4(deck, 1.0);
}
