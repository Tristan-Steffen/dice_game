// Das Muster der PLATINE, EINE Quelle für die Anzeige (table_pcb.gdshader) und den Deck-Ring
// der Wanne (table_body.gdshader): Leiterzug-Bündel mit 45-Grad-Ecken und
// Durchkontaktierungen, gekachelt in WELT-Koordinaten (x, z) - so läuft es über den Rand
// der Anzeige durch.

const float PCB_TILE = 4.2;
const float PCB_PITCH = 0.075;
const float PCB_WIDTH = 0.014;
const float PCB_TURN = 0.28;
const vec3 PCB_VIA = vec3(0.62, 0.48, 0.2);
const float PCB_TRACE_GAIN = 0.75;
const float PCB_VIA_GAIN = 0.6;

float pcb_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float pcb_seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}

// Ein Zug von der linken Kantenmitte zur unteren, mit 45-Grad-Ecke.
float pcb_bend(vec2 q) {
	float d = pcb_seg(q, vec2(-0.5, 0.0), vec2(-PCB_TURN, 0.0));
	d = min(d, pcb_seg(q, vec2(-PCB_TURN, 0.0), vec2(0.0, -PCB_TURN)));
	return min(d, pcb_seg(q, vec2(0.0, -PCB_TURN), vec2(0.0, -0.5)));
}

// Färbt den Lack: w = Weltpunkt (x, z), aa = Kantenweichheit in Kachel-Anteilen,
// amount = 0..1 (0 = glatter Lack).
vec3 pcb_paint(vec3 mask, vec2 w, float aa, float amount) {
	vec2 cell = floor(w / PCB_TILE);
	vec2 q = fract(w / PCB_TILE) - 0.5;
	float kind = pcb_hash(cell);
	float d = 1.0;
	float via = 1.0;
	if (kind < 0.36) {
		d = min(pcb_bend(q), pcb_bend(-q));
	} else if (kind < 0.72) {
		vec2 m = vec2(-q.x, q.y);
		d = min(pcb_bend(m), pcb_bend(-m));
	} else {
		// Gerader Zug, quer dazu zwei Stiche mit Durchkontaktierung.
		vec2 r = kind < 0.86 ? q : q.yx;
		d = pcb_seg(r, vec2(-0.5, 0.0), vec2(0.5, 0.0));
		d = min(d, pcb_seg(r, vec2(0.0, 0.5), vec2(0.0, 0.3)));
		d = min(d, pcb_seg(r, vec2(0.0, -0.5), vec2(0.0, -0.3)));
		via = min(length(r - vec2(0.0, 0.3)), length(r - vec2(0.0, -0.3)));
	}
	float lines = 1.0 - smoothstep(PCB_WIDTH, PCB_WIDTH + aa, d);
	lines = max(lines, 1.0 - smoothstep(PCB_WIDTH, PCB_WIDTH + aa, abs(d - PCB_PITCH)));
	float ring = 1.0 - smoothstep(0.03, 0.03 + aa, abs(via - 0.012));
	float hole = 1.0 - smoothstep(0.012, 0.012 + aa, via);
	vec3 c = mask * (1.0 + PCB_TRACE_GAIN * lines * amount);
	c = mix(c, PCB_VIA, ring * PCB_VIA_GAIN * amount);
	return c * (1.0 - 0.6 * hole * amount);
}
