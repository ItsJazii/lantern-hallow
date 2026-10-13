shader_type spatial;
render_mode cull_disabled;
// Tripo foliage with gentle wind: the whole plant leans with a slow gust that
// travels across the garden, and leaves add a small quick flutter near the top.
// Material inputs mirror the imported StandardMaterial3D.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool has_albedo = true;
uniform bool has_normal = false;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float roughness = 0.85;
uniform float sway = 0.08;
uniform float flutter = 0.02;
uniform float speed = 1.2;
uniform float height = 1.0;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float h = clamp(VERTEX.y / height, 0.0, 1.0);
	h = h * h;
	float gust = 0.6 + 0.4 * sin(TIME * 0.31 + origin.x * 0.05);
	float t = TIME * speed + origin.x * 0.35 + origin.z * 0.27;
	vec3 lean = vec3(sin(t), 0.0, cos(t * 0.83)) * sway * gust;
	vec3 leaf = vec3(sin(t * 3.7 + VERTEX.x * 3.0 + VERTEX.y * 2.0), 0.0, sin(t * 3.1 + VERTEX.z * 3.0)) * flutter;
	VERTEX += (lean + leaf) * h * height;
}

void fragment() {
	vec4 c = albedo_color;
	if (has_albedo) {
		c *= texture(albedo_tex, UV);
	}
	ALBEDO = c.rgb;
	if (has_normal) {
		NORMAL_MAP = texture(normal_tex, UV).rgb;
	}
	ROUGHNESS = roughness;
	SPECULAR = 0.3;
}
