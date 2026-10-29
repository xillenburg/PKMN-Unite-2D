shader_type canvas_item;
render_mode blend_mix;

uniform bool bloom_enabled = true;
uniform float bloom_intensity : hint_range(0.0, 5.0) = 2.2;
uniform float bloom_radius : hint_range(0.0, 10.0) = 3.5;
uniform vec4 bloom_tint : source_color = vec4(1.0, 1.0, 0.95, 1.0);

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	if (!bloom_enabled) {
		COLOR = base * COLOR;
	} else {
		vec2 ps = TEXTURE_PIXEL_SIZE * bloom_radius;
		vec4 glow = vec4(0.0);
		float total_weight = 0.0;

		// Multi-tap bloom kernel for radiant luminous halo
		for (float x = -2.0; x <= 2.0; x += 1.0) {
			for (float y = -2.0; y <= 2.0; y += 1.0) {
				float dist = length(vec2(x, y));
				float weight = exp(-0.5 * dist * dist);
				vec2 offset = vec2(x, y) * ps;
				vec4 s = texture(TEXTURE, UV + offset);
				glow += s * weight;
				total_weight += weight;
			}
		}
		glow /= max(total_weight, 0.001);

		// Blend base sprite with vibrant bloom glow
		vec3 result_rgb = base.rgb + (glow.rgb * bloom_intensity * bloom_tint.rgb);
		float result_a = max(base.a, glow.a * clamp(bloom_intensity * 0.65, 0.0, 1.0));

		COLOR = vec4(result_rgb, result_a) * COLOR;
	}
}
