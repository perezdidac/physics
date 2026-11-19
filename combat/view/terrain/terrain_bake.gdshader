// Bake pass of the terrain colours. Rendered into the front / back colour textures of TerrainBaker (a ColorRect per pass):
//   mode 0  front colour of every pixel (rock / soil / turf, six texture styles)      world.js generateDestructibleTerrain
//   mode 1  back rock wall (only under the natural surface)
//   mode 2  stamped structure (tree, tower, terrace, ...) fallback pixel colours over the pixels that were solid at match start
//   mode 4  structure mask of the stamps drawn as sprites (TerrainOverlay): R solid pixel of the stamp, G enclosed void
//   mode 3  crater scorch, blended over what is already baked                          world.js:1088-1099
// All formulas are the ones the per-frame terrain shader used before the bake. GL Compatibility / WebGL2 safe.
shader_type canvas_item;
#include "res://combat/view/noise.gdshaderinc"

uniform int mode = 0;
uniform vec2 origin = vec2(0.0);
uniform sampler2D surf_tex : filter_nearest, repeat_disable;
uniform sampler2D mask_src : filter_nearest, repeat_disable;
uniform vec3 turf_col = vec3(92.0, 118.0, 52.0);
uniform vec3 soil_col = vec3(134.0, 84.0, 58.0);
uniform vec3 rock_col = vec3(148.0, 128.0, 122.0);
uniform float map_seed = 2.4;
uniform int tex_style = 0;
// Stamp pass: x, y, scale, crown_y of the stamp; box top y, box end y, rows allowed under the natural surface; kind id and
// tree style (see TerrainStamps).
uniform vec4 stamp = vec4(0.0);
uniform vec3 stamp_box = vec3(0.0, 0.0, 0.0);
uniform ivec2 stamp_kind = ivec2(0);
// Structure pass: enclosed void kind (TerrainStamps.hollow_id: 1 tower chamber, 2 barraca door, 3 log tube) and the log's tilt / half length.
uniform int stamp_hollow = 0;
uniform vec2 stamp_extra = vec2(0.0);
// Scorch pass: crater centre and radius.
uniform vec3 crater = vec3(0.0);

varying vec2 wpos;

void vertex() {
	wpos = VERTEX + origin;
}

float ridged2(float x, float y) {
	float val = 0.0;
	float amp = 0.5;
	float freq = 1.0;
	float weight = 1.0;
	float mx = 0.0;
	for (int i = 0; i < 2; i++) {
		float n = 1.0 - abs(noise2d(x * freq, y * freq) * 2.0 - 1.0);
		n = n * n * weight;
		weight = clamp(n * 2.0, 0.0, 1.0);
		val += n * amp;
		mx += amp;
		freq *= 2.12;
		amp *= 0.5;
	}
	return val / mx;
}

float surf(int x) {
	return texelFetch(surf_tex, ivec2(clamp(x, 0, 3199), 0), 0).r;
}

// Running-bond masonry: returns a brightness factor (mortar joints, per-brick tone). Replaces the JS two-tone checkerboard,
// which read as a failed texture. Integer hash only (no sin/fract), so it is identical on every GPU.
float masonry(int ix, int iy, int bw, int bh, float contrast) {
	int row = iy / bh;
	int off = (row & 1) * (bw / 2);
	int bx = (ix + off) % bw;
	int by = iy % bh;
	if (bx == 0 || by == 0) {
		return 0.78;
	}
	int col = (ix + off) / bw;
	float tone = float(((row * 13 + col * 7 + (row ^ col) * 3) & 7)) / 7.0 - 0.5;
	return 1.0 + tone * contrast;
}

