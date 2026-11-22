// Kar zemini (SPEC §15). Compatibility görüntü ayarında çalışır.
// - Büyük, yumuşak ton farkları (rüzgârın savurduğu kar)
// - Rüzgâr dalgaları: karın üstünde ince, kıvrımlı açık-mavi çizgiler
// - Haritaya özel maske (map_mask): engel diplerinde gölge çukuru (R), parlak kar birikintisi (G), ezilmiş patika (B)
// - Parıltılar: güneşte yanıp sönen küçük kar kristalleri
shader_type spatial;
render_mode diffuse_toon, specular_disabled;

uniform vec3 snow_light : source_color = vec3(0.93, 0.95, 1.0);
uniform vec3 snow_mid : source_color = vec3(0.85, 0.89, 0.98);
uniform vec3 snow_shadow : source_color = vec3(0.66, 0.76, 0.93);
uniform vec3 ripple_color : source_color = vec3(0.74, 0.82, 0.96);
uniform vec3 path_color : source_color = vec3(0.72, 0.78, 0.92);
uniform sampler2D map_mask : filter_linear, repeat_disable;
uniform float map_size = 37.5;
uniform float sparkle_strength = 0.9;
// Güneş + ortam ışığı toplamı 1'in üstünde: zemin renkleri bununla çarpılmazsa bembeyaz patlar,
// gölge çukurları da camgöbeğine döner (sadece mavi kanal taşmadan kalır).
uniform float light_comp = 0.84;

varying vec3 world_pos;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 3; i++) {
		v += vnoise(p) * amp;
		p *= 2.03;
		amp *= 0.5;
	}
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;

	// büyük yumuşak ton farkları
	float large = fbm(p * 0.07);
	vec3 col = mix(snow_mid, snow_light, smoothstep(0.3, 0.7, large));

	// rüzgâr dalgaları: kıvrılan ince çizgiler, bazı bölgelerde belirgin
	float warp = fbm(p * 0.18 + 3.1) * 4.0;
	float wave = sin(dot(p, vec2(0.85, 0.45)) * 2.6 + warp);
	float ridge = smoothstep(0.82, 0.98, wave);
	float region = smoothstep(0.35, 0.65, fbm(p * 0.06 + 11.0));
	col = mix(col, ripple_color, ridge * region * 0.55);

	// haritaya özel maske (oyun alanının dışında 0)
	vec2 uv = p / map_size + 0.5;
	vec3 mask = texture(map_mask, uv).rgb;
	col = mix(col, path_color, mask.b * 0.55);
	col = mix(col, snow_light * 1.02, mask.g * 0.6);
	col = mix(col, snow_shadow, mask.r * 0.85);

	// parıltılar: hücre başına en fazla bir kristal, zamanla yanıp söner
	vec2 g = p * 5.0;
	vec2 cell = floor(g);
	float h = hash(cell);
	vec2 offset = vec2(hash(cell + 1.7), hash(cell + 9.2)) - 0.5;
	float d = length(fract(g) - 0.5 - offset * 0.6);
	float twinkle = pow(max(0.0, sin(TIME * 2.5 + h * 60.0)), 6.0);
	float sparkle = step(0.9, h) * smoothstep(0.09, 0.0, d) * twinkle * (1.0 - mask.r);

	ALBEDO = col * light_comp;
	EMISSION = vec3(sparkle * sparkle_strength);
}
