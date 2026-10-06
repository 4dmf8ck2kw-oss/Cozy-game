shader_type canvas_item;

uniform vec4 color_dark : source_color = vec4(0.55, 0.29, 0.24, 1.0);
uniform vec4 color_mid : source_color = vec4(0.96, 0.78, 0.68, 1.0);
uniform vec4 color_light : source_color = vec4(1.0, 0.9, 0.84, 1.0);
uniform float mid_point : hint_range(0.0, 1.0) = 0.45;
uniform float line_point : hint_range(0.0, 1.0) = 0.15;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float g = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 c;
	if (g < mid_point) {
		c = mix(color_dark.rgb, color_mid.rgb, smoothstep(line_point, mid_point, g));
	} else {
		c = mix(color_mid.rgb, color_light.rgb, smoothstep(mid_point, 1.0, g));
	}
	COLOR = vec4(c, tex.a * COLOR.a);
}


