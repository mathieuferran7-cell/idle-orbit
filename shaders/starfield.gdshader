shader_type canvas_item;

// Starfield parallax shader — 3 layers, mobile-friendly
// Each layer has different star density, size, speed and brightness

uniform float scroll_speed : hint_range(0.0, 0.1) = 0.015;
uniform vec4 bg_color : source_color = vec4(0.04, 0.04, 0.1, 1.0);

// Hash function for pseudo-random star placement
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Single star layer
float star_layer(vec2 uv, float scale, float brightness, float time_offset) {
	vec2 grid = floor(uv * scale);
	vec2 sub = fract(uv * scale);

	float rand_val = hash(grid);
	// Only ~30% of cells have a star
	if (rand_val > 0.3) {
		return 0.0;
	}

	// Star position within cell (centered with margin)
	vec2 star_pos = vec2(hash(grid + 0.1), hash(grid + 0.2)) * 0.6 + 0.2;
	float dist = length(sub - star_pos);

	// Star size varies per cell
	float star_size = mix(0.02, 0.06, hash(grid + 0.3));

	// Twinkle effect
	float twinkle = sin(TIME * mix(1.5, 4.0, hash(grid + 0.4)) + time_offset + rand_val * 6.28) * 0.3 + 0.7;

	// Brightness falloff
	float star = smoothstep(star_size, 0.0, dist) * brightness * twinkle;

	return star;
}

void fragment() {
	vec2 uv = UV;

	// Slow vertical scroll for each layer (parallax)
	float t = TIME * scroll_speed;

	// Layer 1: distant small stars (slow)
	vec2 uv1 = uv + vec2(0.0, t * 0.3);
	float stars1 = star_layer(uv1, 60.0, 0.4, 0.0);

	// Layer 2: medium stars
	vec2 uv2 = uv + vec2(0.0, t * 0.6);
	float stars2 = star_layer(uv2, 35.0, 0.7, 2.0);

	// Layer 3: close bright stars (fast)
	vec2 uv3 = uv + vec2(0.0, t * 1.0);
	float stars3 = star_layer(uv3, 18.0, 1.0, 4.5);

	// Combine layers
	float stars = stars1 + stars2 + stars3;

	// Subtle blue/cyan tint on brighter stars
	vec3 star_color = mix(vec3(0.8, 0.85, 1.0), vec3(0.6, 0.9, 1.0), stars);

	vec3 final_color = bg_color.rgb + star_color * stars;
	COLOR = vec4(final_color, 1.0);
}
