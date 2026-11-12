shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;
uniform vec4 star_data[40];
varying vec2 glyph;
varying vec2 screenPoint;
varying float power;
void vertex(){
 vec4 star=star_data[int(round(COLOR.r*128.0))];
 glyph=UV;power=star.w;
 screenPoint=star.xy+glyph*star.z;
 VERTEX=screenPoint;
}
void fragment(){
 vec2 p=glyph;float r=dot(p,p);
 float core=exp(-r*170.0);
 float diamond=pow(abs(max(0.0,1.0-abs(p.x)/.30-abs(p.y)/.42)),2.3);
 float horizontal=exp(-abs(p.x)*4.5-p.y*p.y/.00065);
 float vertical=exp(-abs(p.y)*3.8-p.x*p.x/.00045);
 float halo=exp(-r*7.0)*.18+exp(-r*22.0)*.13;
 vec3 light=vec3(1.8,1.35,.65)*(core+diamond*.26)
  +vec3(1.2,.85,.23)*(horizontal*.56+vertical*.62)+vec3(1.0,.45,.04)*halo;
 float edge=1.0-smoothstep(.82,1.0,max(abs(p.x),abs(p.y)));
 float visibility=edge*(1.0-smoothstep(811.0,816.0,screenPoint.y));
 float controls=(1.0-smoothstep(71.0,75.0,abs(screenPoint.x-800.0)))*(1.0-smoothstep(12.0,16.0,abs(screenPoint.y-791.0)));
 visibility*=1.0-controls;
 vec3 emission=(1.0-exp(-light*power))*visibility;
 COLOR=vec4(emission,0.0);
}