shader_type spatial;
render_mode unshaded;

// Die BUCHSEN der Kammer: in die Grube fällt kein Szenenlicht, also trägt das Bauteil
// sein Licht selbst - ein festes Schräglicht im Blickraum, Glanzpunkt und Streiflicht.
uniform vec3 base : source_color = vec3(0.2, 0.22, 0.27);
uniform float metal = 1.0;
uniform float glow = 0.0;

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 light = normalize(vec3(-0.35, 0.75, 0.55));
	float lit = clamp(dot(n, light) * 0.5 + 0.5, 0.0, 1.0);
	float shine = pow(clamp(reflect(-light, n).z, 0.0, 1.0), 28.0);
	float rim = pow(1.0 - clamp(n.z, 0.0, 1.0), 3.0);
	// Ein grober Horizont statt einer Umgebung - Metall braucht etwas zum Spiegeln.
	float sky = smoothstep(-0.25, 0.55, n.y);
	vec3 color = base * (0.22 + 0.95 * lit);
	color = mix(color, color * (0.55 + 0.9 * sky), metal * 0.6);
	color += vec3(0.75, 0.85, 1.0) * (shine * 0.8 * metal + rim * 0.1);
	ALBEDO = color + base * glow;
}
