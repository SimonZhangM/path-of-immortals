shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;
uniform float visual_time=0.0;
uniform float blue_speed_scale=.5;
varying vec2 glyph;
varying vec4 tint;
void vertex(){
 float id=round(COLOR.r*128.0),tail=round(COLOR.g*8.0);
 float cycle=visual_time*blue_speed_scale/16.0*TAU;
 float lane=mod(id,3.0)-1.0,seed=id*2.3999632297;
 float angle=seed+cycle*2.0-tail*.010;
 float age=fract(id*.61803398875+cycle/TAU*2.0);
 float opacity=pow(abs(sin(age*PI)),2.0),depth=.5+.5*sin(seed+cycle*2.0);
 float r=565.0+lane*11.0+8.0*sin(angle*3.0-cycle*2.0+lane);
 float rise=28.0*sin(angle*2.0-cycle+lane*1.4)+12.0*sin(angle*4.0+cycle*2.0+lane*2.0);
 vec2 p=vec2(800.0+r*cos(angle),466.0+(151.0+lane*5.0)*sin(angle)+rise+lane*9.0);
 if(mod(id,4.0)<.5){p.x+=sin(seed*1.73)*age*30.0;p.y-=age*age*72.0;}
 p.y+=sin(seed*3.1)*5.0;
 p=vec2(800.0,695.0)+(p-vec2(800.0,466.0))*vec2(425.0/565.0,99.166667/151.0);
 float size=(tail<.5?13.0+mod(id,5.0)*2.1:7.0+tail*.2)*.75;
 float mask=1.0;
 if(p.y>810.0||(abs(p.x-800.0)<75.0&&abs(p.y-791.0)<16.0)||(abs(p.x-800.0)>395.0&&p.y<637.0))mask=0.0;
 tint=vec4(.28+.4*depth,.76+.2*depth,1.0,opacity*exp(-tail*.70)*(.45+.55*depth)*mask);
 glyph=UV;VERTEX=p+UV*size*.5;
}
void fragment(){
 float r=length(glyph);
 float core=exp(-r*r*38.0);
 float glow=exp(-r*r*5.0)*.25;
 float rays=exp(-abs(glyph.x)*24.0-abs(glyph.y)*4.0)*.12+exp(-abs(glyph.y)*24.0-abs(glyph.x)*4.0)*.12;
 float edge=1.0-smoothstep(.85,1.0,r);
 COLOR=vec4(tint.rgb*(core+glow+rays)*tint.a*edge,0.0);
}
