shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

// CRT scanlines toggle
uniform bool crt_enabled = true;

// Subtle CRT horizontal scanlines (reduced visibility for clean mobile look)
uniform float scanline_count : hint_range(60.0, 480.0) = 160.0;
uniform float scanline_line_size : hint_range(1.0, 10.0) = 2.0;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.18;

// Chromatic aberration slider (0 to 100)
uniform float chromatic_aberration : hint_range(0.0, 100.0) = 10.0;

void fragment() {
	vec4 col;
	if (chromatic_aberration > 0.01) {
		float ca_offset = (chromatic_aberration / 100.0) * 0.008;
		float r = texture(screen_texture, SCREEN_UV - vec2(ca_offset, 0.0)).r;
		float g = texture(screen_texture, SCREEN_UV).g;
		float b = texture(screen_texture, SCREEN_UV + vec2(ca_offset, 0.0)).b;
		col = vec4(r, g, b, 1.0);
	} else {
		col = texture(screen_texture, SCREEN_UV);
	}

	if (crt_enabled) {
		// Horizontal CRT scanlines with customizable line size
		float effective_count = scanline_count / max(scanline_line_size * 0.5, 0.1);
		float scanline = sin(SCREEN_UV.y * effective_count * PI * 2.0);
		scanline = (scanline + 1.0) * 0.5;
		scanline = pow(scanline, 1.3);
		col.rgb -= col.rgb * (scanline * scanline_intensity);
	}

	COLOR = col;
}
