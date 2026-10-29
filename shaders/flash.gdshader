shader_type canvas_item;

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform bool outline_enabled = false;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 5.0) = 1.0;
uniform bool outline_pulsating = false;

uniform float hue_shift : hint_range(-0.5, 0.5) = 0.0;
uniform float sat_mult : hint_range(0.0, 2.0) = 1.0;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 col = texture(TEXTURE, UV);

	if (outline_enabled && col.a < 0.1) {
		vec2 size = TEXTURE_PIXEL_SIZE * outline_width;
		float max_a = 0.0;
		max_a = max(max_a, texture(TEXTURE, UV + vec2(size.x, 0.0)).a);
		max_a = max(max_a, texture(TEXTURE, UV - vec2(size.x, 0.0)).a);
		max_a = max(max_a, texture(TEXTURE, UV + vec2(0.0, size.y)).a);
		max_a = max(max_a, texture(TEXTURE, UV - vec2(0.0, size.y)).a);
		max_a = max(max_a, texture(TEXTURE, UV + vec2(size.x, size.y)).a);
		max_a = max(max_a, texture(TEXTURE, UV + vec2(size.x, -size.y)).a);
		max_a = max(max_a, texture(TEXTURE, UV + vec2(-size.x, size.y)).a);
		max_a = max(max_a, texture(TEXTURE, UV + vec2(-size.x, -size.y)).a);

		if (max_a > 0.5) {
			vec4 final_outline = outline_color;
			if (outline_pulsating) {
				// Stepped retro pulsating shift: gold -> yellow -> white (8 fps GBA rate)
				float t = mod(floor(TIME * 8.0), 3.0);
				if (t < 1.0) {
					final_outline = vec4(1.0, 0.84, 0.0, outline_color.a); // Gold
				} else if (t < 2.0) {
					final_outline = vec4(1.0, 1.0, 0.2, outline_color.a);  // Yellow
				} else {
					final_outline = vec4(1.0, 1.0, 1.0, outline_color.a);  // White
				}
			}
			col = final_outline;
		}
	}

	if (col.a > 0.1) {
		vec3 base_rgb = col.rgb * COLOR.rgb;
		if (abs(hue_shift) > 0.0001 || abs(sat_mult - 1.0) > 0.0001) {
			vec3 hsv = rgb2hsv(base_rgb);
			hsv.x = fract(fract(hsv.x + hue_shift) + 1.0);
			hsv.y = clamp(hsv.y * sat_mult, 0.0, 1.0);
			base_rgb = hsv2rgb(hsv);
		}
		col.rgb = mix(base_rgb, flash_color.rgb, flash);
	}

	COLOR = vec4(col.rgb, col.a * COLOR.a);
}
