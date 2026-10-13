shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, specular_schlick_ggx;
// Crystal-clear water. Looking down you see straight through to the sand and
// pebbles (refracted by the ripples); the colour deepens only with real depth
// (from the depth buffer), turquoise in the shallows to deep blue-green in the
// middle. Reflections follow Fresnel: faint from above, strong at a glance
// across the surface. A thin bright line of wet foam traces the shore, and
// the moon and lanterns leave sharp glints on the ripples.

uniform vec4 deep : source_color = vec4(0.02, 0.13, 0.2, 1.0);
uniform vec4 shallow : source_color = vec4(0.3, 0.72, 0.7, 1.0);
uniform vec2 pond_radii = vec2(12.5, 9.5);
uniform float use_pond_depth = 1.0;
uniform vec2 flow = vec2(0.0, 0.0);
uniform float ripple_strength = 0.24;
uniform float murk_density = 0.55;
uniform float refraction = 0.03;
uniform sampler2D normal_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D reflection_tex : source_color, filter_linear;
uniform float reflection_strength = 0.55;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float view_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	// The browser renderer (OpenGL/WebGL) stores depth as 0..1, not -1..1.
	vec4 v = inv_proj * vec4(vec3(uv, d) * 2.0 - 1.0, 1.0);
#else
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
#endif
	return -v.z / v.w;
}

void fragment() {
	vec2 uv = wpos.xz;
	vec2 f = flow * TIME;
	vec3 na = texture(normal_a, uv * 0.085 + vec2(TIME * 0.011, TIME * 0.006) + f).rgb;
	vec3 nb = texture(normal_b, uv * 0.21 + vec2(-TIME * 0.009, TIME * 0.014) + f * 1.3).rgb;
	vec3 nmap = normalize(mix(na, nb, 0.45));
	NORMAL_MAP = nmap;
	NORMAL_MAP_DEPTH = ripple_strength;

	// How much water lies behind this pixel, along the view ray.
	float surface = -VERTEX.z;
	float water_depth = max(view_depth(SCREEN_UV, INV_PROJECTION_MATRIX) - surface, 0.0);
	vec2 refr_uv = SCREEN_UV + (nmap.xy - 0.5) * refraction * clamp(water_depth, 0.0, 1.0);
	// Don't refract things that sit in front of the water.
	float refr_depth = view_depth(refr_uv, INV_PROJECTION_MATRIX) - surface;
	if (refr_depth < 0.0) {
		refr_uv = SCREEN_UV;
		refr_depth = water_depth;
	}
	vec3 below = textureLod(screen_tex, refr_uv, 0.0).rgb;

	// Beer-Lambert-ish absorption: red goes first, then green.
	vec3 absorb = exp(-max(refr_depth, 0.0) * murk_density * vec3(2.2, 0.9, 0.6));
	float murk = 1.0 - exp(-max(refr_depth, 0.0) * murk_density);
	vec3 body = mix(shallow.rgb, deep.rgb, smoothstep(0.0, 1.0, murk));
	vec3 through = below * absorb + body * murk * 0.35;

	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = 0.02 + 0.98 * pow(1.0 - facing, 5.0);
	// Mirror reflection (U flipped: the mirror camera is rendered X-negated).
	vec2 ruv = vec2(1.0 - SCREEN_UV.x, SCREEN_UV.y) + (nmap.xy - 0.5) * 0.04;
	vec3 refl = texture(reflection_tex, ruv).rgb;
	float r = clamp(fres * (0.6 + reflection_strength * 0.6) + 0.06, 0.0, 0.92);

	// Wet foam line where the water thins out on the shore.
	float foam_n = texture(normal_b, uv * 0.9 + vec2(TIME * 0.02, 0.0)).r;
	float foam = smoothstep(0.09, 0.0, water_depth) * smoothstep(0.35, 0.65, foam_n) * 0.35 * use_pond_depth;

	EMISSION = mix(through, refl, r) + vec3(0.75, 0.85, 0.9) * foam * 0.25;
	ALBEDO = body * murk * (1.0 - r) * 0.25 + vec3(foam);
	ROUGHNESS = 0.03;
	METALLIC = 0.0;
	SPECULAR = 0.45;
	// Soft edge where the water meets the bank.
	ALPHA = smoothstep(0.0, 0.04, water_depth);
}
