#include <stdio.h>
#include <stdlib.h>
#include <math.h>
/* per-video-frame envelopes (30 fps): low (<150Hz) and high (>3kHz), fast attack / slow release, 0..1 */
int main(){FILE*f=fopen("pcm_s16le_48k.raw","rb");fseek(f,0,2);long n=ftell(f)/4;rewind(f);short*s=malloc(n*4);if(fread(s,4,n,f)){}
 int nf=(int)ceil(n/1600.0); double lp=0,lp2=0,hpp=0,hx=0; double al=1-exp(-2*M_PI*150/48000.0), ah=exp(-2*M_PI*3000/48000.0);
 double *L=calloc(nf,8),*Hh=calloc(nf,8);
 for(long i=0;i<n;i++){ double x=(s[2*i]+s[2*i+1])/65536.0; lp+=al*(x-lp); lp2+=al*(lp-lp2); double hp=ah*(hpp+x-hx); hx=x; hpp=hp; L[i/1600]+=lp2*lp2; Hh[i/1600]+=hp*hp; }
 printf("{\"low\":["); double el=0,eh=0;
 for(int k=0;k<nf;k++){ double d=10*log10(L[k]/1600+1e-12); double v=(d+32)/24; v=v<0?0:v>1?1:v; el = v>el? v : el*0.80+v*0.20; printf("%s%.3f",k?",":"",el); }
 printf("],\"high\":[");
 for(int k=0;k<nf;k++){ double d=10*log10(Hh[k]/1600+1e-12); double v=(d+45)/25; v=v<0?0:v>1?1:v; eh = v>eh? v : eh*0.7+v*0.3; printf("%s%.3f",k?",":"",eh); }
 printf("]}\n"); }