// Rock texture of the pixel: returns rockVal, outputs texMod and n1.
float rock_tex(float x, float y, out float tex_mod, out float n1) {
	n1 = fbm(x * 0.014 + map_seed, y * 0.014, 3);
	float n2 = ridged2(x * 0.028, y * 0.028);
	float strata = 0.0;
	tex_mod = 0.0;
	if (tex_style == 1) {
		float col_phase = abs(mod(x + sin(y * 0.02) * 4.0, 18.0) - 9.0) / 9.0;
		float joint = abs(mod(y + floor(x / 18.0) * 11.0, 34.0) - 17.0) < 1.6 ? -18.0 : 0.0;
		strata = col_phase;
		tex_mod = (col_phase > 0.78 ? -16.0 : (col_phase < 0.25 ? 12.0 : 0.0)) + joint;
	} else if (tex_style == 2) {
		float row = floor(y / 16.0);
		float shift = mod(row, 2.0) * 19.0;
		float bx = mod(x + shift, 38.0);
		float by = mod(y, 16.0);
		bool mortar = bx < 1.8 || by < 1.6;
		float hash = float((int(row * 13.0 + floor((x + shift) / 38.0) * 7.0)) & 7) - 3.5;
		strata = mortar ? 0.15 : 0.65;
		tex_mod = mortar ? -22.0 : hash * 4.5;
	} else if (tex_style == 3) {
		float cx = (x + sin(y * 0.05) * 6.0) * 0.085;
		float cy = y * 0.085;
		float peb = sin(cx * 3.14159265) * sin(cy * 3.14159265);
		strata = peb * 0.5 + 0.5;
		tex_mod = peb > 0.45 ? 16.0 : (peb < -0.45 ? -14.0 : 0.0);
	} else if (tex_style == 4) {
		float diag = sin(x * 0.09 + y * 0.14 + n2 * 3.8);
		strata = diag * 0.5 + 0.5;
		tex_mod = diag > 0.65 ? 15.0 : (diag < -0.68 ? -18.0 : 0.0);
	} else if (tex_style == 5) {
		float ripple = sin(y * 0.14 + sin(x * 0.025 + map_seed) * 3.2);
		strata = ripple * 0.5 + 0.5;
		tex_mod = ripple * 14.0;
	} else {
		strata = sin(y * 0.075 + n1 * 4.2 + cos(x * 0.008) * 1.5) * 0.5 + 0.5;
		tex_mod = strata > 0.72 ? 12.0 : (strata < 0.25 ? -8.0 : 0.0);
	}
	return n1 * 0.55 + n2 * 0.22 + strata * 0.23;
}

vec3 front_color(int ix, int iy) {
	float x = float(ix);
	float y = float(iy);
	float tex_mod;
	float n1;
	float rock_val = rock_tex(x, y, tex_mod, n1);
	// Band boundaries use the unrounded surface height and soft transitions (about 1 px wide), so the turf / soil / rock bands are
	// anti-aliased instead of following the 1 px stair steps of the pixel grid.
	float sy = surf(ix);
	float slope = (surf(ix + 3) - surf(ix - 3)) / 6.0;
	// Air next to the surface (the smoothed terrain contour reaches into it) borrows the depth of the highest neighbouring column, so a flat
	// top keeps its turf rim and a cliff face keeps its soil / rock colour.
	if (y + 0.5 < sy) {
		sy = min(sy, min(min(surf(ix - 1), surf(ix + 1)), min(surf(ix - 2), surf(ix + 2))));
	}
	float depth = max(y + 0.5 - sy, 0.0);
	float tuft = sin(x * 0.22 + n1 * 6.0) * 2.2 + cos(x * 0.09) * 1.6;
	float grass = max(5.0, 14.0 - abs(slope) * 2.8 + tuft);
	float light = clamp(0.88 - slope * 0.18 + (n1 - 0.5) * 0.18, 0.54, 1.24);
	vec3 c_turf = clamp(turf_col * light, 24.0, 255.0);
	float rim = clamp(1.32 - slope * 0.16 - depth * 0.09, 1.02, 1.48);
	c_turf = mix(c_turf, clamp(c_turf * rim + vec3(22.0, 24.0, 12.0), 0.0, 255.0), 1.0 - smoothstep(1.5, 2.5, depth));
	c_turf = mix(c_turf, c_turf * vec3(0.76, 0.78, 0.76), smoothstep(grass - 1.6, grass - 0.4, depth));
	float ao = mix(0.74, 0.88, smoothstep(grass + 3.3, grass + 4.7, depth));
	vec3 c_soil = soil_col * ((0.78 + rock_val * 0.36) * ao);
	float fade_d = clamp(1.0 - (depth - 20.0) * 0.0009, 0.72, 1.0);
	float shade = clamp(0.92 - slope * 0.14, 0.62, 1.14) * fade_d;
	vec3 c_rock = vec3(rock_col.r + rock_val * 48.0 + tex_mod, rock_col.g + rock_val * 45.0 + tex_mod, rock_col.b + rock_val * 49.0 + tex_mod * 1.1) * shade;
	vec3 c = mix(mix(c_turf, c_soil, smoothstep(grass - 0.7, grass + 0.7, depth)), c_rock, smoothstep(grass + 15.3, grass + 16.7, depth));
	return clamp(c, 0.0, 255.0) / 255.0;
}

