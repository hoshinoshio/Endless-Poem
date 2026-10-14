shader_type canvas_item;
uniform float battle_time = 0.0;
void fragment() {
 vec2 uv = UV;
 // Three existing cloth banners; quantized displacement preserves pixel contours.
 bool cloth = (uv.x > .923 && uv.x < .968 && uv.y < .29) || (uv.x > .520 && uv.x < .563 && uv.y > .225 && uv.y < .37) || (uv.x > .236 && uv.x < .268 && uv.y > .24 && uv.y < .35);
 if (cloth) { uv.x += floor(sin(battle_time*1.7 + uv.y*27.0)*1.7) * TEXTURE_PIXEL_SIZE.x; }
 vec4 base = texture(TEXTURE, uv);
 vec2 lamps[7] = vec2[7](vec2(.053,.424),vec2(.383,.444),vec2(.5,.442),vec2(.622,.446),vec2(.949,.412),vec2(.032,.196),vec2(.986,.196));
 float glow = 0.0;
 for(int i=0;i<7;i++){float d=length((UV-lamps[i])*vec2(1.0,.63)); glow += max(0.0,1.0-d/.017)*(.055+.035*sin(battle_time*2.1+float(i)*1.9));}
 base.rgb += vec3(1.0,.66,.25)*glow;
 COLOR = base;
}
