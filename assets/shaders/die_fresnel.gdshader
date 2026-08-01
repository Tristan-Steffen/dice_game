shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;

// Fresnel-Schimmer der Würfel: additive Hülle knapp über dem Körper, deren
// Glühen mit flacherem Blickwinkel zunimmt - das Licht wirkt so, als käme es
// aus dem Glasvolumen statt von der Oberfläche. DAS ist die Farbabstrahlung
// des Würfels: sie hängt an ihm selbst, wirkt also in Grube, Tray, Werkstatt
// und Inspektor gleichermaßen (anders als die Lache, die einen Boden braucht).
//
// DIE REGEL: die Randzone gehört der Seele, die Flächenmitte der Einlage und
// der Ziffer. Additives Licht lässt sich nicht durch hellere Einlagen kontern -
// wer eine Seite lesbar halten will, muss ihr Licht WEGNEHMEN. Auf einem
// Essenz-Würfel sättigte der Fresnel-Term unter flachen Blickwinkeln (Tray!)
// und goss die Seelenfarbe über die ganze Fläche; Material und Ziffer
// verschwanden darunter. Die Randmaske unten schneidet genau diese Mitte frei.
// Sie rechnet in LOKALEN Koordinaten, ist also blickwinkel-relativ und in jeder
// Ansicht dieselbe - ein Würfel sieht überall gleich aus.

uniform vec3 glow_color = vec3(0.55, 0.91, 0.99);
uniform float strength : hint_range(0.0, 3.0) = 0.5;
// Steiler als früher (2.1): der Würfel soll strahlen, aber nicht mehr in seine
// eigenen Flächen hinein. Den Hauptteil der Arbeit macht die Randmaske.
uniform float falloff : hint_range(1.0, 5.0) = 2.8;
// Anteil der halben Flächenbreite, der GANZ frei bleibt (Chebyshev-Abstand zur
// Flächenmitte), und die Stelle, ab der die Hülle wieder voll trägt.
uniform float face_clear : hint_range(0.0, 1.0) = 0.55;
uniform float rim_soft : hint_range(0.0, 1.0) = 0.85;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float grazing = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(grazing, falloff);

	// Auf einem Würfel ist die größte Komponente die Achse der Fläche; sie ist
	// dort zugleich die halbe Kantenlänge, normiert sich also selbst. Die beiden
	// übrigen spannen die Fläche auf - ihr Chebyshev-Abstand ist 0 in der Mitte
	// und 1 am Flächenrand.
	vec3 p = abs(local_pos);
	float half_size = max(p.x, max(p.y, p.z));
	vec2 plane;
	if (p.x >= p.y && p.x >= p.z) {
		plane = vec2(p.y, p.z);
	} else if (p.y >= p.z) {
		plane = vec2(p.x, p.z);
	} else {
		plane = vec2(p.x, p.y);
	}
	float edge_dist = max(plane.x, plane.y) / max(half_size, 0.0001);
	// Silhouette, Ecken, Kantenzone und Lache behalten ihre volle Seele - nur
	// die Mitte wird ehrlich.
	fresnel *= smoothstep(face_clear, rim_soft, edge_dist);

	// unshaded verwirft EMISSION - die Farbe muss über ALBEDO raus. ALPHA
	// bleibt 1, sonst steckte der Fresnel-Abfall bei blend_add zweimal drin.
	ALBEDO = glow_color * fresnel * strength;
	ALPHA = 1.0;
}
