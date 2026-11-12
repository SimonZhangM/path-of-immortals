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
void fragment(){
 vec2 p=glyph;
 float d=10.0,coverage=0.0,halo=0.0;
 vec4 artwork=vec4(0.0);
 bool usesArtwork=(motif>1.5&&motif<2.5)||motif>3.5;
 if(motif<1.5){
  d=min(segment(p,vec2(-0.72,0.0),vec2(0.72,0.0)),segment(p,vec2(0.0,-0.72),vec2(0.0,0.72)));
  d=min(d,min(segment(p,vec2(-0.46,-0.46),vec2(0.46,0.46)),segment(p,vec2(-0.46,0.46),vec2(0.46,-0.46))));
  if(motif>0.5)d=min(d,abs(abs(p.x)+abs(p.y)-0.37)*0.7071);
  coverage=1.0-smoothstep(0.035,0.13,d);halo=exp(-d*d/0.12)*0.14;
 }else if(motif<2.5){
  artwork=texture(starArt,(p+1.0)*0.5);coverage=artwork.a;
 }else if(motif>3.5){
  artwork=texture(flowerArt,(p+1.0)*0.5);coverage=artwork.a;
 }else{
  coverage=exp(-dot(p,p)*65.0);halo=exp(-dot(p,p)*5.0)*0.30;
 }
 float alpha=clamp((coverage+halo)*power,0.0,1.0);
 if(motif>3.5){
  vec2 delta=screenPoint-vec2(799.85331148,441.64119134);
  float outer=length(delta/vec2(309.18142026,264.62583951));
  float inner=length(delta/vec2(283.18142026,238.62583951));
  alpha*=(1.0-smoothstep(0.995,0.998,outer))*smoothstep(1.002,1.005,inner);
 }
 alpha*=1.0-smoothstep(645.0,653.0,screenPoint.y);
 vec3 color=mix(vec3(0.94,0.53,0.10),vec3(1.0,0.87,0.45),coverage*0.65);
 if(motif>1.5)color=mix(vec3(1.0,0.57,0.08),vec3(1.0,0.95,0.74),coverage);
 if(usesArtwork)color=artwork.rgb;
 COLOR=vec4(color*alpha,alpha);
}