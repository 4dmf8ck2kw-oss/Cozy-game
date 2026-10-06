shader_type canvas_item;

uniform vec4 hair_color : source_color = vec4(1.0);
uniform float light_boost : hint_range(0.0, 1.0) = 1.0;
uniform float shine : hint_range(0.0, 1.0) = 0.4;
uniform float saturation : hint_range(0.0, 1.5) = 0.85;
uniform float sway = 0.0;
uniform float sway_start : hint_range(0.0, 1.0) = 0.3;
uniform float sway_strength = 0.03;
uniform float sway_end : hint_range(0.0, 1.0) = 0.6;

void fragment () {
	float bend = smoothstep(sway_start, sway_end, UV.y);
	vec2 uv = UV + vec2(sway * sway_strength * bend, 0.0);
	vec4 base = texture(TEXTURE, uv);
	vec3 b = base.rgb;
	vec3 t = hair_color.rgb;
	vec3 multiply = b * t + max(b - 0.6, vec3(0.0)) * shine;
	vec3 low = 2.0 * b * t;
	vec3 high = 1.0 - 2.0 * (1.0 - b) * (1.0 - t);
	vec3 overlay = mix(low, high, step(0.5, b));
	float lum = dot(t, vec3(0.299, 0.587, 0.114));
	float k = smoothstep(0.35, 0.95, lum) * light_boost;
	vec3 col = mix(multiply, overlay, k);
	float gray = dot(col, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(vec3(gray), col, saturation), base.a);
}