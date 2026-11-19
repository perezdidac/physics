// Sprite of a structure stamped into the terrain (tree, tower, terrace, ...), drawn over the terrain with its smooth silhouette.
// The sim pixel mask only collides; this shader decides, per pixel, whether the sprite is still there by comparing the live mask
// (mask_tex) with the structure mask baked at match start (struct_tex, R = pixel owned by a stamp, G = enclosed void):
//   mask 1, struct 0  ground in front of the structure: the sprite is hidden (a trunk ends at the grass line);
//   mask 0, struct 1  carved away since the start: the sprite is cut with a soft edge and the rim near the cut is scorched;
//   inside an enclosed void (chamber, door, log tube) the sprite stays only while some wall of the stamp remains above it.
// World-space values are highp: phones may default to mediump.
shader_type canvas_item;

uniform highp sampler2D mask_tex : filter_linear, repeat_disable;
uniform highp sampler2D struct_tex : filter_linear, repeat_disable;
uniform highp vec2 terrain_size = vec2(3200.0, 820.0);

varying highp vec2 wpos;
varying vec4 vcol;

void vertex() {
	wpos = VERTEX;
	vcol = COLOR;
}

// x = live mask (0..1), y = struct mask (0..1) at world point p.
vec2 ms(highp vec2 p) {
	highp vec2 uv = p / terrain_size;
	return vec2(texture(mask_tex, uv).r * 255.0, texture(struct_tex, uv).r);
}

void fragment() {
	vec4 t = texture(TEXTURE, UV) * vcol;
	if (t.a < 0.01) {
		discard;
	}
	vec3 rgb = t.rgb;
	float alpha = 1.0;
	highp vec2 uv = wpos / terrain_size;
	if (texture(struct_tex, uv).g > 0.5) {
		float alive = 0.0;
		for (int i = 1; i <= 12; i++) {
			vec2 q = ms(wpos + vec2(0.0, -4.5 * float(i)));
			alive = max(alive, step(0.5, q.x) * step(0.5, q.y));
		}
		alpha = alive;
	} else {
		vec2 a = ms(wpos + vec2(1.0, 1.0)) + ms(wpos + vec2(-1.0, 1.0)) + ms(wpos + vec2(1.0, -1.0)) + ms(wpos + vec2(-1.0, -1.0));
		float d = (a.y - a.x) * 0.25;
		float s4 = a.y * 0.25;
		// Inside the stamp's silhouette: cut where the live mask lost the pixel. Ground in front of the stamp hides the sprite.
		float inside = 1.0 - smoothstep(0.1, 0.9, d);
		float ground = smoothstep(0.35, 0.65, -d);
		// Scorch: share of carved pixels in two rings around the point; the inner ring also tells whether the stamp pixels next to a
		// sprite pixel that sticks out of the mask (outline, puffs) are still alive.
		float ring = 0.0;
		float sum_s = 0.0;
		float sum_alive = 0.0;
		for (int i = 0; i < 6; i++) {
			float ang = 1.0471976 * float(i);
			vec2 dir = vec2(cos(ang), sin(ang));
			vec2 q3 = ms(wpos + dir * 3.0);
			vec2 q7 = ms(wpos + dir * 7.0 + vec2(0.7, 0.3));
			ring += max(q3.y - q3.x, 0.0) * 1.0 + max(q7.y - q7.x, 0.0) * 0.5;
			sum_s += q3.y;
			sum_alive += min(q3.x, q3.y);
		}
		float outside = mix(1.0, smoothstep(0.4, 0.85, sum_alive / max(sum_s, 0.001)), smoothstep(0.1, 0.4, sum_s));
		alpha = mix(outside, inside, smoothstep(0.3, 0.7, s4)) * (1.0 - ground);
		float burn = smoothstep(0.0, 0.7, ring * 0.1667);
		rgb = mix(rgb, rgb * vec3(0.34, 0.28, 0.25) + vec3(0.07, 0.03, 0.0), burn * 0.85);
	}
	COLOR = vec4(rgb, t.a * alpha);
}
