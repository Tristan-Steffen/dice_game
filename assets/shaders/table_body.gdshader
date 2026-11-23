shader_type spatial;
render_mode unshaded, cull_disabled;
// Der Tischkörper (TableBodyView): Lack, Leder, Pyramidenwand, Messing, Deck, Teppich.
// Das Licht ist EINGEMALT - im dunklen Raum beleuchtet nichts die Wanne, und ein so großes
// Netz finge sonst jedes Spill-Licht (max_lights_per_object).

uniform vec3 tint : source_color = vec3(0.5);
uniform float seams = 0.0;   // Platten-Fugen in Welt (0 = keine)
uniform bool pcb = false;    // das Deck: Platinen-Muster wie die Anzeige
uniform float gloss = 0.25;
uniform float glow = 0.0;    // 1 = Lichtleiste
// 0 glatt, 1 Diamant-Pyramiden (Wand), 2 gestepptes Leder, 3 Teppich.
uniform int style = 0;
uniform vec2 carpet_center = vec2(0.0);

#include "res://assets/shaders/pcb_pattern.gdshaderinc"

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Flächen-Normale aus den Ableitungen: die Netze tragen keine eigenen.
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (n.z < 0.0) {
		n = -n;
	}
	vec3 nw = normalize((INV_VIEW_MATRIX * vec4(n, 0.0)).xyz);
	vec3 v = normalize((INV_VIEW_MATRIX * vec4(normalize(-VERTEX), 0.0)).xyz);
	vec3 l = normalize(vec3(-0.35, 0.8, -0.45));
	vec3 base = tint;
	float shade = 0.3 + 0.7 * max(dot(nw, l), 0.0);
	if (style == 3) {
		vec2 q = vec2(wpos.x + wpos.z, wpos.x - wpos.z) / 16.0;
		vec2 d = 0.5 - abs(fract(q) - 0.5);
		float line = 1.0 - smoothstep(0.02, 0.045, min(d.x, d.y));
		float spot = 1.0 - smoothstep(0.1, 0.13, length(fract(q) - 0.5));
		vec3 c = tint + vec3(0.5, 0.36, 0.12) * (line * 0.2 + spot * 0.14);
		ALBEDO = c * (1.0 - smoothstep(80.0, 280.0, length(wpos.xz - carpet_center)));
	} else {
		if (style == 1 && abs(nw.y) < 0.85) {
			vec2 t = normalize(vec2(nw.z, -nw.x));
			vec2 f = fract(vec2(dot(wpos.xz, t), wpos.y) / 1.5) - 0.5;
			shade *= abs(f.x) > abs(f.y) ? (f.x > 0.0 ? 1.3 : 0.6) : (f.y > 0.0 ? 1.55 : 0.8);
		}
		if (style == 2) {
			vec2 d = 0.5 - abs(fract(vec2(wpos.x + wpos.z, wpos.x - wpos.z) / 3.4) - 0.5);
			shade *= 0.5 + 0.75 * sqrt(d.x * d.y * 4.0);
			if (d.x < 0.07 && d.y < 0.07) {
				base = vec3(0.86, 0.64, 0.24);
			}
		}
		if (pcb && nw.y > 0.9) {
			base = pcb_paint(base, wpos.xz, fwidth(wpos.x) / PCB_TILE * 1.2, 1.0);
		}
		vec3 c = base * shade;
		// Glanz nur gedämpft: die Flächen sind facettiert, ein harter Reflex springt je Polygon.
		c += gloss * 0.4 * pow(max(dot(nw, normalize(l + v)), 0.0), 40.0);
		c += gloss * 0.2 * pow(1.0 - max(dot(nw, v), 0.0), 3.0);
		if (seams > 0.0 && nw.y > 0.9) {
			vec2 g = abs(fract(wpos.xz / seams - 0.5) - 0.5) * seams;
			c *= 1.0 - 0.5 * (1.0 - step(0.07, min(g.x, g.y)));
		}
		// Unter der Tischkante verliert sich der Körper im Dunkel.
		c *= 0.25 + 0.75 * smoothstep(-55.0, -1.0, min(wpos.y, 0.0));
		ALBEDO = mix(c, tint * 1.5, glow);
	}
}
