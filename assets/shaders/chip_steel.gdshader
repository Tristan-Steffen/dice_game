shader_type spatial;
render_mode unshaded;

// Gebürsteter Stahl der Prozessor-Fassungen: der Tisch beleuchtet nichts, also trägt das
// Teil ein festes Studio - Schlüssellicht von Bild-oben-links, ein Verlauf über die
// flachen Deckflächen und feine Bürstspuren längs Bild-waagerecht.
uniform vec3 base : source_color = vec3(0.42, 0.44, 0.48);
uniform float brush = 0.5;
uniform float glow = 0.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 key = normalize(vec3(0.55, 0.7, -0.4));
	float lit = clamp(dot(n, key) * 0.5 + 0.5, 0.0, 1.0);
	float top = smoothstep(0.8, 0.99, n.y);
	float sweep = 0.5 + 0.5 * sin(world_pos.x * 0.13 - world_pos.z * 0.09 + 0.8);
	float grain = fract(sin(dot(floor(world_pos.xz * vec2(48.0, 1.2)), vec2(12.9898, 78.233))) * 43758.5453);
	vec3 color = base * (0.16 + 1.25 * pow(lit, 1.8));
	color = mix(color, base * (0.5 + 0.7 * sweep), top * 0.75);
	color *= 1.0 + (grain - 0.5) * brush * 0.3;
	float edge = pow(clamp(dot(n, normalize(key + vec3(0.0, 0.6, 0.0))), 0.0, 1.0), 20.0);
	color += vec3(0.8, 0.88, 1.0) * edge * 0.5 * (1.0 - top);
	ALBEDO = color + base * glow;
}
