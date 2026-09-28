/* Independent verification decoder for the Baseline/CAVLC subset (plus general parsing checks).
 * Supports: I/P slices, I16x16, I4x4 (not produced but parsed), P_L0_16x16/P_Skip, integer & fractional mv,
 * deblocking only when disabled (errors out otherwise). Outputs cropped I420. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "tables.h"
#define DIE(...) do{ fprintf(stderr,__VA_ARGS__); fprintf(stderr,"\n"); exit(2);}while(0)

typedef struct { const uint8_t*d; size_t n, pos; } BR; /* bit position */
static uint32_t u(BR*b,int k){ uint32_t v=0; for(int i=0;i<k;i++){ if(b->pos>=b->n*8) DIE("read past end"); v=(v<<1)|((b->d[b->pos>>3]>>(7-(b->pos&7)))&1); b->pos++; } return v; }
static uint32_t ue(BR*b){ int z=0; while(!u(b,1)){ z++; if(z>31) DIE("bad ue"); } return (z?((1u<<z)-1+u(b,z)):0); }
static int se(BR*b){ uint32_t k=ue(b); return (k&1)?(int)((k+1)/2):-(int)(k/2); }
static int more_rbsp(BR*b){ /* true if there is more data before the rbsp_stop_one_bit */
  size_t total=b->n*8; if(b->pos>=total) return 0;
  /* find last 1 bit */
  size_t last=total; while(last>0){ last--; if((b->d[last>>3]>>(7-(last&7)))&1) break; }
  return b->pos < last; }

/* read VLC by matching (len,bits) pairs */
static int read_vlc(BR*b,const uint8_t*len,const uint8_t*bits,int n,int stride_ok_mask_zero){
  uint32_t code=0; int l=0;
  for(l=1;l<=16;l++){ code=(code<<1)|u(b,1);
    for(int i=0;i<n;i++) if(len[i]==l && bits[i]==code && !(stride_ok_mask_zero && len[i]==0)) return i; }
  DIE("vlc not found"); return -1; }

static int W,H,MBW,MBH,PW,PH, crop_r, crop_b, log2mfn, poc_type, sps_ok=0;
static int pps_init_qp, chroma_qp_off, deblock_present, entropy;
typedef struct { uint8_t*y,*u,*v; } Pic; static Pic curp, refp;
static uint8_t *tcY, *tcC; static int *mvx_,*mvy_; static int8_t *refi; static uint8_t *intra_mb;

static inline int clip(int x){ return x<0?0:x>255?255:x; }

static void inv_transform(int *c /* raster coeff d[y][x] scaled */, int *r){
  int f[16],g[16];
  for(int i=0;i<4;i++){ int d0=c[i*4],d1=c[i*4+1],d2=c[i*4+2],d3=c[i*4+3];
    int e0=d0+d2,e1=d0-d2,e2=(d1>>1)-d3,e3=d1+(d3>>1);
    f[i*4]=e0+e3; f[i*4+1]=e1+e2; f[i*4+2]=e1-e2; f[i*4+3]=e0-e3; }
  for(int j=0;j<4;j++){ int f0=f[j],f1=f[4+j],f2=f[8+j],f3=f[12+j];
    int g0=f0+f2,g1=f0-f2,g2=(f1>>1)-f3,g3=f1+(f3>>1);
    g[j]=g0+g3; g[4+j]=g1+g2; g[8+j]=g1-g2; g[12+j]=g0-g3; }
  for(int i=0;i<16;i++) r[i]=(g[i]+32)>>6;
}
static const int normAdjust[6][3]={{10,16,13},{11,18,14},{13,20,16},{14,23,18},{16,25,20},{18,29,23}};
static int LS(int m,int i,int j){ int cls = (i%2==0&&j%2==0)?0 : (i%2==1&&j%2==1)?1:2; return 16*normAdjust[m][cls]; }

