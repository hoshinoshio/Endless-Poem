shader_type canvas_item;
uniform vec2 left_region[20];
uniform vec2 right_region[20];
uniform bool inner_lining = false;
uniform int left_count = 0;
uniform int right_count = 0;
bool inside_left(vec2 p) {
 bool c=false; int j=left_count-1;
 for(int i=0;i<20;i++){if(i>=left_count)break;vec2 a=left_region[i];vec2 b=left_region[j];if(((a.y>p.y)!=(b.y>p.y))&&(p.x<(b.x-a.x)*(p.y-a.y)/(b.y-a.y)+a.x))c=!c;j=i;}return c;
}
bool inside_right(vec2 p) {
 bool c=false; int j=right_count-1;
 for(int i=0;i<20;i++){if(i>=right_count)break;vec2 a=right_region[i];vec2 b=right_region[j];if(((a.y>p.y)!=(b.y>p.y))&&(p.x<(b.x-a.x)*(p.y-a.y)/(b.y-a.y)+a.x))c=!c;j=i;}return c;
}
void fragment(){COLOR=texture(TEXTURE,UV)*COLOR;if(inner_lining){float fold=.68+.32*sin(UV.x*1024.0*.55+UV.y*1536.0*.012);COLOR.rgb*=fold;}else{if(inside_left(UV)||inside_right(UV)||(UV.y>0.935&&UV.x>0.54&&UV.x<0.77))discard;}}
