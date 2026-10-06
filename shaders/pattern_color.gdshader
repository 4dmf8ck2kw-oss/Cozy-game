shader_type canvas_item;

uniform vec4 color_dark : source_color = vec4(0.72, 0.55, 0.38, 1.0);  // линии
uniform vec4 color_mid : source_color = vec4(0.93, 0.84, 0.66, 1.0);   // основной цвет
uniform vec4 color_light : source_color = vec4(1.0, 0.96, 0.86, 1.0);  // блики
uniform float mid_point : hint_range(0.05, 0.95) = 0.6;  // яркость основного цвета в PNG
uniform float line_point : hint_range(0.0, 0.9) = 0.0;   // всё, что темнее, — чистый цвет линий

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	float v = dot(base.rgb, vec3(0.299, 0.587, 0.114));
	vec3 col;
	if (v <= line_point) {
		col = color_dark.rgb;
	} else if (v < mid_point) {
		col = mix(color_dark.rgb, color_mid.rgb, (v - line_point) / (mid_point - line_point));
	} else {
		col = mix(color_mid.rgb, color_light.rgb, (v - mid_point) / (1.0 - mid_point));
	}
	COLOR = vec4(col, base.a);
}
