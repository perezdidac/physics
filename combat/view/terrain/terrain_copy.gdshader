// Copies mask bytes into the mask texture, replacing what is there (no blending).
//   R  the exact sim mask (0 / 1/255), read by the overlay shader and by tests
//   G  the solidity smoothed by a 3x3 bilinear tent (taps 2.6 px apart, about 7 px wide): the terrain shader draws the 0.5 contour of
//      this field, which turns stair steps into smooth slopes and rounds the corners. The sprite texture needs linear filtering and
//      must contain 4 px of margin around the drawn region (see TerrainBaker.upload_mask_rect).
shader_type canvas_item;
render_mode blend_disabled;

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	float raw = texelFetch(TEXTURE, ivec2(UV / px), 0).r;
	const float d = 2.6;
	float s = 0.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			float w = (i == 0 ? 2.0 : 1.0) * (j == 0 ? 2.0 : 1.0);
			s += w * texture(TEXTURE, UV + vec2(float(i), float(j)) * d * px).r;
		}
	}
	COLOR = vec4(raw, s * (255.0 / 16.0), 0.0, 1.0);
}