/* residual_block_cavlc: returns total coeff; coeffLevel[startIdx..endIdx] */
static int residual_block(BR*b,int*coeffLevel,int startIdx,int endIdx,int maxNumCoeff,int nC){
  for(int i=0;i<maxNumCoeff;i++) coeffLevel[i]=0;
  int tc,t1;
  if(nC==-1){ int idx=read_vlc(b,chroma_dc_coeff_token_len,chroma_dc_coeff_token_bits,20,1); tc=idx/4; t1=idx%4; }
  else { int t= nC<2?0: nC<4?1: nC<8?2:3; int idx=read_vlc(b,coeff_token_len[t],coeff_token_bits[t],68,1); tc=idx/4; t1=idx%4; }
  if(tc>maxNumCoeff) DIE("tc>max");
  int levelVal[16];
  if(tc>0){
    int suffixLength = (tc>10 && t1<3)?1:0;
    for(int i=0;i<tc;i++){
      if(i<t1){ levelVal[i]= u(b,1)?-1:1; }
      else {
        int level_prefix=0; while(!u(b,1)){ level_prefix++; if(level_prefix>15) DIE("prefix>15 not baseline"); }
        int levelCode=(level_prefix<15?level_prefix:15)<<suffixLength;
        int levelSuffixSize = (level_prefix==14 && suffixLength==0)?4 : (level_prefix>=15? level_prefix-3 : suffixLength);
        if(suffixLength>0 || level_prefix>=14){ int level_suffix = levelSuffixSize? (int)u(b,levelSuffixSize):0; levelCode+=level_suffix; }
        if(level_prefix>=15 && suffixLength==0) levelCode+=15;
        if(level_prefix>=16) levelCode+=(1<<(level_prefix-3))-4096;
        if(i==t1 && t1<3) levelCode+=2;
        if(levelCode%2==0) levelVal[i]=(levelCode+2)>>1; else levelVal[i]=(-levelCode-1)>>1;
        if(suffixLength==0) suffixLength=1;
        int a=levelVal[i]<0?-levelVal[i]:levelVal[i];
        if(a>(3<<(suffixLength-1)) && suffixLength<6) suffixLength++;
      }
    }
    int zerosLeft=0;
    if(tc<endIdx-startIdx+1){
      if(nC==-1) zerosLeft=read_vlc(b,chroma_dc_total_zeros_len[tc-1],chroma_dc_total_zeros_bits[tc-1],4-tc+1,0);
      else zerosLeft=read_vlc(b,total_zeros_len[tc-1],total_zeros_bits[tc-1],16-tc+1,0);
    }
    int runVal[16];
    for(int i=0;i<tc-1;i++){
      if(zerosLeft>0){ int zi=zerosLeft>6?6:zerosLeft-1; int n= zi<6? zi+2 : 15; runVal[i]=read_vlc(b,run_len[zi],run_bits[zi],n,0); }
      else runVal[i]=0;
      zerosLeft-=runVal[i]; if(zerosLeft<0) DIE("zerosLeft<0"); }
    runVal[tc-1]=zerosLeft;
    int coeffNum=-1;
    for(int i=tc-1;i>=0;i--){ coeffNum+=runVal[i]+1; if(startIdx+coeffNum>endIdx) DIE("coeff overflow"); coeffLevel[startIdx+coeffNum]=levelVal[i]; }
  }
  return tc;
}

static int avail_mb(int mx,int my){ return mx>=0&&my>=0&&mx<MBW&&my<MBH; }
/* neighbouring 4x4 luma block total coeff: absolute 4x4 coords */
static int nC_luma(int bx,int by){
  int aok = bx>0, bok = by>0; int s=MBW*4;
  int nA= aok? tcY[by*s+bx-1]:0, nB= bok? tcY[(by-1)*s+bx]:0;
  if(aok&&bok) return (nA+nB+1)>>1; if(aok) return nA; if(bok) return nB; return 0; }
static int nC_chroma(int c,int bx,int by){
  int aok=bx>0,bok=by>0; int s=MBW*2; uint8_t*t=tcC+c*s*MBH*2;
  int nA=aok?t[by*s+bx-1]:0, nB=bok?t[(by-1)*s+bx]:0;
  if(aok&&bok) return (nA+nB+1)>>1; if(aok) return nA; if(bok) return nB; return 0; }

