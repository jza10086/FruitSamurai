shader_type spatial;
render_mode cull_disabled;
uniform sampler2D palette : source_color, filter_linear;
uniform int fruit_kind = 0;
uniform mat4 model_from_mesh;
varying vec3 fruit_point;
void vertex() {
 fruit_point = (model_from_mesh * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
 vec3 color = texture(palette, UV).rgb;
 // Soft chroma masks also cover the kit's cyan highlights, avoiding threshold seams.
 float green = smoothstep(0.01, 0.09, color.g - color.r) * smoothstep(0.0, 0.08, color.g - color.b * 0.62);
 if (fruit_kind == 3) {
  float angle = atan(fruit_point.z, fruit_point.x);
  float stripe = smoothstep(-0.45, 0.45, sin(angle * 10.0 + sin(fruit_point.y * 37.0) * 0.22));
  vec3 rind = mix(vec3(0.065,0.17,0.055), vec3(0.23,0.36,0.105), stripe);
  color = mix(color, rind * (0.8 + 0.3 * color.g), green);
 } else if (fruit_kind == 1) {
  color = mix(color, vec3(0.38,0.47,0.11) * (0.85 + 0.25 * color.g), green);
 } else {
  color = mix(color, vec3(0.08,0.20,0.06), green);
 }
 if (fruit_kind == 2) {
  color *= vec3(0.90,0.86,0.72);
 }
 if (fruit_kind == 0) {
  float red = smoothstep(0.08, 0.25, color.r - color.g);
  color = mix(color, color * vec3(0.85,0.64,0.64), red);
 }
 ALBEDO = color;
 ROUGHNESS = 0.86;
 SPECULAR = 0.12;
}