bool solid_at(int x, int y) {
	return texelFetch(mask_src, ivec2(x, y), 0).r > 0.0;
}

// Colour of a stamped structure pixel. kid: 0 tree, 1 terrace, 2 log, 3 monolith, 4 arch, 5 barraca, 6 truss, 7 viaduct, 8 stone.
vec3 stamp_color(int kid, int tree_style, int ix, int iy, int run_depth) {
	float x = float(ix);
	float y = float(iy);
	float n = noise2d(x * 0.12, y * 0.12);
	vec3 c;
	if (kid == 0) {
		float sc = stamp.z;
		float crown_y = stamp.w;
		if (abs(x - stamp.x) <= 7.0 * sc && y > crown_y + 22.0 * sc) {
			float bark = 0.8 + noise2d(x * 0.25, y * 0.15) * 0.4;
			c = vec3(82.0, 54.0, 36.0) * bark;
		} else {
			float shade = clamp(0.75 - (y - crown_y) * 0.014 + (noise2d(x * 0.2, y * 0.2) - 0.5) * 0.3, 0.45, 1.25);
			if (tree_style == 1) {
				c = vec3(38.0, 88.0, 56.0) * shade;
			} else if (tree_style == 2) {
				c = vec3(74.0, 118.0, 46.0) * shade;
			} else if (tree_style == 3) {
				c = vec3(52.0, 86.0, 50.0) * shade;
			} else {
				c = vec3(62.0, 104.0, 44.0) * shade;
			}
		}
	} else if (kid == 1) {
		if (run_depth <= 6) {
			float sun = run_depth <= 2 ? 1.28 : 0.96;
			c = turf_col * sun + (run_depth <= 1 ? vec3(18.0, 20.0, 10.0) : vec3(0.0));
		} else {
			c = (rock_col + vec3(24.0, 20.0, 16.0) + vec3(n * 24.0)) * masonry(ix, iy, 13, 6, 0.16);
		}
	} else if (kid == 2) {
		c = vec3(92.0, 58.0, 36.0) * (0.78 + n * 0.35);
	} else if (kid == 3) {
		c = vec3(128.0, 124.0, 118.0) + vec3(n * 28.0);
	} else if (kid == 4) {
		c = rock_col + vec3(n * 35.0);
	} else if (kid == 5) {
		if (y >= stamp.y - 30.0) {
			c = vec3(236.0, 230.0, 216.0) + vec3((n - 0.5) * 18.0);
		} else {
			c = vec3(158.0, 124.0, 74.0) * (((ix + iy) % 4) == 0 ? 1.08 : 0.92);
		}
	} else if (kid == 6) {
		c = vec3(102.0, 114.0, 124.0);
	} else if (kid == 7) {
		c = vec3(162.0, 126.0, 92.0) * masonry(ix, iy, 18, 9, 0.16) + vec3(n * 26.0);
	} else {
		c = (vec3(148.0, 132.0, 114.0) + vec3(n * 24.0)) * masonry(ix, iy, 14, 8, 0.16);
	}
	return clamp(c, 0.0, 255.0) / 255.0;
}

