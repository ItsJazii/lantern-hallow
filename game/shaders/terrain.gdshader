shader_type spatial;
// Garden ground. Vertex color channels come from the terrain builder:
//   R = path (packed earth), G = pond/stream bank, B = submerged bed.
// Banks are a walkable sandy shore that darkens where the water wets it; under
// the water the bed is sand and smooth pebbles, fading with depth, with soft
// moving caustics so the clear water reads as clear.

uniform vec4 grass_dark : source_color = vec4(0.22, 0.33, 0.21, 1.0);
uniform vec4 grass_light : source_color = vec4(0.42, 0.53, 0.31, 1.0);
uniform vec4 path_color : source_color = vec4(0.6, 0.48, 0.35, 1.0);
uniform vec4 path_grout : source_color = vec4(0.42, 0.35, 0.26, 1.0);  // damp patches
uniform vec4 sand_color : source_color = vec4(0.62, 0.55, 0.42, 1.0);
uniform vec4 pebble_color : source_color = vec4(0.5, 0.5, 0.47, 1.0);
uniform vec4 deep_bed : source_color = vec4(0.08, 0.17, 0.19, 1.0);
uniform float water_y = -0.3;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D cell_tex : filter_linear_mipmap, repeat_enable;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Rounded pebbles from cellular noise, each with its own tone.
vec3 pebbles(vec2 xz, vec3 base, float density, out float mask) {
	float cells = texture(cell_tex, xz * 0.9).r;
	// Smooth noise (not a grid) decides where pebbles gather and their tone.
	float id = texture(noise_tex, xz * 0.31).r;
	float keep = smoothstep(1.0 - density - 0.08, 1.0 - density + 0.08, texture(noise_tex, xz * 0.47 + vec2(0.21, 0.63)).r);
	mask = smoothstep(0.1, 0.22, cells) * keep;
	vec3 stone = pebble_color.rgb * (0.7 + id * 0.6) * mix(vec3(1.0), vec3(1.05, 0.98, 0.9), fract(id * 3.7));
	// Lit top, darker rim.
	stone *= 0.75 + 0.35 * smoothstep(0.1, 0.45, cells);
	return mix(base, stone, mask);
}

void fragment() {
	float n1 = texture(noise_tex, wpos.xz * 0.03).r;
	float n2 = texture(noise_tex, wpos.xz * 0.19).r;
	float n3 = texture(noise_tex, wpos.xz * 0.9).r;
	vec3 grass = mix(grass_dark.rgb, grass_light.rgb, smoothstep(0.2, 0.8, n1 * 0.65 + n2 * 0.35));
	grass *= 0.9 + n3 * 0.2;

	// Packed earth path (as in the concept): warm and smooth, slightly lighter
	// down the worn middle, with tiny pebbles and darker damp patches.
	float big = texture(noise_tex, wpos.xz * 0.07).r;
	vec3 path = path_color.rgb * (0.86 + big * 0.2) * (0.94 + n2 * 0.1);
	path *= mix(0.9, 1.05, smoothstep(0.55, 1.0, COLOR.r));
	float pebble = texture(noise_tex, wpos.xz * 3.3).r;
	float pebble2 = texture(noise_tex, wpos.xz * 2.1 + vec2(0.37, 0.71)).r;
	path *= 1.0 - smoothstep(0.7, 0.78, pebble) * 0.28;
	path += smoothstep(0.76, 0.84, pebble2) * vec3(0.07, 0.06, 0.05);
	path = mix(path, path_grout.rgb, smoothstep(0.62, 0.8, texture(noise_tex, wpos.xz * 0.21 + 0.3).r) * 0.25);

	// Shore: sand with scattered pebbles, wet and darker near the waterline.
	float pm;
	vec3 sand = sand_color.rgb * (0.88 + n2 * 0.18) * (0.95 + n3 * 0.1);
	sand = pebbles(wpos.xz, sand, 0.35, pm);
	float wet = smoothstep(water_y + 0.25, water_y + 0.02, wpos.y);
	sand *= mix(1.0, 0.62, wet);

	// Bed: sand and denser pebbles, fading into blue-green depth.
	float bm;
	vec3 bed = sand_color.rgb * 0.8 * (0.9 + n2 * 0.2);
	bed = pebbles(wpos.xz * 1.3, bed, 0.6, bm);
	float depth = clamp((water_y - wpos.y) / 1.3, 0.0, 1.0);
	bed = mix(bed * 0.85, deep_bed.rgb, smoothstep(0.05, 1.0, depth));
	float c1 = texture(noise_tex, wpos.xz * 0.55 + vec2(TIME * 0.03, TIME * 0.018)).r;
	float c2 = texture(noise_tex, wpos.xz * 0.62 - vec2(TIME * 0.022, TIME * 0.031)).r;
	float caustic = pow(1.0 - abs(c1 - c2), 14.0) * (1.0 - depth * 0.7);

	float path_mask = smoothstep(0.4, 0.62, COLOR.r + (n2 - 0.5) * 0.3);
	float bank = smoothstep(0.0, 1.0, COLOR.g + (n2 - 0.5) * 0.25);
	vec3 col = mix(grass, sand, bank);
	col = mix(col, path, path_mask);
	float under = smoothstep(water_y + 0.02, water_y - 0.06, wpos.y);
	col = mix(col, bed, under);

	ALBEDO = col;
	EMISSION = vec3(0.55, 0.75, 0.8) * caustic * under * 0.18;
	ROUGHNESS = mix(mix(0.95, 0.88, path_mask), 0.55, max(wet * bank, under));
	SPECULAR = mix(0.3, 0.5, wet * bank);
}
