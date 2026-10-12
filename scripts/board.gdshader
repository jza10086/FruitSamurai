shader_type spatial;
render_mode unshaded;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void fragment(){
 vec2 uv=UV;
 float plank=floor(uv.x*10.0);
 float seam=smoothstep(0.004,0.012,abs(fract(uv.x*10.0)-0.5));
 float grain=sin(uv.y*900.0+sin(uv.y*17.0+plank)*3.0+sin(uv.x*100.0)*3.0)*0.004;
 float noise=hash(floor(uv*900.0))*0.004;
 vec3 base=mix(vec3(0.035,0.080,0.073),vec3(0.073,0.126,0.110),hash(vec2(plank,0.0)));
 float vignette=1.0-smoothstep(0.25,0.8,length((uv-0.5)*vec2(1.1,1.0)));
 ALBEDO=(base+grain+noise)*mix(0.48,1.0,vignette)*mix(0.6,1.0,seam);
}