// Enclosed void of the stamp at pixel (ix, iy) (mirrors the sim's clear loops in terrain_sim.gd).
bool hollow_at(int ix, int iy) {
	int cx = int(stamp.x);
	int sy = int(stamp.y);
	if (stamp_hollow == 1) {
		return abs(ix - cx) <= 18 && iy >= sy - 52 && iy <= sy - 16;
	} else if (stamp_hollow == 2) {
		return abs(ix - cx) <= 12 && iy >= sy - 22 && iy <= sy - 2;
	} else if (stamp_hollow == 3) {
		int dx = ix - cx;
		int yc = int(floor(stamp.y - 14.0 + float(dx) * stamp_extra.x));
		return abs(dx) <= int(stamp_extra.y) && abs(iy - yc) <= 8;
	}
	return false;
}

vec4 scorch_color(vec2 p) {
	float d = length(p - crater.xy);
	float rin = max(2.0, crater.z - 3.0);
	float rout = crater.z + 18.0;
	if (d >= rout) {
		discard;
	}
	float t = clamp((d - rin) / (rout - rin), 0.0, 1.0);
	vec4 s0 = vec4(24.0, 18.0, 15.0, 0.85);
	vec4 s1 = vec4(92.0, 48.0, 26.0, 0.52);
	vec4 s2 = vec4(42.0, 30.0, 22.0, 0.25);
	vec4 s3 = vec4(32.0, 24.0, 18.0, 0.0);
	vec4 s;
	if (t < 0.35) {
		s = mix(s0, s1, t / 0.35);
	} else if (t < 0.7) {
		s = mix(s1, s2, (t - 0.35) / 0.35);
	} else {
		s = mix(s2, s3, (t - 0.7) / 0.3);
	}
	return vec4(s.rgb / 255.0, s.a);
}

void fragment() {
	ivec2 ip = ivec2(floor(wpos));
	if (mode == 0) {
		COLOR = vec4(front_color(ip.x, ip.y), 1.0);
	} else if (mode == 1) {
		if (float(ip.y) < floor(surf(ip.x))) {
			discard;
		}
		float tm;
		float n1;
		float rv = rock_tex(float(ip.x), float(ip.y), tm, n1);
		vec3 b = (rock_col * 0.48 + vec3(rv * 22.0, rv * 20.0, rv * 24.0)) / 255.0;
		COLOR = vec4(clamp(b, 0.0, 1.0), 1.0);
	} else if (mode == 2) {
		int ymax = min(int(stamp_box.y), int(surf(ip.x)) + int(stamp_box.z));
		if (ip.y >= ymax || !solid_at(ip.x, ip.y)) {
			discard;
		}
		int run_depth = 0;
		for (int i = 1; i <= 8; i++) {
			if (float(ip.y - i) < stamp_box.x || !solid_at(ip.x, ip.y - i)) {
				break;
			}
			run_depth = i;
		}
		vec3 sc = stamp_color(stamp_kind.x, stamp_kind.y, ip.x, ip.y, run_depth);
		COLOR = vec4(sc, 1.0);
	} else if (mode == 4) {
		int ymax = min(int(stamp_box.y), int(surf(ip.x)) + int(stamp_box.z));
		if (ip.y < ymax && solid_at(ip.x, ip.y)) {
			COLOR = vec4(1.0, 0.0, 0.0, 1.0);
		} else if (hollow_at(ip.x, ip.y) && !solid_at(ip.x, ip.y)) {
			COLOR = vec4(0.0, 1.0, 0.0, 1.0);
		} else {
			discard;
		}
	} else {
		COLOR = scorch_color(vec2(ip) + vec2(0.5));
	}
}
