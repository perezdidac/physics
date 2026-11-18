// Vertical three-stop gradient for the splash title (CSS: #fff6df -> #f3c46b at 48% -> #b8742a).
shader_type canvas_item;

uniform vec4 top_color : source_color = vec4(1.0, 0.965, 0.875, 1.0);
uniform vec4 mid_color : source_color = vec4(0.953, 0.769, 0.42, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.722, 0.455, 0.165, 1.0);
uniform float text_height = 80.0;

varying float local_y;

void vertex() {
	local_y = VERTEX.y;
}

void fragment() {
	float t = clamp(local_y / max(text_height, 1.0), 0.0, 1.0);
	vec3 c = t < 0.48 ? mix(top_color.rgb, mid_color.rgb, t / 0.48) : mix(mid_color.rgb, bottom_color.rgb, (t - 0.48) / 0.52);
	COLOR = vec4(c, COLOR.a);
}
