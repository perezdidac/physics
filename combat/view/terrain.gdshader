// Per-frame terrain shader: composes the baked back wall and front colour layers (TerrainBaker) under the solidity mask.
// All the expensive colour work (noise, strata, turf, scorch) happens once in terrain/terrain_bake.gdshader.
// The solid / air boundary is the 0.5 contour of a blurred copy of the mask (G channel of mask_tex), so the stair steps of the
// sim mask become smooth slopes and the corners rounded. Collision is untouched (it reads the sim mask).
// Pixels owned by a stamp drawn as a sprite (struct_tex, see TerrainOverlay) are hidden here: the sprite replaces them.
// World-space values are highp: phones may default to mediump, which cannot address a 3200 px wide terrain.
shader_type canvas_item;

uniform highp sampler2D mask_tex : filter_linear, repeat_disable;
uniform highp sampler2D struct_tex : filter_linear, repeat_disable;
// Front colours are fully opaque, so linear filtering only softens the 1 px stair steps of the baked turf / soil bands.
uniform highp sampler2D front_tex : filter_linear, repeat_disable;
// The back wall has alpha 0 outside its silhouette (rgb 0 there), so linear filtering gives premultiplied colours: un-premultiplied below.
uniform highp sampler2D back_tex : filter_linear, repeat_disable;
uniform highp vec2 persp = vec2(0.0, -9.0);
uniform highp vec2 terrain_size = vec2(3200.0, 820.0);

varying highp vec2 wpos;

void vertex() {
	wpos = VERTEX;
}

// Smoothed solidity (0..1): channel G of the mask texture, a 7 px wide tent blur of the sim mask baked by terrain_copy.gdshader.
float solid_field(highp vec2 p) {
	return texture(mask_tex, p / terrain_size).g;
}

// Back rock wall at the shifted point bp: same 4 tap blur and contour as the front, colour un-premultiplied.
vec4 back_wall(highp vec2 bp) {
	if (bp.x < 0.0 || bp.y < 0.0 || bp.x >= terrain_size.x || bp.y >= terrain_size.y) {
		return vec4(0.0);
	}
	highp vec2 px = 1.0 / terrain_size;
	const float r = 1.25;
	vec4 s = texture(back_tex, (bp + vec2(r, r)) * px)
		+ texture(back_tex, (bp + vec2(-r, r)) * px)
		+ texture(back_tex, (bp + vec2(r, -r)) * px)
		+ texture(back_tex, (bp + vec2(-r, -r)) * px);
	s *= 0.25;
	return vec4(s.rgb / max(s.a, 0.001), smoothstep(0.3, 0.7, s.a));
}

void fragment() {
	highp vec2 p = wpos;
	vec4 result = vec4(0.0);

	// Front layer (derivative taken outside the branch).
	float f = solid_field(p);
	float w = clamp(fwidth(f) * 0.75, 0.06, 0.35);
	float a = 0.0;
	vec3 fc = vec3(0.0);
	if (p.x >= 0.0 && p.y >= 0.0 && p.x < terrain_size.x && p.y < terrain_size.y) {
		highp vec2 uv = p / terrain_size;
		a = smoothstep(0.46 - w, 0.46 + w, f);
		a *= 1.0 - smoothstep(0.3, 0.7, texture(struct_tex, uv).r);
		fc = texture(front_tex, uv).rgb;
	}
	// Back rock wall (shifted for the fake 2.5D extrusion), only where the front does not cover it completely.
	if (a < 0.99) {
		result = back_wall(p - persp);
	}
	if (a > 0.0) {
		float oa = a + result.a * (1.0 - a);
		result = vec4((fc * a + result.rgb * result.a * (1.0 - a)) / max(oa, 0.001), oa);
	}
	COLOR = result;
}
