shader_type spatial;
render_mode unshaded;

// Haut des Schwarzmarkts: festes Schlüssellicht wie chip_steel, dazu Glanz und Bürstspur je
// Entwurf. Die Schubfächer schneiden sich an der Gehäuse-Rückwand ab (clip_plane, Welt).
uniform vec3 base : source_color = vec3(0.2, 0.2, 0.23);
uniform float brush = 0.5;
uniform float gloss = 0.2;
uniform bool flat_lit = false;
uniform bool clip_on = false;
uniform vec4 clip_plane = vec4(1.0, 0.0, 0.0, 1000.0);

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	if (clip_on && dot(world_pos, clip_plane.xyz) > clip_plane.w) {
		discard;
	}
	vec3 color = base;
	if (!flat_lit) {
		vec3 n = normalize(world_normal);
		vec3 key = normalize(vec3(0.55, 0.7, -0.4));
		float lit = clamp(dot(n, key) * 0.5 + 0.5, 0.0, 1.0);
		float top = smoothstep(0.8, 0.99, n.y);
		float sweep = 0.5 + 0.5 * sin(world_pos.x * 0.11 - world_pos.z * 0.07 + 0.8);
		float grain = fract(sin(dot(floor(world_pos.xz * vec2(48.0, 1.2)), vec2(12.9898, 78.233))) * 43758.5453);
		color = base * (0.42 + 0.8 * pow(lit, 1.4));
		color = mix(color, base * (0.78 + 0.34 * sweep), top * 0.8);
		color *= 1.0 + (grain - 0.5) * brush * 0.35;
		color += vec3(0.85, 0.85, 0.95) * gloss * 0.3 * pow(sweep, 6.0) * top;
		float edge = pow(clamp(dot(n, normalize(key + vec3(0.0, 0.6, 0.0))), 0.0, 1.0), 20.0);
		color += vec3(0.8, 0.84, 0.95) * edge * (0.25 + gloss * 0.4) * (1.0 - top);
	}
	// Unter der Bloom-Schwelle.
	ALBEDO = min(color, vec3(0.9));
}