static void intra16_pred(int mode,int mx,int my,int pred[16][16]){
  uint8_t*Y=curp.y; int s=PW; int x0=mx*16,y0=my*16;
  int tA=avail_mb(mx,my-1), lA=avail_mb(mx-1,my), tlA=avail_mb(mx-1,my-1);
  #define P(x,y) ((int)Y[(y0+(y))*s + x0+(x)])
  switch(mode){
  case 0: if(!tA) DIE("V unavailable"); for(int y=0;y<16;y++)for(int x=0;x<16;x++) pred[y][x]=P(x,-1); break;
  case 1: if(!lA) DIE("H unavailable"); for(int y=0;y<16;y++)for(int x=0;x<16;x++) pred[y][x]=P(-1,y); break;
  case 2: { int v; int st=0,sl=0; for(int i=0;i<16;i++){ if(tA) st+=P(i,-1); if(lA) sl+=P(-1,i); }
    if(tA&&lA) v=(st+sl+16)>>5; else if(lA) v=(sl+8)>>4; else if(tA) v=(st+8)>>4; else v=128;
    for(int y=0;y<16;y++)for(int x=0;x<16;x++) pred[y][x]=v; break; }
  case 3: { if(!(tA&&lA&&tlA)) DIE("plane unavailable");
    int Hs=0,Vs=0; for(int xp=0;xp<=7;xp++) Hs+=(xp+1)*(P(8+xp,-1)-P(6-xp,-1));
    for(int yp=0;yp<=7;yp++) Vs+=(yp+1)*(P(-1,8+yp)-P(-1,6-yp));
    int a=16*(P(-1,15)+P(15,-1)), bq=(5*Hs+32)>>6, c=(5*Vs+32)>>6;
    for(int y=0;y<16;y++)for(int x=0;x<16;x++) pred[y][x]=clip((a+bq*(x-7)+c*(y-7)+16)>>5); break; }
  default: DIE("bad i16 mode"); }
  #undef P
}
static void intra_chroma_pred(int mode,int mx,int my,uint8_t*C,int pred[8][8]){
  int s=PW/2, x0=mx*8,y0=my*8;
  int tA=avail_mb(mx,my-1), lA=avail_mb(mx-1,my), tlA=avail_mb(mx-1,my-1);
  #define P(x,y) ((int)C[(y0+(y))*s + x0+(x)])
  if(mode==0){
    for(int cb=0;cb<4;cb++){ int xO=(cb&1)*4, yO=(cb>>1)*4; int st=0,sl=0,v;
      for(int i=0;i<4;i++){ if(tA) st+=P(xO+i,-1); if(lA) sl+=P(-1,yO+i); }
      if((xO==0&&yO==0)||(xO>0&&yO>0)){ if(tA&&lA) v=(st+sl+4)>>3; else if(lA) v=(sl+2)>>2; else if(tA) v=(st+2)>>2; else v=128; }
      else if(xO>0&&yO==0){ if(tA) v=(st+2)>>2; else if(lA) v=(sl+2)>>2; else v=128; }
      else { if(lA) v=(sl+2)>>2; else if(tA) v=(st+2)>>2; else v=128; }
      for(int y=0;y<4;y++)for(int x=0;x<4;x++) pred[yO+y][xO+x]=v; }
  } else if(mode==1){ if(!lA) DIE("cH unavail"); for(int y=0;y<8;y++)for(int x=0;x<8;x++) pred[y][x]=P(-1,y); }
  else if(mode==2){ if(!tA) DIE("cV unavail"); for(int y=0;y<8;y++)for(int x=0;x<8;x++) pred[y][x]=P(x,-1); }
  else if(mode==3){ if(!(tA&&lA&&tlA)) DIE("cplane unavail");
    int Hs=0,Vs=0; for(int xp=0;xp<=3;xp++) Hs+=(xp+1)*(P(4+xp,-1)-P(2-xp,-1));
    for(int yp=0;yp<=3;yp++) Vs+=(yp+1)*(P(-1,4+yp)-P(-1,2-yp));
    int a=16*(P(-1,7)+P(7,-1)), bq=(34*Hs+32)>>6, c=(34*Vs+32)>>6;
    for(int y=0;y<8;y++)for(int x=0;x<8;x++) pred[y][x]=clip((a+bq*(x-3)+c*(y-3)+16)>>5); }
  else DIE("bad chroma mode");
  #undef P
}

