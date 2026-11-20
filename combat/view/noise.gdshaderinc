// Port of the JS value noise (world.js noise2D / fbm) for the terrain and cloud shaders.
// The 256-entry permutation table comes from the view as a 256x1 R8 texture (see ViewNoise.perm_image()).
uniform sampler2D perm_tex : filter_nearest, repeat_disable;

float P(int i) {
	return round(texelFetch(perm_tex, ivec2(i & 255, 0), 0).r * 255.0);
}

float fade(float t) {
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

float grad2(float hv, float x, float y) {
	int h = int(hv) & 7;
	float u = h < 4 ? x : y;
	float v = h < 4 ? y : x;
	return (((h & 1) != 0) ? -u : u) + (((h & 2) != 0) ? -2.0 * v : 2.0 * v);
}

float noise2d(float x, float y) {
	float fx = floor(x);
	float fy = floor(y);
	int xi = int(fx) & 255;
	int yi = int(fy) & 255;
	x -= fx;
	y -= fy;
	float u = fade(x);
	float v = fade(y);
	int a = int(P(xi)) + yi;
	int b = int(P(xi + 1)) + yi;
	return mix(
		mix(grad2(P(a), x, y), grad2(P(b), x - 1.0, y), u),
		mix(grad2(P(a + 1), x, y - 1.0), grad2(P(b + 1), x - 1.0, y - 1.0), u),
		v) * 0.5 + 0.5;
}

float fbm(float x, float y, int octaves) {
	float val = 0.0;
	float amp = 0.5;
	float freq = 1.0;
	float mx = 0.0;
	for (int i = 0; i < 5; i++) {
		if (i >= octaves) {
			break;
		}
		val += noise2d(x * freq, y * freq) * amp;
		mx += amp;
		freq *= 2.04;
		amp *= 0.5;
	}
	return val / mx;
}
