shader_type spatial;
// Der GÜTE-SCHIMMER eines Pakets: liegt als Overlay auf allen Flächen der Hülle. Ein
// Lichtstreif wandert in Weltkoordinaten über den Tisch, Royal funkelt dazu.
render_mode unshaded, blend_add, depth_draw_never;

uniform vec4 tint : source_color = vec4(1.0);
uniform float strength = 0.4;
uniform float glitter = 0.0;
// Abstand zweier Streifen (Welt) und Durchläufe je Sekunde.
uniform float period = 13.0;
uniform float speed = 0.22;

varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float phase = fract((world.z * 0.75 + world.x * 0.35 + world.y * 0.5) / period - TIME * speed);
	float band = smoothstep(0.085, 0.0, abs(phase - 0.5))
		+ 0.45 * smoothstep(0.028, 0.0, abs(phase - 0.63));
	vec2 grain = (world.xz + world.y * 0.37) * 7.0;
	float seed = hash(floor(grain));
	float spark = step(0.88, seed) * smoothstep(0.24, 0.0, length(fract(grain) - 0.5))
		* pow(max(sin(TIME * 2.4 + seed * 40.0), 0.0), 4.0);
	ALBEDO = tint.rgb;
	ALPHA = clamp(band * strength + spark * glitter + strength * 0.06, 0.0, 1.0);
}
