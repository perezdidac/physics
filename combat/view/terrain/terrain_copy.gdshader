// Copies mask bytes into the mask texture (red channel) replacing what is there, no blending.
shader_type canvas_item;
render_mode blend_disabled;

void fragment() {
	COLOR = vec4(texture(TEXTURE, UV).r, 0.0, 0.0, 1.0);
}
