shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;
uniform sampler2D starArt : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D flowerArt : source_color, filter_linear_mipmap, repeat_disable;

uniform float visual_time=0.0;
uniform float small_per_eighth=6.0;
uniform bool floor_mode=false;
uniform sampler2D orbit_angles : filter_linear, repeat_disable;
varying vec2 glyph;
varying vec2 screenPoint;
varying float motif;
varying float power;
void vertex(){
 float id=round(COLOR.r*128.0);
 motif=COLOR.g*4.0;
 float radius=COLOR.b*32.0;
 float aspect=COLOR.a*2.0;
 vec2 g=UV;
 vec2 p; vec2 tx;vec2 ty;
 if(floor_mode){
  float angle;
  if(motif<1.5)angle=id/32.0*TAU+visual_time/64.0*TAU;
  else if(motif<2.5)angle=id/4.0*TAU+visual_time/64.0*TAU;
  else if(motif>3.5)angle=(id/4.0+.125)*TAU+visual_time/64.0*TAU;
  else angle=id/32.0*TAU-visual_time/32.0*TAU;
  p=vec2(802.0,733.0)+vec2(498.0*cos(angle),498.0*sin(angle)*.164);
  tx=vec2(-sin(angle),cos(angle)*.164)*radius*aspect;
  ty=vec2(cos(angle),sin(angle)*.164)*radius;
  power=motif<1.5?.97:1.0;
  if(motif>2.5&&motif<3.5){tx=vec2(radius,0.0);ty=vec2(0.0,radius);power=.20;}
  g*=1.0+1.25/(radius*(motif>2.5&&motif<3.5?1.0:.164));
 }else{
  float lane=0.0;float progress;
  if(motif<1.5)progress=(floor(id/small_per_eighth)+(mod(id,small_per_eighth)+1.0)/(small_per_eighth+1.0))/8.0+visual_time/32.0-.25;
  else if(motif<2.5)progress=id/4.0+visual_time/32.0-.25;
  else if(motif>3.5)progress=id/4.0+.125+visual_time/32.0-.25;
  else {progress=id/32.0-visual_time/16.0;lane=1.0+mod(id,2.0);}
  float angle=texture(orbit_angles,vec2((fract(progress)*4096.0+.5)/4097.0,(lane+.5)/3.0)).r;
  float offset=lane<.5?0.0:(lane<1.5?-9.0:9.0);
  vec2 radii=vec2(296.18142026,251.62583951)+offset;
  p=vec2(799.85331148,441.64119134)+radii*vec2(cos(angle),sin(angle));
  vec2 tangent=normalize(radii*vec2(-sin(angle),cos(angle)));
  tx=tangent*radius*aspect;ty=vec2(-tangent.y,tangent.x)*radius;
  power=motif<1.5?.94:1.0;
  if(motif>2.5&&motif<3.5)power=.32+.24*sin(TAU*(id/32.0+visual_time/8.0));
 }
 glyph=g;
 screenPoint=p+tx*g.x+ty*g.y;
 VERTEX=screenPoint;
}
float segment(vec2 p,vec2 a,vec2 b){vec2 d=b-a;return length(p-a-d*clamp(dot(p-a,d)/dot(d,d),0.0,1.0));}
vec4 motifSample(vec2 p){
 float coverage=0.0,halo=0.0;vec3 color=vec3(1.0,.80,.30);
 if(motif<1.5){
  float d=min(segment(p,vec2(-.72,0.0),vec2(.72,0.0)),segment(p,vec2(0.0,-.72),vec2(0.0,.72)));
  d=min(d,min(segment(p,vec2(-.46,-.46),vec2(.46,.46)),segment(p,vec2(-.46,.46),vec2(.46,-.46))));
  if(motif>.5)d=min(d,abs(abs(p.x)+abs(p.y)-.37)*.7071);
  coverage=1.0-smoothstep(.045,.19,d);halo=exp(-d*d/.12)*.13;
 }else if(motif<2.5){vec4 art=texture(starArt,(p+1.0)*.5);coverage=art.a;color=art.rgb;
 }else if(motif>3.5){vec4 art=texture(flowerArt,(p+1.0)*.5);coverage=art.a;color=art.rgb;
 }else{coverage=exp(-dot(p,p)*40.0);halo=exp(-dot(p,p)*5.0)*.20;color=vec3(1.0,.80,.37);}
 float alpha=clamp((coverage+halo)*power,0.0,1.0);
 alpha*=1.0-smoothstep(.80,1.0,max(abs(p.x),abs(p.y)));
 return vec4(color*alpha,alpha);
}
void fragment(){
 // Integrate each output pixel over its footprint in the flattened motif.
 // Polygon MSAA alone cannot stabilize subpixel lines drawn inside a shader.
 vec2 dx=dFdx(glyph),dy=dFdy(glyph);
 vec4 light=vec4(0.0);
 if(motif<1.5){
  for(int y=0;y<8;y++)for(int x=0;x<8;x++)
   light+=motifSample(glyph+dx*((float(x)+.5)/8.0-.5)+dy*((float(y)+.5)/8.0-.5))/64.0;
 }else{
  for(int y=0;y<4;y++)for(int x=0;x<4;x++)
   light+=motifSample(glyph+dx*((float(x)+.5)/4.0-.5)+dy*((float(y)+.5)/4.0-.5))/16.0;
 }
 vec2 plane=(screenPoint-vec2(802.0,733.0))/vec2(1.0,.164);
 float radius=length(plane),angle=atan(plane.y,plane.x);
 float visibility=1.0;
 if(motif<1.5||motif>3.5){
  float aa=max(.8,fwidth(radius)*.5);
  visibility*=smoothstep(483.2-aa,483.2+aa,radius)*(1.0-smoothstep(512.8-aa,512.8+aa,radius));
 }
 visibility*=smoothstep(.43,.66,abs(cos(angle)));
 COLOR=light*visibility;
}