shader_type canvas_item;

// Radial glow effect for the station in Last Stand minigame
// Pulses gently, shifts to red when HP is low

uniform float radius : hint_range(0.0, 1.0) = 0.3;
uniform float glow_intensity : hint_range(0.0, 2.0) = 0.5;
uniform float hp_ratio : hint_range(0.0, 1.0) = 1.0;
uniform float pulse_speed : hint_range(0.0, 5.0) = 2.0;

void fragment() {
	vec2 center = vec2(0.5, 0.5);
	float dist = length(UV - center);

	// Pulse
	float pulse = sin(TIME * pulse_speed) * 0.15 + 0.85;

	// Glow falloff
	float glow = smoothstep(radius, 0.0, dist) * glow_intensity * pulse;

	// Color: cyan when healthy, red when low HP
	vec3 healthy_color = vec3(0.3, 0.6, 1.0);
	vec3 danger_color = vec3(1.0, 0.15, 0.05);
	vec3 glow_color = mix(danger_color, healthy_color, hp_ratio);

	COLOR = vec4(glow_color * glow, glow * 0.6);
}
