// Erases a crater disc from the back rock wall texture (world.js:1093-1097: the back layer loses radius * 0.68).
shader_type canvas_item;
render_mode blend_disabled;

uniform vec2 origin = vec2(0.0);
uniform vec3 crater = vec3(0.0);

varying vec2 wpos;

void vertex() {
	wpos = VERTEX + origin;
}

void fragment() {
	if (length(floor(wpos) + vec2(0.5) - crater.xy) >= crater.z * 0.68) {
		discard;
	}
	COLOR = vec4(0.0);
}
