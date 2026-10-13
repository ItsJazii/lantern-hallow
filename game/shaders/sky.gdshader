shader_type sky;
// Blue-hour sky: navy zenith, softer teal-blue horizon, sparse twinkling stars,
// and a moon disk at the directional light's position.

uniform vec4 zenith : source_color = vec4(0.035, 0.07, 0.16, 1.0);
uniform vec4 horizon : source_color = vec4(0.16, 0.27, 0.42, 1.0);
uniform vec4 glow : source_color = vec4(0.30, 0.36, 0.55, 1.0);
uniform vec4 ground : source_color = vec4(0.04, 0.07, 0.1, 1.0);
uniform vec4 moon_color : source_color = vec4(1.0, 0.96, 0.86, 1.0);
uniform float star_density = 0.986;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	vec3 d = EYEDIR;
	float y = d.y;
	vec3 col = mix(horizon.rgb, zenith.rgb, smoothstep(0.0, 0.6, y));
	col = mix(col, glow.rgb, smoothstep(0.18, 0.0, abs(y)) * 0.45);
	col = mix(col, ground.rgb, smoothstep(0.0, -0.12, y));

	if (!AT_CUBEMAP_PASS) {
		vec3 sp = d * 240.0;
		vec3 cell = floor(sp);
		vec3 fr = fract(sp) - 0.5;
		float h = hash(cell);
		float star = step(star_density, h) * smoothstep(0.22, 0.0, length(fr)) * smoothstep(0.04, 0.3, y);
		float twinkle = 0.65 + 0.35 * sin(TIME * (1.5 + h * 2.0) + h * 80.0);
		col += vec3(0.88, 0.92, 1.0) * star * twinkle * 1.4;
	}

	vec3 md = normalize(LIGHT0_DIRECTION);
	float m = dot(d, md);
	float disk = smoothstep(0.99955, 0.99975, m);
	col += moon_color.rgb * disk * 5.0;
	col += vec3(0.45, 0.55, 0.85) * (pow(max(m, 0.0), 600.0) * 0.6 + pow(max(m, 0.0), 14.0) * 0.07);
	COLOR = col;
}
