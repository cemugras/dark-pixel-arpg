shader_type canvas_item;

// Arena dışındaki lavı canlandırır: sadece doygun kızıl/turuncu piksellere (lav, kızgın çatlaklar)
// dünyada yavaşça kayan dalgalı bir parlaklık uygular. Gri zemin (düşük doygunluk) etkilenmez.
// Parlaklık basamaklı (STEPS) değişir ki piksel sanat yumuşak geçişe dönmesin.

uniform float speed = 0.5;
uniform float strength = 0.35;
uniform float steps = 5.0;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float sat = mx > 0.0 ? (mx - mn) / mx : 0.0;
	float lava = smoothstep(0.45, 0.7, sat) * step(c.b, c.r);
	float t = TIME * speed;
	vec2 p = floor(world_pos / 2.0) * 2.0;  // 2x2 piksel blok: dalga pikselli görünsün
	float n = sin(p.x * 0.045 + t) * sin(p.y * 0.06 - t * 0.7) + 0.5 * sin((p.x - p.y) * 0.025 + t * 1.3);
	n = floor(n * steps) / steps;
	c.rgb *= 1.0 + strength * n * lava;
	c.rgb += vec3(0.22, 0.10, 0.0) * max(n, 0.0) * lava * strength;  // en kızgın yerler sarıya kayar
	COLOR = c * COLOR;
}
