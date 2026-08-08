#include <stdio.h>
#include <math.h>
#include <stdint.h>
typedef int32_t s32; typedef uint32_t u32;
#define NOISE_MAGIC_X 1619
#define NOISE_MAGIC_Y 31337
#define NOISE_MAGIC_SEED 1013U
static int myfloor(float f){ if(f>0) return (int)f; int i=(int)f; return (i>f)?i-1:i; }
static float noise2d(int x,int y,s32 seed){
  unsigned int n=(NOISE_MAGIC_X*x+NOISE_MAGIC_Y*y+NOISE_MAGIC_SEED*seed)&0x7fffffff;
  n=(n>>13)^n;
  n=(n*(n*n*60493+19990303)+1376312589)&0x7fffffff;
  return 1.f-(float)(int)n/0x40000000;
}
static float easeCurve(float t){ return t*t*t*(t*(6.f*t-15.f)+10.f); }
static float bilin(float v00,float v10,float v01,float v11,float x,float y,int eased){
  if(eased){x=easeCurve(x);y=easeCurve(y);}
  float u=v00+(v10-v00)*x, v=v01+(v11-v01)*x; return u+(v-u)*y;
}
static float nv2(float x,float y,s32 seed,int eased){
  int x0=myfloor(x),y0=myfloor(y); float xl=x-(float)x0, yl=y-(float)y0;
  return bilin(noise2d(x0,y0,seed),noise2d(x0+1,y0,seed),noise2d(x0,y0+1,seed),noise2d(x0+1,y0+1,seed),xl,yl,eased);
}
static float nf2(float off,float sc,float spread,s32 npseed,int oct,float pers,float lac,float x,float y,s32 seed){
  float a=0,f=1.f,g=1.f; x/=spread; y/=spread; seed+=npseed;
  for(int i=0;i<oct;i++){ a+=g*nv2(x*f,y*f,seed+i,1); f*=lac; g*=pers; }
  return off+a*sc;
}
int main(){
  s32 S=1580377614;
  int pts[][2]={{0,900},{550,900},{-550,900},{500,500},{1500,500},{800,1500},{123,-777},{-1234,1666},{7,101},{1249,1201}};
  for(int i=0;i<10;i++){
    float x=pts[i][0],z=pts[i][1];
    float heat=nf2(50,35,1000,5349,3,0.5f,2.f,x,z,S)+nf2(0,4,32,13,2,1.0f,2.f,x,z,S);
    float hum =nf2(50,35,1000,842,3,0.5f,2.f,x,z,S)+nf2(0,4,32,90003,2,1.0f,2.f,x,z,S);
    float hsel=nf2(-8,16,500,4213,6,0.7f,2.f,x,z,S);
    float pp  =nf2(0.6f,0.1f,2000,539,3,0.6f,2.f,x,z,S);
    float hb  =nf2(14,70,600,82341,5,pp,2.f,x,z,S);
    float ha  =nf2(10,25,600,5934,5,pp,2.f,x,z,S);
    printf("%d %d %.9g %.9g %.9g %.9g %.9g %.9g\n",pts[i][0],pts[i][1],heat,hum,hsel,pp,hb,ha);
  }
  return 0;
}