/* luma 6-tap interpolation (general) */
static int refY(int x,int y){ x=x<0?0:x>=PW?PW-1:x; y=y<0?0:y>=PH?PH-1:y; return refp.y[y*PW+x]; }
static int tap(int a,int b,int c,int d,int e,int f){ return a-5*b+20*c+20*d-5*e+f; }
static int luma_sample(int xi,int yi,int xf,int yf){
  #define G(dx,dy) refY(xi+(dx),yi+(dy))
  if(!xf&&!yf) return G(0,0);
  int b1=tap(G(-2,0),G(-1,0),G(0,0),G(1,0),G(2,0),G(3,0)); int bb=clip((b1+16)>>5);
  int h1=tap(G(0,-2),G(0,-1),G(0,0),G(0,1),G(0,2),G(0,3)); int hh=clip((h1+16)>>5);
  int s1=tap(G(-2,1),G(-1,1),G(0,1),G(1,1),G(2,1),G(3,1)); int ss=clip((s1+16)>>5);
  int m1=tap(G(1,-2),G(1,-1),G(1,0),G(1,1),G(1,2),G(1,3)); int mm=clip((m1+16)>>5);
  int col[6]; for(int k=-2;k<=3;k++) col[k+2]=tap(G(-2,k),G(-1,k),G(0,k),G(1,k),G(2,k),G(3,k));
  int j1=tap(col[0],col[1],col[2],col[3],col[4],col[5]); int jj=clip((j1+512)>>10);
  int G0=G(0,0), G1=G(1,0), G2=G(0,1), G3=G(1,1);
  switch(yf*4+xf){
   case 1: return (G0+bb+1)>>1; case 2: return bb; case 3: return (bb+G1+1)>>1;
   case 4: return (G0+hh+1)>>1; case 5: return (bb+hh+1)>>1; case 6: return (bb+jj+1)>>1; case 7: return (bb+mm+1)>>1;
   case 8: return hh; case 9: return (hh+jj+1)>>1; case 10: return jj; case 11: return (jj+mm+1)>>1;
   case 12: return (hh+G2+1)>>1; case 13: return (hh+ss+1)>>1; case 14: return (jj+ss+1)>>1; case 15: return (ss+mm+1)>>1;
  }
  (void)G3; return 0;
  #undef G
}

static void mvpred(int mx,int my,int*px,int*py){
  int A_ok=avail_mb(mx-1,my), B_ok=avail_mb(mx,my-1), C_ok=avail_mb(mx+1,my-1), D_ok=avail_mb(mx-1,my-1);
  int rA=-1,rB=-1,rC=-1; int mA[2]={0,0},mB[2]={0,0},mC[2]={0,0};
  if(A_ok){ int i=my*MBW+mx-1; rA=refi[i]; if(rA>=0){mA[0]=mvx_[i];mA[1]=mvy_[i];} }
  if(B_ok){ int i=(my-1)*MBW+mx; rB=refi[i]; if(rB>=0){mB[0]=mvx_[i];mB[1]=mvy_[i];} }
  if(C_ok){ int i=(my-1)*MBW+mx+1; rC=refi[i]; if(rC>=0){mC[0]=mvx_[i];mC[1]=mvy_[i];} }
  else if(D_ok){ C_ok=1; int i=(my-1)*MBW+mx-1; rC=refi[i]; if(rC>=0){mC[0]=mvx_[i];mC[1]=mvy_[i];} }
  if(!B_ok && !C_ok && A_ok){ rB=rC=rA; mB[0]=mC[0]=mA[0]; mB[1]=mC[1]=mA[1]; }
  int cnt=(rA==0)+(rB==0)+(rC==0);
  if(cnt==1){ int*m= rA==0?mA: rB==0?mB:mC; *px=m[0]; *py=m[1]; return; }
  for(int k=0;k<2;k++){ int a=mA[k],b=mB[k],c=mC[k]; int mn=a<b?a:b; mn=mn<c?mn:c; int mxv=a>b?a:b; mxv=mxv>c?mxv:c; int med=a+b+c-mn-mxv; if(k==0)*px=med; else *py=med; }
}

