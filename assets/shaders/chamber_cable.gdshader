shader_type spatial;
render_mode unshaded, cull_disabled;

// Ein FLACHBAND der Kammer: UV.x läuft von der Wand (0) zum Würfel (1), UV.y rundum.
// In die Grube fällt kein Szenenlicht - das Band rechnet sein Licht selbst.
uniform vec3 tint : source_color = vec3(0.3, 1.0, 0.5);
// Wie weit es ausgefahren ist - dahinter gibt es kein Band.
uniform float grow = 1.0;
// Kopf des Licht-Pulses (< 0 = keiner).
uniform float pulse = -1.0;
uniform float glow = 0.0;
// Adern quer über das Band (rundum gezählt).
uniform float strands = 10.0;

void fragment() {
	if (UV.x > grow) {
		discard;
	}
	vec3 n = normalize(NORMAL);
	vec3 light = normalize(vec3(-0.35, 0.75, 0.55));
	float lit = clamp(dot(n, light) * 0.5 + 0.5, 0.0, 1.0);
	float shine = pow(clamp(reflect(-light, n).z, 0.0, 1.0), 14.0);
	float groove = smoothstep(0.0, 0.3, abs(fract(UV.y * strands) - 0.5));
	float head = pulse < 0.0 ? 0.0 : smoothstep(0.2, 0.0, abs(UV.x - pulse));
	vec3 sheath = tint * (0.12 + 0.5 * lit) * mix(0.6, 1.0, groove)
		+ vec3(0.8, 0.88, 1.0) * shine * 0.2;
	ALBEDO = sheath + tint * (glow * 0.75 + head * 3.2);
}
