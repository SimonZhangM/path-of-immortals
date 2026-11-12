shader_type canvas_item;
render_mode unshaded, blend_disabled;
// Native canvas compositor, sampled before live board/character/UI. No screenshot assets.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform sampler2D composition : source_color, filter_linear_mipmap;
uniform vec4 region = vec4(230.0,145.0,1350.0,680.0);
uniform float phase = 0.0;
uniform float blue_phase = 0.0;
uniform vec3 greenLights[24];
const float brightness=1.0;
const float FLOOR_FLATTEN=.164;
float hash(vec2 point) {
 return fract(sin(dot(point,vec2(127.1,311.7)))*43758.5453);
}
float noise(vec2 point) {
 vec2 cell=floor(point);
 vec2 local=fract(point);
 vec2 smoothLocal=local*local*(3.0-2.0*local);
 return mix(mix(hash(cell),hash(cell+vec2(1.0,0.0)),smoothLocal.x),
            mix(hash(cell+vec2(0.0,1.0)),hash(cell+vec2(1.0)),smoothLocal.x),smoothLocal.y);
}
float turbulence(vec2 point) {
 return noise(point)*0.57+noise(point*2.03+vec2(7.2,3.1))*0.28
       +noise(point*4.11+vec2(2.5,11.7))*0.15;
}
vec2 curve(float angle,float lane) {
 float radius=565.0+lane*11.0+8.0*sin(3.0*angle-blue_phase*2.0+lane);
 float depth=151.0+lane*5.0;
 float rise=28.0*sin(2.0*angle-blue_phase+lane*1.4)
           +12.0*sin(4.0*angle+blue_phase*2.0+lane*2.0);
 return vec2(800.0+radius*cos(angle),466.0+depth*sin(angle)+rise+lane*9.0);
}
vec2 tangent(float angle,float lane) {
 return (curve(angle+0.002,lane)-curve(angle-0.002,lane))/0.004;
}
float angularTrail(float angle,float head) {
 float behind=mod(head-angle+TAU*2.0,TAU);
 return exp(-behind*0.88)*smoothstep(0.0,0.11,behind);
}
float waterfallCenter(float y,float side){
 float t=clamp((y-440.0)/220.0,0.0,1.0);
 return mix(483.0+0.8*sin(t*PI),1117.0-1.5*t,side);
}
float waterfallForeground(vec2 p,vec3 original){
 float side=step(800.0,p.x);
 float corner=max(0.0,p.y-508.0);
 float label=side>.5?smoothstep(1123.0+corner*.66,1126.0+corner*.66,p.x)
                   :1.0-smoothstep(465.0-corner*.65,468.0-corner*.65,p.x);
 label*=1.0-smoothstep(540.0,546.0,p.y);
 float gold=smoothstep(.09,.23,original.r-original.b)*smoothstep(.35,.62,original.r);
 // Blue ribbons add light over a continuous curtain; never punch a dark gap.
 return max(label,gold);
}
vec3 waterfallLight(vec2 p){
 if(p.y<414.0||p.y>676.0)return vec3(0.0);
 float side=step(800.0,p.x),center=waterfallCenter(p.y,side),dx=p.x-center;
 if(abs(dx)>36.0)return vec3(0.0);
 float top=mix(429.0,423.0,side),bottom=659.0,height=bottom-top,h=(p.y-top)/height;
 float envelope=smoothstep(-.04,.12,h)*(1.0-smoothstep(.96,1.045,h));
 float spread=16.0+4.0*smoothstep(0.0,1.0,h);
 float flow=h*18.0-blue_phase*8.0;
 float fabric=.58+.23*sin(dx*.55+sin(flow)*.4)+.19*cos(flow+dx*.17);
 float body=exp(-pow(abs(dx/spread),4.0)*1.1)*envelope;
 float mist=exp(-dx*dx/450.0)*envelope;
 vec3 light=vec3(.065,.39,.91)*body*fabric+vec3(.025,.15,.33)*mist;
 // Broad translucent folds and narrow white-blue cores form the full waterfall body.
 for(int i=0;i<9;i++){
  float f=float(i),seed=f*2.39996+side*.81;
  float offset=(f-4.0)*4.55+.6*sin(h*5.0+seed);
  float x=dx-offset-.44*sin(h*17.0-blue_phase*4.0+seed);
  float moving=.48+.52*pow(abs(.5+.5*cos(flow+seed)),2.0);
  float weight=.6+.4*pow(abs(sin(seed+.8)),2.0);
  float broad=exp(-x*x/7.0),core=exp(-x*x/(.36+.28*weight));
  light+=(vec3(.13,.49,1.05)*broad*.76+vec3(.75,1.12,1.30)*core*1.55)*weight*moving*envelope;
 }
 for(int i=0;i<18;i++){
  float f=float(i),seed=f*2.123+side*1.7;
  float x=dx-(f-8.5)*2.3-.55*sin(h*21.0-blue_phase*4.0+seed);
  float moving=.28+.72*pow(abs(.5+.5*sin(h*34.0-blue_phase*8.0+seed)),3.0);
  light+=vec3(.30,.72,1.15)*exp(-x*x/.28)*moving*envelope*.32;
 }
 for(int i=0;i<32;i++){
  float f=float(i),seed=f*2.39996+side*1.47;
  float age=fract(f*.618034+blue_phase/TAU*(i<16?4.0:8.0)+side*.37);
  float y=top+height*age,x=waterfallCenter(y,side)+sin(seed)*18.5;
  vec2 d=p-vec2(x,y);float life=pow(abs(sin(PI*age)),2.0);
  float core=exp(-d.x*d.x/.8-d.y*d.y/3.0);
  float tail=exp(-d.x*d.x/1.7-pow(abs((d.y+8.0)/9.0),2.0))*.33;
  float halo=exp(-d.x*d.x/14.0-d.y*d.y/35.0)*.15;
  light+=vec3(.50,.94,1.3)*(core+tail+halo)*life;
 }
 vec2 foot=(p-vec2(waterfallCenter(657.0,side),657.0))/vec2(23.0,4.3);
 light+=vec3(.27,.8,1.2)*exp(-dot(foot,foot))*(.48+.08*cos(blue_phase*4.0+side));
 return light;
}
vec2 outerCurve(float a,float lane){return vec2(803.0,735.0)+vec2(550.0-lane*10.0,81.0-lane*3.0)*vec2(cos(a),sin(a));}
vec2 outerTangent(float a,float lane){return vec2(550.0-lane*10.0,81.0-lane*3.0)*vec2(-sin(a),cos(a));}
float outerArcVisibility(float a){
 return smoothstep(.46,.88,abs(cos(a)))*(1.0-smoothstep(.08,.37,sin(a)));
}
vec3 outerDiscLight(vec2 p){
 if(p.y<642.0||p.y>783.0||abs(p.x-803.0)<230.0)return vec3(0.0);
 vec3 light=vec3(0.0);
 for(int i=0;i<2;i++){
  float lane=float(i),a=atan((p.y-735.0)/(81.0-lane*3.0),(p.x-803.0)/(550.0-lane*10.0));
  for(int j=0;j<5;j++){vec2 tangent=outerTangent(a,lane);a-=clamp(dot(outerCurve(a,lane)-p,tangent)/max(dot(tangent,tangent),1.0),-.16,.16);}
  vec2 normal=normalize(vec2(-outerTangent(a,lane).y,outerTangent(a,lane).x));
  float across=dot(p-outerCurve(a,lane),normal);
  float visibility=outerArcVisibility(a);
  float side=cos(a)>0.0?1.0:-1.0;
  float flow=a*side-blue_phase*4.0+lane*1.4;
  float surge=.58+.95*exp(3.5*(cos(flow)-1.0));
  float grain=.6+.4*noise(vec2(cos(flow),sin(flow))*10.0+across*.4);
  float weave=.30*sin(a*17.0-blue_phase*4.0+lane);
  float core=exp(-pow(abs((across-weave)/.68),2.0));
  float soft=exp(-across*across/8.0),glow=exp(-across*across/40.0);
  light+=(vec3(.61,.94,1.20)*core*.94+vec3(.045,.38,.97)*soft*.5+vec3(.02,.13,.40)*glow*.25)*surge*grain*visibility;
  // Irregular moving glints embedded in the thin band, never a solid neon tube.
  float sparks=pow(abs(max(0.0,cos(a*29.0-side*blue_phase*8.0+lane*2.0))),30.0);
  light+=vec3(.4,.84,1.2)*exp(-across*across/2.0)*sparks*visibility*.62;
 }
 return light;
}
float lotusRegion(vec2 p) {
 float ellipse=length((p-vec2(1485.0,427.0))/vec2(65.0,40.0));
 return (1.0-smoothstep(0.88,1.06,ellipse))*(1.0-smoothstep(459.0,465.0,p.y));
}
float lotusMask(vec2 p) {
 vec3 color=texture(composition,p/vec2(1600.0,900.0)).rgb;
 float pink=smoothstep(.02,.10,color.r-color.g)*smoothstep(.28,.65,color.r);
 return pink*lotusRegion(p);
}
vec2 greenPath(float a,float lane){
 return vec2(1387.0+lane*2.0,471.0-lane)
  +vec2((152.0-lane*13.0)*cos(a)+3.0*sin(2.0*a+lane),
        (29.0-lane*4.0)*sin(a)+(2.0+lane*2.0)*sin(2.0*a+lane*0.5)+1.4*cos(3.0*a-lane*0.7));
}
vec2 greenTangent(float a,float lane){
 return vec2(-(152.0-lane*13.0)*sin(a)+6.0*cos(2.0*a+lane),
 (29.0-lane*4.0)*cos(a)+(4.0+lane*4.0)*cos(2.0*a+lane*0.5)-4.2*sin(3.0*a-lane*0.7));
}
vec2 greenCurl(float t){
 float u=1.0-t;
 return u*u*u*vec2(1305.0,493.0)+3.0*u*u*t*vec2(1235.0,485.0)
       +3.0*u*t*t*vec2(1229.0,450.0)+t*t*t*vec2(1297.0,427.0);
}
vec3 greenWaves(vec2 p){
 if(p.x<1215.0||p.x>1578.0||p.y<422.0||p.y>524.0)return vec3(0.0);
 vec3 light=vec3(0.0);
 for(int i=0;i<4;i++){
  float lane=float(i);
  float a=atan((p.y-471.0+lane)/(29.0-lane*4.0),(p.x-1387.0-lane*2.0)/(152.0-lane*13.0));
  for(int j=0;j<5;j++){
   vec2 tangent=greenTangent(a,lane);
   a-=clamp(dot(greenPath(a,lane)-p,tangent)/max(dot(tangent,tangent),1.0),-0.24,0.24);
  }
  vec2 normal=normalize(vec2(-greenTangent(a,lane).y,greenTangent(a,lane).x));
  float across=dot(p-greenPath(a,lane),normal);
  float front=pow(abs(0.5+0.5*sin(a)),2.0);
  float width=0.48+front*(4.0-lane*0.72)*(0.78+0.22*sin(2.0*a+lane));
  float flow=a-phase*2.0+lane*1.73;
  // No exponential of mod(): heads blend continuously into tails at the wrap point.
  float surge=0.48+0.67*exp(3.5*(cos(flow)-1.0))+0.28*exp(2.5*(cos(flow+2.1)-1.0));
  float grain=turbulence(vec2(cos(flow),sin(flow))*10.0+across*0.65);
  float rear=.035+.10*pow(abs(.5+.5*cos(a+lane*1.7)),3.0);
  float visibility=(rear+front*.94)*(1.0-lane*.14);
  float body=exp(-across*across/(width*width*2.0));
  float glow=exp(-across*across/(width*width*10.0));
  light+=vec3(0.15,0.68,0.035)*glow*surge*visibility*0.25;
  light+=vec3(0.38,1.02,0.10)*body*surge*visibility*(0.36+grain*0.9);
  for(int j=0;j<3;j++){
   float f=float(j)-1.0;
   float offset=f*width*.73+width*.16*sin(a*(5.0+float(j))+phase*2.0+lane*2.0);
   float d=across-offset;
   float thread=exp(-d*d/(0.32+front*0.24));
   light+=vec3(0.63,1.15,0.30)*thread*surge*(0.22+0.78*grain)*visibility*0.65;
  }
 }
 // An open, tapered rising curl gives the energy a trailing silhouette.
 float closest=1e4,along=0.0;
 vec2 previous=greenCurl(0.0);
 for(int i=1;i<=36;i++){
  float t=float(i)/36.0;vec2 next=greenCurl(t),d=next-previous;
  float u=clamp(dot(p-previous,d)/dot(d,d),0.0,1.0);
  float distance=length(p-previous-d*u);
  if(distance<closest){closest=distance;along=(float(i)-1.0+u)/36.0;}
  previous=next;
 }
 float curlWidth=0.45+2.1*sin(PI*along);
 float taper=pow(abs(max(0.0,sin(PI*along))),0.7);
 float curlFlow=.55+.45*cos(along*TAU-phase*2.0);
 light+=vec3(0.36,0.91,0.13)*exp(-closest*closest/(curlWidth*curlWidth))*taper*curlFlow*.78;
 light+=vec3(0.23,0.70,0.05)*exp(-closest*closest/(curlWidth*curlWidth*8.0))*taper*.18;
 for(int i=0;i<24;i++){
  vec3 spark=greenLights[i];vec2 d=p-spark.xy;
  float core=exp(-dot(d,d)/1.4),glow=exp(-dot(d,d)/14.0)*.15;
  float rays=exp(-abs(d.x)*.55-abs(d.y)*2.9)*.16+exp(-abs(d.y)*.6-abs(d.x)*3.0)*.13;
  light+=vec3(.74,1.21,.35)*(core+glow+rays)*spark.z;
 }
 // Persistent energy source: fixed at the lower front, never travelling with particles.
 vec2 source=p-vec2(1387.0,500.0);
 float breathing=.93+.07*cos(phase*2.0);
 float sourceCore=exp(-dot(source,source)/5.8);
 float sourceHalo=exp(-pow(abs(source.x/25.0),2.0)-pow(abs(source.y/6.2),2.0));
 float sourceRay=exp(-abs(source.x)/17.0-pow(abs(source.y/.82),2.0))
                +.9*exp(-abs(source.y)/7.0-pow(abs(source.x/1.05),2.0));
 light+=vec3(.53,1.32,.19)*(sourceHalo*.70+sourceCore*2.5+sourceRay*1.35)*breathing;
 return light;
}
float bottomGoldSides(float angle){return smoothstep(.43,.66,abs(cos(angle)));}
vec4 flatFloorRing(vec2 p){
 vec2 q=(p-vec2(802.0,733.0))/vec2(1.0,FLOOR_FLATTEN);
 float r=length(q);
 if(r<462.0||r>534.0)return vec4(0.0);
 float angle=atan(q.y,q.x);
 float gradient=length(vec2(q.x,q.y/FLOOR_FLATTEN))/max(r,1.0);
 float outer=(r-514.0)/gradient,inner=(r-482.0)/gradient;
 float body=(1.0-smoothstep(-.45,.65,outer))*smoothstep(-.65,.45,inner);
 float edge=min(abs(outer),abs(inner));
 float rim=exp(-edge*edge/.60),warm=exp(-edge*edge/5.0),aura=exp(-edge*edge/21.0);
 float grain=noise(q*.15),cross=(r-482.0)/32.0;
 vec3 metal=vec3(.080,.094,.103)+vec3(.041,.025,.008)*grain;
 metal+=vec3(.035,.022,.006)*(.5+.5*cos(cross*TAU));
 float shine=.86+.27*exp(5.0*(cos(angle-phase*2.0)-1.0));
 vec3 light=(vec3(1.0,.78,.30)*rim*1.15+vec3(.98,.39,.045)*warm*.36+vec3(.68,.21,.02)*aura*.085)*shine*brightness;
 float visibility=bottomGoldSides(angle);
 float alpha=max(body,max(rim,warm*.7+aura*.15))*visibility;
 return vec4(metal*body+light,clamp(alpha,0.0,1.0));
}
float ringFrontMask(vec2 p) {
 // The platform hides the lower arc; the title and side panels stay in front.
 return (1.0-smoothstep(645.0,653.0,p.y))*smoothstep(167.0,176.0,p.y);
}
float ellipseDistance(vec2 p, vec2 radii) {
 vec2 q=(p-vec2(799.85331148,441.64119134))/radii;
 float r=length(q);
 if(r<0.02)return -min(radii.x,radii.y);
 return (r-1.0)*r/max(length(q/radii),0.00001);
}
vec3 titleSourceLight(vec2 p){
 vec2 d=p-vec2(802.0,176.0);
 if(abs(d.x)>65.0||abs(d.y)>30.0)return vec3(0.0);
 float core=exp(-dot(d/vec2(2.2,1.55),d/vec2(2.2,1.55)));
 float glow=exp(-dot(d/vec2(11.0,5.0),d/vec2(11.0,5.0)));
 float halo=exp(-dot(d/vec2(25.0,11.0),d/vec2(25.0,11.0)));
 float horizontal=exp(-abs(d.x)/18.0-pow(abs(d.y/.85),2.0));
 float vertical=exp(-abs(d.y)/5.0-pow(abs(d.x/1.15),2.0));
 float pulse=.97+.03*cos(phase*2.0);
 float edge=(1.0-smoothstep(48.0,65.0,abs(d.x)))*(1.0-smoothstep(20.0,30.0,abs(d.y)));
 return (vec3(3.2,2.7,1.8)*core+vec3(1.6,.96,.26)*glow
  +vec3(.52,.25,.035)*halo+vec3(1.45,1.12,.53)*(horizontal*.7+vertical*.42))*pulse*edge;
}
vec4 fixedOrbitRing(vec2 p) {
 float outer=ellipseDistance(p,vec2(309.18142026,264.62583951));
 float inner=ellipseDistance(p,vec2(283.18142026,238.62583951));
 float mid=ellipseDistance(p,vec2(296.18142026,251.62583951));
 float body=(1.0-smoothstep(-0.6,0.6,outer))*smoothstep(-0.6,0.6,inner);
 float edge=min(abs(outer),abs(inner));
 float rim=exp(-edge*edge/0.75);
 float warm=exp(-edge*edge/7.0);
 float aura=exp(-edge*edge/37.0);
 float grain=turbulence(p*0.11);
 float crossLight=0.5+0.5*cos(mid*0.17);
 vec3 metal=vec3(0.103,0.111,0.106)+vec3(0.047,0.030,0.010)*grain;
 metal+=vec3(0.055,0.031,0.009)*(1.0-crossLight);
 // The lit contour stays put; a low-amplitude travelling shine changes brightness only.
 float a=atan((p.y-441.64119134)/251.62583951,(p.x-799.85331148)/296.18142026);
 float head=exp(-mod(a+phase*2.0+TAU*5.0,TAU)*3.1);
 float gain=0.84+0.32*head;
 vec3 emission=(vec3(1.00,0.82,0.36)*rim*1.22+vec3(1.00,0.42,0.055)*warm*0.47+vec3(0.77,0.21,0.018)*aura*0.11)*gain*brightness;
 vec3 color=metal*body+emission;
 float alpha=max(body,max(rim,warm*0.78+aura*0.19));
 float guide=max(1.0-smoothstep(0.4,0.95,abs(outer-3.0)),1.0-smoothstep(0.4,0.95,abs(inner+3.0)))*0.0;
 color=mix(color,vec3(0.13,0.93,0.92),guide);
 alpha=max(alpha,guide);
 alpha*=ringFrontMask(p);
 return vec4(color,clamp(alpha,0.0,1.0));
}
void fragment() {
 vec2 scenePoint=region.xy+UV*region.zw;
 vec2 point=(scenePoint-vec2(800.0,695.0))/vec2(425.0/565.0,99.166667/151.0)+vec2(800.0,466.0);
 vec2 view=(point-vec2(800.0,466.0))/vec2(565.0,151.0);
 float radius=length(view);
 float atmosphere=exp(-dot((point-vec2(800.0,488.0))/vec2(620.0,260.0),
                           (point-vec2(800.0,488.0))/vec2(620.0,260.0)));
 vec3 background=vec3(0.010,0.022,0.038)+vec3(0.008,0.018,0.033)*atmosphere;
 vec3 light=vec3(0.0);
 if(scenePoint.y>575.0 && radius>0.45 && radius<1.65) {
   for(int ribbon=0;ribbon<3;ribbon++) {
     float lane=float(ribbon)-1.0;
     float angle=atan(view.y,view.x);
     // Find the local ribbon contour so thickness stays consistent around the ellipse.
     for(int iteration=0;iteration<6;iteration++) {
       vec2 derivative=tangent(angle,lane);
       angle-=clamp(dot(curve(angle,lane)-point,derivative)/max(dot(derivative,derivative),1.0),-0.22,0.22);
     }
     vec2 direction=normalize(tangent(angle,lane));
     vec2 normal=vec2(-direction.y,direction.x);
     vec2 offset=point-curve(angle,lane);
     float across=length(offset)*sign(dot(offset,normal));
     float front=0.5+0.5*sin(angle);
     float perspective=0.55+0.45*front;
     float flowAngle=angle-blue_phase*2.0+lane*0.8;
     float width=(15.0+8.0*front)*(0.8+0.2*sin(flowAngle*3.0+lane));
     float cross=across/width;
     vec2 flowCoordinate=vec2(cos(flowAngle),sin(flowAngle))*10.0
                        +vec2(cross*1.2,cross*2.8);
     float texture=turbulence(flowCoordinate);
     float smallTexture=noise(flowCoordinate*7.0);
     float tailA=angularTrail(angle,blue_phase*2.0+lane*1.9);
     float tailB=angularTrail(angle,blue_phase*2.0+lane*1.9+PI);
     float surge=0.42+tailA*1.35+tailB*0.68;
     float body=exp(-cross*cross*1.55);
     float vapor=exp(-across*across/(width*width*5.0));
     float smoke=smoothstep(0.27,0.76,texture);
     // A broad translucent body and travelling internal streaks form the whole ribbon.
     light+=vec3(0.015,0.14,0.66)*vapor*smoke*surge*perspective*0.44;
     light+=vec3(0.018,0.34,0.93)*body*surge*perspective*(0.20+0.85*smoke)*0.76;
     for(int thread=0;thread<6;thread++) {
       float index=float(thread);
       float spread=(index-2.5)*2.6;
       float weave=3.4*sin(angle*(3.0+mod(index,3.0))-blue_phase*2.0+index*1.7+lane)
                  +1.5*sin(angle*11.0+blue_phase*3.0+index);
       float threadDistance=across-spread-weave;
       float filament=exp(-threadDistance*threadDistance/(0.6+front*0.55));
       float soft=exp(-threadDistance*threadDistance/15.0);
       float life=0.25+0.75*smoothstep(0.32,0.77,
                    turbulence(vec2(cos(flowAngle+index),sin(flowAngle+index))*8.0+index));
       light+=vec3(0.08,0.54,1.00)*soft*life*surge*perspective*0.19;
       light+=vec3(0.60,0.94,1.00)*filament*life*surge*perspective*0.58;
     }
     float edgeDistance=abs(across)-width*(0.62+0.18*sin(flowAngle*5.0+lane));
     float edge=exp(-edgeDistance*edgeDistance/1.5);
     light+=vec3(0.12,0.62,1.0)*edge*(0.25+smallTexture*0.35)*surge*perspective*0.24;
   }
 }
 // Very faint reflected light grounds the hovering ribbon.
 float floorHalo=exp(-pow(abs((point.x-800.0)/560.0),2.0)-pow(abs((point.y-671.0)/57.0),2.0));
 light+=vec3(0.005,0.022,0.065)*floorHalo;
 vec3 mapped=vec3(1.0)-exp(-light*brightness*1.42);
 float bottom=1.0-smoothstep(810.0,818.0,scenePoint.y);
 float controls=1.0-(1.0-smoothstep(71.0,75.0,abs(scenePoint.x-800.0)))*(1.0-smoothstep(12.0,16.0,abs(scenePoint.y-791.0)));
 float panels=1.0-(1.0-smoothstep(628.0,637.0,scenePoint.y))*smoothstep(395.0,405.0,abs(scenePoint.x-800.0));

 vec3 original=texture(screen_texture,SCREEN_UV).rgb;
 vec4 movingRing=fixedOrbitRing(scenePoint);
 vec3 base=mix(original,movingRing.rgb,movingRing.a);
 vec4 floorRing=flatFloorRing(scenePoint);
 base=mix(base,floorRing.rgb,floorRing.a);
 float breath=.5-.5*cos(phase*2.0);
 float petal=lotusMask(scenePoint),softPetal=0.0;
 for(int i=0;i<8;i++){
  float a=float(i)*TAU/8.0;
  softPetal+=lotusMask(scenePoint+vec2(cos(a),sin(a))*3.0)/8.0;
 }
 vec3 lotusLight=vec3(.90,.33,.52)*max(0.0,softPetal-petal*.65)*(.014+.075*breath);
 base*=1.0+petal*(-.04+.10*breath);
 vec3 newLight=titleSourceLight(scenePoint)+greenWaves(scenePoint)+lotusLight
  +waterfallLight(scenePoint)*(1.0-movingRing.a)*(1.0-waterfallForeground(scenePoint,original))
  +outerDiscLight(scenePoint);
 vec3 colored=vec3(1.0)-exp(-newLight);
 COLOR=vec4(1.0-(1.0-base)*(1.0-mapped*bottom*controls*panels)*(1.0-colored),1.0);
}
