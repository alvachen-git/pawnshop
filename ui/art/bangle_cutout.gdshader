shader_type canvas_item;
void fragment(){vec4 t=texture(TEXTURE,UV);t.a*=smoothstep(.22,.37,t.r);COLOR=t;}
