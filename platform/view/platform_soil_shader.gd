## Shader code of the DIG-mode soil: a cross-section with depth layers, pebbles, rock, roots and carved galleries read from a mask
## texture (red = air, green = rock, blue = root; one texel per 4 px cell, bilinear so the walls come out smooth and a little rough
## from noise), plus the flood water that fills the galleries.
class_name PlatformSoilShader
extends RefCounted

const CODE: String = """
shader_type canvas_item;
render_mode blend_mix;

uniform sampler2D mask : filter_linear, repeat_disable;
uniform vec2 world_size = vec2(1024.0, 1024.0);
uniform float surface_y = 120.0;
uniform float water_y = 100000.0;
uniform float time = 0.0;

varying vec2 wpos;

void vertex() {
	wpos = VERTEX;
}

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// soil colour of the layer at `d` px under the surface (layer borders are wavy)
vec3 layer_color(float d, float x) {
	float wob = 9.0 * sin(x * 0.012) + 5.0 * sin(x * 0.031 + 1.7);
	float dd = d + wob;
	vec3 humus = vec3(0.24, 0.16, 0.10);
	vec3 loam = vec3(0.40, 0.27, 0.16);
	vec3 clay = vec3(0.55, 0.33, 0.19);
	vec3 gravel = vec3(0.36, 0.31, 0.27);
	vec3 deep = vec3(0.27, 0.22, 0.20);
	vec3 c = humus;
	c = mix(c, loam, smoothstep(40.0, 46.0, dd));
	c = mix(c, clay, smoothstep(260.0, 268.0, dd));
	c = mix(c, gravel, smoothstep(560.0, 568.0, dd));
	c = mix(c, deep, smoothstep(900.0, 910.0, dd));
	// thin dark seams where the layers meet
	float seam = 0.0;
	seam += 1.0 - smoothstep(0.0, 2.2, abs(dd - 43.0));
	seam += 1.0 - smoothstep(0.0, 2.2, abs(dd - 264.0));
	seam += 1.0 - smoothstep(0.0, 2.2, abs(dd - 564.0));
	seam += 1.0 - smoothstep(0.0, 2.2, abs(dd - 905.0));
	return c * (1.0 - 0.28 * clamp(seam, 0.0, 1.0));
}

// mask sampled with a small cross blur (radius `r` px) so walls are rounded and corners soft
vec3 msample(vec2 p, float r) {
	vec3 c = texture(mask, p / world_size).rgb * 2.0;
	c += texture(mask, (p + vec2(r, 0.0)) / world_size).rgb;
	c += texture(mask, (p - vec2(r, 0.0)) / world_size).rgb;
	c += texture(mask, (p + vec2(0.0, r)) / world_size).rgb;
	c += texture(mask, (p - vec2(0.0, r)) / world_size).rgb;
	return c / 6.0;
}

void fragment() {
	float surf = surface_y;
	if (wpos.y < surf) {
		COLOR = vec4(0.0);
	} else {
		float depth = wpos.y - surf;
		vec3 mk = msample(wpos, 5.0);
		vec3 wide = msample(wpos, 14.0);
		float rough = (vnoise(wpos * 0.11) - 0.5) * 0.36 + (vnoise(wpos * 0.31) - 0.5) * 0.16 + (hash(floor(wpos / 2.0)) - 0.5) * 0.05;
		float m = mk.r;
		float air = smoothstep(0.44, 0.56, m + rough);
		// soil: layer colour, grain and pebbles
		vec3 soil = layer_color(depth, wpos.x);
		float grain = hash(floor(wpos / 2.0)) - 0.5;
		float blot = vnoise(wpos * 0.05) - 0.5;
		soil *= 1.0 + grain * 0.16 + blot * 0.3;
		float pb = hash(floor(wpos / 11.0));
		vec2 pc = (fract(wpos / 11.0) - 0.5);
		float peb = (1.0 - smoothstep(0.22, 0.30, length(pc * vec2(1.0, 1.2)))) * step(0.86, pb);
		soil = mix(soil, soil * 1.45 + vec3(0.05), peb * 0.8);
		float pd = hash(floor(wpos / 17.0) + 7.0);
		vec2 pd2 = (fract(wpos / 17.0) - 0.5);
		soil = mix(soil, soil * 0.7, (1.0 - smoothstep(0.16, 0.30, length(pd2))) * step(0.93, pd) * 0.6);
		// turf: a green-brown mat at the very top
		float turf = 1.0 - smoothstep(5.0, 13.0, depth);
		soil = mix(soil, vec3(0.30, 0.38, 0.14) * (0.9 + grain * 0.3), turf);
		// light fades with depth
		soil *= mix(1.0, 0.62, clamp(depth / 1300.0, 0.0, 1.0));
		// ambient occlusion on the soil next to a gallery and a bright lip on the cut edge
		float near = smoothstep(0.04, 0.46, m);
		soil *= 1.0 - 0.5 * near * (1.0 - air);
		float lip = smoothstep(0.30, 0.44, m + rough) * (1.0 - smoothstep(0.44, 0.52, m + rough));
		soil += vec3(0.16, 0.11, 0.06) * lip;
		// gallery: dark, warmer near the wall, black in the middle
		float core = smoothstep(0.55, 1.0, m);
		vec3 gal = mix(vec3(0.20, 0.13, 0.09), vec3(0.055, 0.035, 0.028), core);
		gal += vec3(0.03, 0.02, 0.01) * (hash(floor(wpos / 3.0)) - 0.5);
		vec3 col = mix(soil, gal, air);
		// rock: grey stone with cracks, dark rim
		float rk = smoothstep(0.44, 0.56, mk.g + rough);
		if (rk > 0.0) {
			float rn = vnoise(wpos * 0.07) * 0.6 + vnoise(wpos * 0.21) * 0.4;
			vec3 stone = mix(vec3(0.34, 0.33, 0.31), vec3(0.58, 0.56, 0.52), rn);
			stone *= 1.0 + (hash(floor(wpos / 2.0)) - 0.5) * 0.1;
			float crack = 1.0 - smoothstep(0.0, 0.035, abs(vnoise(wpos * 0.05 + 3.0) - 0.5));
			stone *= 1.0 - 0.45 * crack;
			stone *= mix(1.0, 0.62, clamp(depth / 1300.0, 0.0, 1.0));
			float rim = smoothstep(0.5, 0.8, wide.g);
			stone *= mix(0.6, 1.05, rim);
			col = mix(col, stone, rk);
		}
		// roots: warm wood with fibres
		float rt = smoothstep(0.44, 0.56, mk.b + rough);
		if (rt > 0.0) {
			// fibres run along the bar: the blurred mask's gradient tells which way it lies
			float gx = msample(wpos + vec2(24.0, 0.0), 6.0).b - msample(wpos - vec2(24.0, 0.0), 6.0).b;
			float gy = msample(wpos + vec2(0.0, 24.0), 6.0).b - msample(wpos - vec2(0.0, 24.0), 6.0).b;
			float horiz = smoothstep(-0.15, 0.15, abs(gy) - abs(gx));
			vec2 fp = mix(vec2(wpos.x * 0.7, wpos.y * 0.07), vec2(wpos.x * 0.07, wpos.y * 0.7), horiz);
			float fib = vnoise(fp + vnoise(wpos * 0.05) * 3.0) * 0.6 + vnoise(fp * 2.3) * 0.4;
			vec3 wood = mix(vec3(0.30, 0.18, 0.09), vec3(0.58, 0.39, 0.20), fib);
			float rrim = smoothstep(0.5, 0.78, wide.b);
			wood *= mix(0.45, 1.1, rrim);
			wood *= mix(1.0, 0.7, clamp(depth / 1300.0, 0.0, 1.0));
			col = mix(col, wood, rt);
		}
		// flood water in the galleries
		float wsurf = water_y + 2.0 * sin(wpos.x * 0.08 + time * 2.2) + 1.2 * sin(wpos.x * 0.21 - time * 3.1);
		if (wpos.y > wsurf && air > 0.01) {
			float wd = wpos.y - wsurf;
			vec3 wc = mix(vec3(0.28, 0.52, 0.70), vec3(0.06, 0.18, 0.32), clamp(wd / 90.0, 0.0, 1.0));
			float caustic = sin(wpos.x * 0.11 + time * 1.7 + sin(wpos.y * 0.09 + time)) * sin(wpos.y * 0.13 - time * 1.3 + wpos.x * 0.03);
			wc += vec3(0.10, 0.14, 0.14) * smoothstep(0.55, 1.0, caustic) * (1.0 - clamp(wd / 70.0, 0.0, 1.0));
			col = mix(col, wc, 0.72 * air);
			// a bright shimmering line right under the surface
			float shim = 1.0 - smoothstep(0.0, 3.0, wd);
			col += vec3(0.55, 0.7, 0.75) * shim * air * (0.55 + 0.45 * sin(wpos.x * 0.3 + time * 5.0));
		} else if (wpos.y > wsurf - 3.0 && air > 0.01) {
			col += vec3(0.4, 0.55, 0.6) * air * 0.35 * (1.0 - clamp((wsurf - wpos.y) / 3.0, 0.0, 1.0)) * step(wsurf - 3.0, wpos.y);
		}
		COLOR = vec4(col, 1.0);
	}
}
"""
