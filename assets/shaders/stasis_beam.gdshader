// Kraftfeld-Säule je Tray-Emitter (siehe DiceTrayView): steht IMMER auf der
// Tischfläche und öffnet sich nach oben zum Würfel (Projektionskegel). Leer
// (engaged 0) glimmt nur ein kurzer Stummel über dem Emitter; mit Würfel
// (engaged 1) strömen helle Energiepakete von der Blende nach OBEN und
// verlöschen an der Würfel-Unterseite (grip_h) - so wird sichtbar, dass der
// Emitter den Würfel trägt. load pulst mit der Wurf-Last (siehe _process).
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform vec3 beam_color : source_color = vec3(0.3, 0.68, 1.0);
uniform float beam_height = 1.7;   // muss der Zylinderhöhe entsprechen (lokale Ausblendung)
uniform float engaged : hint_range(0.0, 1.0) = 0.0;  // 0 = leerer Slot, 1 = Würfel im Feld
uniform float load : hint_range(0.0, 2.0) = 1.0;     // Last-Puls: heller, wenn der Würfel sinkt
uniform float grip_h : hint_range(0.0, 1.0) = 0.85;  // relative Höhe der Würfel-Unterseite
uniform float idle_h : hint_range(0.0, 1.0) = 0.45;  // sichtbare Säulenhöhe im Leerlauf
uniform float base_alpha : hint_range(0.0, 1.0) = 0.03;
uniform float edge_alpha : hint_range(0.0, 1.0) = 0.17;
uniform float grip_alpha : hint_range(0.0, 1.0) = 0.3;
uniform float mote_alpha : hint_range(0.0, 1.0) = 0.85;  // Deckkraft der aufsteigenden Pakete
uniform float mote_count = 2.5;    // Pakete gleichzeitig in der Säule
uniform float mote_speed = 0.75;   // Aufstiegsgeschwindigkeit (Säulenlängen/s)
uniform float scan_freq = 8.0;
uniform float scan_speed = 2.5;
uniform float flicker_speed = 13.0;
uniform float flicker_amount : hint_range(0.0, 1.0) = 0.1;

varying float local_y;   // Zylinder-Vertex-Höhe (zentriert)
varying vec3 world_pos;

void vertex() {
	local_y = VERTEX.y;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	float h = clamp((local_y + beam_height * 0.5) / beam_height, 0.0, 1.0);
	// Leerlauf: kurzer, nach oben auslaufender Stummel. Im Betrieb TRÄGT die
	// Säule sichtbar bis zur Würfel-Unterseite (grip_h) und endet dort.
	float vis_h = mix(idle_h, 1.0, engaged);
	float fall = pow(clamp(1.0 - h / vis_h, 0.0, 1.0), 1.4);
	float carry = engaged * (1.0 - 0.5 * h) * step(h, grip_h + 0.04);
	float fade = max(fall, carry);
	float fres = pow(1.0 - abs(dot(n, normalize(VIEW))), 2.0);
	float wall = 1.0 - abs(n.y);  // Deckel/Boden ausblenden - nur die Säulenwand leuchtet
	float scan = 0.5 + 0.5 * sin(world_pos.y * scan_freq - TIME * scan_speed);
	float flick = 1.0 - flicker_amount * (0.5 + 0.5 * sin(TIME * flicker_speed) * sin(TIME * flicker_speed * 1.7));
	// Aufsteigende Energiepakete: scharfe helle Bänder, die nach oben wandern und
	// an der Würfel-Unterseite (grip_h) ausblenden - die sichtbare "Ursache".
	float flow = fract(h * mote_count - TIME * mote_speed);
	// Weiches Paket (kein Rasiermesser) das an der Würfel-Unterseite ausblendet.
	float mote = pow(flow, 4.0) * smoothstep(grip_h + 0.08, grip_h * 0.35, h) * engaged;
	// Griff-Ring unter dem getragenen Würfel - pulsiert mit der Last.
	float grip = smoothstep(0.08, 0.0, abs(h - grip_h)) * engaged;
	float column = (base_alpha + fres * edge_alpha) * fade * mix(0.7, 1.0, scan);
	float active = (grip * grip_alpha + mote * mote_alpha) * load;
	float intensity = (column + active) * wall * flick * mix(0.7, 1.0, engaged);
	ALBEDO = beam_color * (1.0 + mote * 1.3);  // Pakete heller/weißlicher
	ALPHA = clamp(intensity, 0.0, 1.0);
}
