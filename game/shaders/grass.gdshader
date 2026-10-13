shader_type spatial;
render_mode cull_disabled;
// Stylized grass tufts: blade color comes from vertex color (dark root to
// light tip), lit from behind with a little translucency, swaying in the same
// wind as the rest of the foliage. Tips fade into the ground color far away.

// Close to the ground colour, so tufts read as texture, not dark stubble.
uniform vec4 root_color : source_color = vec4(0.24, 0.35, 0.21, 1.0);
uniform vec4 tip_color : source_color = vec4(0.44, 0.55, 0.31, 1.0);
uniform float sway = 0.07;
uniform float speed = 1.4;

varying float tip;

void vertex() {
	tip = UV.y;  // 0 at the root, 1 at the blade tip
	vec3 origin = MODEL_MATRIX[3].xyz;
	float t = TIME * speed + origin.x * 0.35 + origin.z * 0.27;
	float gust = 0.6 + 0.4 * sin(TIME * 0.31 + origin.x * 0.05);
	float h = tip * tip;
	VERTEX.x += sin(t + VERTEX.z * 2.0) * sway * gust * h;
	VERTEX.z += cos(t * 0.83 + VERTEX.x * 2.0) * sway * 0.6 * gust * h;
}

void fragment() {
	vec3 c = mix(root_color.rgb, tip_color.rgb, tip);
	// Per-tuft color variation from the instance color.
	c *= COLOR.rgb;
	ALBEDO = c;
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
	BACKLIGHT = c * 0.35;
	AO = mix(0.8, 1.0, tip);
	AO_LIGHT_AFFECT = 0.6;
}
