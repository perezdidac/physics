// Per-frame terrain shader: composes the baked back wall and front colour layers (TerrainBaker) under the solidity mask.
// All the expensive colour work (noise, strata, turf, stamps, scorch) happens once in terrain/terrain_bake.gdshader.
shader_type canvas_item;

uniform sampler2D mask_tex : filter_linear, repeat_disable;
uniform sampler2D front_tex : filter_nearest, repeat_disable;
uniform sampler2D back_tex : filter_nearest, repeat_disable;
uniform vec2 persp = vec2(0.0, -9.0);
uniform vec2 terrain_size = vec2(3200.0, 820.0);

varying vec2 wpos;

void vertex() {
	wpos = VERTEX;
}

void fragment() {
	vec2 p = wpos;
	vec4 result = vec4(0.0);

	// Back rock wall (shifted for the fake 2.5D extrusion); alpha 0 under the sky and inside crater cuts.
	vec2 bp = p - persp;
	if (bp.x >= 0.0 && bp.y >= 0.0 && bp.x < terrain_size.x && bp.y < terrain_size.y) {
		result = texture(back_tex, bp / terrain_size);
	}

	// Front layer.
	if (p.x >= 0.0 && p.y >= 0.0 && p.x < terrain_size.x && p.y < terrain_size.y) {
		vec2 uv = p / terrain_size;
		float a = smoothstep(0.35, 0.65, texture(mask_tex, uv).r * 255.0);
		if (a > 0.0) {
			vec3 fc = texture(front_tex, uv).rgb;
			float oa = a + result.a * (1.0 - a);
			result = vec4((fc * a + result.rgb * result.a * (1.0 - a)) / max(oa, 0.001), oa);
		}
	}
	COLOR = result;
}
