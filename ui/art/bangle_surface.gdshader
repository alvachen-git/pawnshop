shader_type canvas_item;
uniform float soot=0.0;
uniform float heat=0.0;
uniform float side=0.0;
void fragment(){
 vec4 tex=texture(TEXTURE,UV);
 float patch=1.0-smoothstep(.08,.42,length((UV-vec2(.5,.55))*vec2(1.0,1.5)));
 float grain=.75+.25*sin(UV.x*141.0)*cos(UV.y*137.0);
 tex.rgb*=1.0-soot*patch*grain;
 tex.rgb*=1.0+side*(UV.x-.5)*2.0;
 tex.rgb+=vec3(.3,.07,.005)*heat*patch;
 COLOR=tex;
}