static void inter_pred(int mx,int my,int mvx,int mvy,int py[16][16],int pu[8][8],int pv[8][8]){
  for(int y=0;y<16;y++)for(int x=0;x<16;x++){ int ax=mx*16+x, ay=my*16+y;
    int xi=ax+(mvx>>2), yi=ay+(mvy>>2); py[y][x]=luma_sample(xi,yi,mvx&3,mvy&3); }
  int cw=PW/2,ch=PH/2;
  for(int c=0;c<2;c++){ uint8_t*R=c?refp.v:refp.u;
    for(int y=0;y<8;y++)for(int x=0;x<8;x++){
      int xi=mx*8+x+(mvx>>3), yi=my*8+y+(mvy>>3), xf=mvx&7, yf=mvy&7;
      #define CS(a,b) R[((b)<0?0:(b)>=ch?ch-1:(b))*cw+((a)<0?0:(a)>=cw?cw-1:(a))]
      int v=((8-xf)*(8-yf)*CS(xi,yi)+xf*(8-yf)*CS(xi+1,yi)+(8-xf)*yf*CS(xi,yi+1)+xf*yf*CS(xi+1,yi+1)+32)>>6;
      #undef CS
      if(c) pv[y][x]=v; else pu[y][x]=v; } }
}

static long stats_mb[8];
static void decode_slice(BR*b,int nal_type){
  int first_mb=ue(b); int slice_type=ue(b)%5; ue(b); /*pps id*/
  u(b,log2mfn); if(nal_type==5) ue(b);
  if(poc_type!=2) DIE("only poc type 2 supported");
  if(first_mb!=0) DIE("multi-slice not supported");
  if(slice_type==0){ if(u(b,1)) { ue(b); } if(u(b,1)) DIE("rplm unsupported"); }
  else if(slice_type!=2) DIE("slice type %d unsupported",slice_type);
  if(nal_type==5){ u(b,1); u(b,1); } else { if(u(b,1)) DIE("mmco unsupported"); }
  int qp=pps_init_qp+se(b);
  if(deblock_present){ int dis=ue(b); if(dis!=1) DIE("deblocking enabled - unsupported in verifier"); }
  int mbaddr=0; int more=1;
  while(more){
    if(slice_type==0){ int run=ue(b);
      for(int k=0;k<run;k++){ if(mbaddr>=MBW*MBH) DIE("skip overflow");
        int mx=mbaddr%MBW,my=mbaddr/MBW, px,py;
        /* P_Skip */
        if(!avail_mb(mx-1,my)||!avail_mb(mx,my-1)) {px=py=0;}
        else { int a=my*MBW+mx-1,bb=(my-1)*MBW+mx;
          if((refi[a]==0&&mvx_[a]==0&&mvy_[a]==0)||(refi[bb]==0&&mvx_[bb]==0&&mvy_[bb]==0)) px=py=0; else mvpred(mx,my,&px,&py); }
        int Yp[16][16],Up[8][8],Vp[8][8]; inter_pred(mx,my,px,py,Yp,Up,Vp);
        for(int y=0;y<16;y++)for(int x=0;x<16;x++) curp.y[(my*16+y)*PW+mx*16+x]=Yp[y][x];
        for(int y=0;y<8;y++)for(int x=0;x<8;x++){ curp.u[(my*8+y)*(PW/2)+mx*8+x]=Up[y][x]; curp.v[(my*8+y)*(PW/2)+mx*8+x]=Vp[y][x]; }
        for(int y=0;y<4;y++)for(int x=0;x<4;x++) tcY[(my*4+y)*MBW*4+mx*4+x]=0;
        for(int c=0;c<2;c++)for(int y=0;y<2;y++)for(int x=0;x<2;x++) tcC[c*MBW*2*MBH*2+(my*2+y)*MBW*2+mx*2+x]=0;
        refi[mbaddr]=0; mvx_[mbaddr]=px; mvy_[mbaddr]=py; intra_mb[mbaddr]=0; stats_mb[0]++;
        mbaddr++; }
      if(run>0) more=more_rbsp(b);
      if(!more) break;
    }
    if(mbaddr>=MBW*MBH) DIE("mb overflow");
    int mx=mbaddr%MBW,my=mbaddr/MBW;
    int mb_type=ue(b); int intra; int i16mode=-1,cbpL=0,cbpC=0;
    if(slice_type==0){ if(mb_type<5){ intra=0; if(mb_type!=0) DIE("only P_L0_16x16 supported (got %d)",mb_type); } else { intra=1; mb_type-=5; } }
    else intra=1;
    if(intra){ if(mb_type==0) DIE("I_NxN not produced/supported"); if(mb_type>24) DIE("I_PCM unsupported");
      int t=mb_type-1; i16mode=t%4; cbpC=(t/4)%3; cbpL=(t>=12)?15:0; stats_mb[1]++; }
    int cmode=0, mvdx=0,mvdy=0;
    if(intra){ cmode=ue(b); if(cmode>3) DIE("bad cmode"); }
    else { mvdx=se(b); mvdy=se(b); int cn=ue(b); if(cn>47) DIE("bad cbp"); int cbp=golomb_to_inter_cbp[cn]; cbpL=cbp&15; cbpC=cbp>>4; stats_mb[2]++; }
    if(cbpL>0||cbpC>0||intra){ int dq=se(b); qp=(qp+dq+52)%52; }
    int qpc=chroma_qp_tab[qp<0?0:qp>51?51:qp];
    /* residual */
    int lumaDC[16]={0}; int ac[16][16]; memset(ac,0,sizeof ac);
    int s4=MBW*4;
    if(intra){ residual_block(b,lumaDC,0,15,16,nC_luma(mx*4,my*4)); }
    for(int i8=0;i8<4;i8++) for(int i4=0;i4<4;i4++){ int blk=i8*4+i4; int bx=mx*4+blk_x(blk)/4, by=my*4+blk_y(blk)/4;
      if(cbpL&(1<<i8)){ int tmp[16]; int tc;
        if(intra){ tc=residual_block(b,tmp,0,14,15,nC_luma(bx,by)); for(int i=0;i<15;i++) ac[blk][i+1]=tmp[i]; }
        else { tc=residual_block(b,tmp,0,15,16,nC_luma(bx,by)); for(int i=0;i<16;i++) ac[blk][i]=tmp[i]; }
        tcY[by*s4+bx]=tc; }
      else tcY[by*s4+bx]=0; }
    int cDC[2][4]={{0}}; int cAC[2][4][16]; memset(cAC,0,sizeof cAC);
    if(cbpC&3) for(int c=0;c<2;c++) residual_block(b,cDC[c],0,3,4,-1);
    for(int c=0;c<2;c++) for(int k=0;k<4;k++){ int bx=mx*2+(k&1),by=my*2+(k>>1); int s2=MBW*2;
      if(cbpC&2){ int tmp[16]; int tc=residual_block(b,tmp,0,14,15,nC_chroma(c,bx,by)); for(int i=0;i<15;i++) cAC[c][k][i+1]=tmp[i]; tcC[c*s2*MBH*2+by*s2+bx]=tc; }
      else tcC[c*s2*MBH*2+by*s2+bx]=0; }
    /* prediction */
    int Yp[16][16],Up[8][8],Vp[8][8];
    if(intra){ intra16_pred(i16mode,mx,my,Yp); intra_chroma_pred(cmode,mx,my,curp.u,Up); intra_chroma_pred(cmode,mx,my,curp.v,Vp);
      refi[mbaddr]=-1; mvx_[mbaddr]=mvy_[mbaddr]=0; intra_mb[mbaddr]=1; }
    else { int px,py; mvpred(mx,my,&px,&py); int vx=px+mvdx, vy=py+mvdy; inter_pred(mx,my,vx,vy,Yp,Up,Vp);
      refi[mbaddr]=0; mvx_[mbaddr]=vx; mvy_[mbaddr]=vy; intra_mb[mbaddr]=0; }
    /* luma reconstruction */
    int dcY[16]={0};
    if(intra){ int c[16]; for(int i=0;i<16;i++) c[zigzag4[i]]=lumaDC[i];
      int t[16],f[16];
      for(int i=0;i<4;i++){ int a=c[i*4],bq=c[i*4+1],cc=c[i*4+2],d=c[i*4+3]; t[i*4]=a+bq+cc+d; t[i*4+1]=a+bq-cc-d; t[i*4+2]=a-bq-cc+d; t[i*4+3]=a-bq+cc-d; }
      for(int j=0;j<4;j++){ int a=t[j],bq=t[4+j],cc=t[8+j],d=t[12+j]; f[j]=a+bq+cc+d; f[4+j]=a+bq-cc-d; f[8+j]=a-bq-cc+d; f[12+j]=a-bq+cc-d; }
      for(int i=0;i<16;i++){ if(qp>=36) dcY[i]=(f[i]*LS(qp%6,0,0))<<(qp/6-6); else dcY[i]=(f[i]*LS(qp%6,0,0)+(1<<(5-qp/6)))>>(6-qp/6); } }
    for(int blk=0;blk<16;blk++){ int bx=blk_x(blk),by=blk_y(blk);
      int c[16]; for(int i=0;i<16;i++) c[zigzag4[i]]=ac[blk][i];
      int d[16]; for(int i=0;i<16;i++){ int yy=i>>2,xx=i&3;
        if(intra && i==0){ d[0]=dcY[(by/4)*4+bx/4]; continue; }
        if(qp>=24) d[i]=(c[i]*LS(qp%6,yy,xx))<<(qp/6-4); else d[i]=(c[i]*LS(qp%6,yy,xx)+(1<<(3-qp/6)))>>(4-qp/6); }
      int r[16]; inv_transform(d,r);
      for(int y=0;y<4;y++)for(int x=0;x<4;x++) curp.y[(my*16+by+y)*PW+mx*16+bx+x]=clip(Yp[by+y][bx+x]+r[y*4+x]); }
    for(int cc=0;cc<2;cc++){ int*l=cDC[cc]; int f[4]={l[0]+l[1]+l[2]+l[3], l[0]-l[1]+l[2]-l[3], l[0]+l[1]-l[2]-l[3], l[0]-l[1]-l[2]+l[3]};
      uint8_t*P=cc?curp.v:curp.u; int (*pr)[8]=cc?Vp:Up;
      for(int k=0;k<4;k++){ int c[16]; for(int i=0;i<16;i++) c[zigzag4[i]]=cAC[cc][k][i];
        int d[16]; for(int i=0;i<16;i++){ int yy=i>>2,xx=i&3; if(i==0){ d[0]=((f[k]*LS(qpc%6,0,0))<<(qpc/6))>>5; continue; }
          if(qpc>=24) d[i]=(c[i]*LS(qpc%6,yy,xx))<<(qpc/6-4); else d[i]=(c[i]*LS(qpc%6,yy,xx)+(1<<(3-qpc/6)))>>(4-qpc/6); }
        int r[16]; inv_transform(d,r); int bx=(k&1)*4,by=(k>>1)*4;
        for(int y=0;y<4;y++)for(int x=0;x<4;x++) P[(my*8+by+y)*(PW/2)+mx*8+bx+x]=clip(pr[by+y][bx+x]+r[y*4+x]); } }
    mbaddr++;
    more=more_rbsp(b);
    if(slice_type==2 && !more) break;
  }
  if(mbaddr!=MBW*MBH) DIE("slice ended at mb %d of %d",mbaddr,MBW*MBH);
}

