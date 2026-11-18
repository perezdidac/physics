// Tiled cumulus / mist veil of the sky (port of world.js renderCloudLayer, evaluated on the GPU instead of a baked bitmap).
shader_type canvas_item;
#include "res://combat/view/noise.gdshaderinc"

uniform float tile_w = 1600.0;
uniform float tile_h = 320.0;
uniform float base_ox = 0.0;
uniform float top_y = 0.0;
uniform float veil_alpha = 0.34;

varying vec2 spos;

void vertex() {
	spos = VERTEX;
}

void fragment() {
	float u01 = mod(spos.x - base_ox, tile_w) / tile_w;
	float ty = (spos.y - top_y) / tile_h * 320.0;
	float vy = ty / 320.0;
	float env = sin(vy * 3.14159265);
	float angle = u01 * 6.2831853;
	float u = cos(angle) * 1.6 + 5.0;
	float n = fbm(u, ty * 0.012, 5) * env;
	vec4 col = vec4(0.0);
	if (n > 0.36 && vy >= 0.0 && vy <= 1.0) {
		float density = min(1.0, (n - 0.36) * 2.6);
		float n_above = fbm(u, (ty - 6.0) * 0.012, 4) * env;
		float rim = clamp((n - n_above) * 4.5 + 0.65, 0.0, 1.0);
		vec3 rgb = mix(vec3(165.0, 155.0, 150.0), vec3(252.0, 234.0, 214.0), rim) / 255.0;
		col = vec4(rgb, floor(density * 135.0) / 255.0 * veil_alpha);
	}
	COLOR = col;
}