int main(int argc,char**argv){
  if(argc<3){ fprintf(stderr,"usage: h264dec in.h264 out.yuv\n"); return 1; }
  FILE*f=fopen(argv[1],"rb"); fseek(f,0,2); long n=ftell(f); rewind(f); uint8_t*d=malloc(n); if(fread(d,1,n,f)!=(size_t)n) return 1; fclose(f);
  FILE*o=fopen(argv[2],"wb"); int frames=0;
  long i=0; uint8_t*rbsp=malloc(n);
  while(i<n){
    /* find start code */
    if(!(i+3<n && d[i]==0&&d[i+1]==0&&((d[i+2]==1)||(d[i+2]==0&&d[i+3]==1)))) { i++; continue; }
    i += d[i+2]==1?3:4;
    long j=i; while(j<n && !(j+2<n && d[j]==0&&d[j+1]==0&&(d[j+2]==1||(d[j+2]==0&&j+3<n&&d[j+3]==1)))) j++;
    if(j>=n) j=n;
    uint8_t hdr=d[i]; int type=hdr&31;
    size_t rn=0; int zeros=0;
    for(long k=i+1;k<j;k++){ if(zeros>=2 && d[k]==3){ zeros=0; continue; } rbsp[rn++]=d[k]; zeros = d[k]==0?zeros+1:0; }
    BR b={rbsp,rn,0};
    if(type==7){
      int prof=u(&b,8); u(&b,8); int lvl=u(&b,8); ue(&b);
      if(prof!=66) DIE("profile %d",prof);
      log2mfn=ue(&b)+4; poc_type=ue(&b); ue(&b); u(&b,1);
      MBW=ue(&b)+1; MBH=ue(&b)+1; if(!u(&b,1)) DIE("field"); u(&b,1);
      crop_r=crop_b=0; if(u(&b,1)){ ue(&b); crop_r=ue(&b); ue(&b); crop_b=ue(&b); }
      PW=MBW*16; PH=MBH*16; W=PW-2*crop_r; H=PH-2*crop_b;
      if(!sps_ok){ size_t ys=(size_t)PW*PH; curp.y=calloc(ys*3/2,1); curp.u=curp.y+ys; curp.v=curp.u+ys/4; refp.y=calloc(ys*3/2,1); refp.u=refp.y+ys; refp.v=refp.u+ys/4;
        tcY=calloc(MBW*4*MBH*4,1); tcC=calloc(2*MBW*2*MBH*2,1); mvx_=calloc(MBW*MBH,sizeof(int)); mvy_=calloc(MBW*MBH,sizeof(int)); refi=calloc(MBW*MBH,1); intra_mb=calloc(MBW*MBH,1);
        fprintf(stderr,"SPS: %dx%d (coded %dx%d) level %d\n",W,H,PW,PH,lvl); }
      sps_ok=1;
      if(u(&b,1)){ /* VUI: parse fully to validate */
        if(u(&b,1)){ int idc=u(&b,8); if(idc==255){u(&b,16);u(&b,16);} }
        if(u(&b,1)) u(&b,1);
        if(u(&b,1)){ u(&b,3); u(&b,1); if(u(&b,1)){ u(&b,8);u(&b,8);u(&b,8);} }
        if(u(&b,1)){ ue(&b); ue(&b); }
        if(u(&b,1)){ uint32_t nu=u(&b,32), ts=u(&b,32); u(&b,1); if(frames==0) fprintf(stderr,"timing %u/%u\n",nu,ts); }
        if(u(&b,1)) DIE("hrd"); if(u(&b,1)) DIE("hrd");
        u(&b,1);
        if(u(&b,1)){ u(&b,1); ue(&b); ue(&b); ue(&b); ue(&b); ue(&b); ue(&b); }
      }
      if(more_rbsp(&b)) DIE("SPS trailing data");
    } else if(type==8){
      ue(&b); ue(&b); entropy=u(&b,1); if(entropy) DIE("cabac"); u(&b,1); if(ue(&b)) DIE("slice groups");
      ue(&b); ue(&b); u(&b,1); u(&b,2); pps_init_qp=26+se(&b); se(&b); chroma_qp_off=se(&b); if(chroma_qp_off) DIE("cqp off");
      deblock_present=u(&b,1); u(&b,1); u(&b,1);
      if(more_rbsp(&b)) DIE("PPS trailing data");
    } else if(type==5||type==1){
      decode_slice(&b,type);
      for(int y=0;y<H;y++) fwrite(curp.y+y*PW,1,W,o);
      for(int y=0;y<H/2;y++) fwrite(curp.u+y*(PW/2),1,W/2,o);
      for(int y=0;y<H/2;y++) fwrite(curp.v+y*(PW/2),1,W/2,o);
      Pic t=refp; refp=curp; curp=t; frames++;
    }
    i=j;
  }
  fclose(o); fprintf(stderr,"decoded %d frames; skip=%ld intra=%ld inter=%ld\n",frames,stats_mb[0],stats_mb[1],stats_mb[2]);
  return 0;
}
