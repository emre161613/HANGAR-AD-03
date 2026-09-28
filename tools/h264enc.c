/*
 * Minimal H.264 Constrained Baseline encoder (CAVLC).
 *  - I slices: Intra16x16 (V/H/DC/Plane) + chroma intra (DC/H/V/Plane)
 *  - P slices: P_Skip / P_L0_16x16 with integer-pel motion search / Intra16x16
 *  - Deblocking disabled (disable_deblocking_filter_idc = 1)
 * Input : raw frames on stdin, either I420 (-i420) or RGBA (default), W x H
 * Output: Annex-B stream, plus an index file with "size keyframe" per frame.
 * usage : h264enc W H out.h264 out.idx [-q qpI qpP] [-g gop] [-i420] [-recon recon.yuv]
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "tables.h"

/* ---------------- bit writer ---------------- */
typedef struct { uint8_t *buf; size_t cap, n; uint32_t acc; int nb; } BW;
static void bw_init(BW*b){ b->cap=1<<20; b->buf=malloc(b->cap); b->n=0; b->acc=0; b->nb=0; }
static inline void bw_byte(BW*b,uint8_t v){ if(b->n>=b->cap){ b->cap*=2; b->buf=realloc(b->buf,b->cap);} b->buf[b->n++]=v; }
static inline void put(BW*b,int len,uint32_t v){
  for(int i=len-1;i>=0;i--){ b->acc=(b->acc<<1)|((v>>i)&1); if(++b->nb==8){ bw_byte(b,b->acc); b->acc=0; b->nb=0; } }
}
static inline void put_ue(BW*b,uint32_t v){ uint32_t x=v+1; int l=0; while((x>>l)>1) l++; put(b,l,0); put(b,l+1,x); }
static inline void put_se(BW*b,int v){ put_ue(b, v<=0 ? (uint32_t)(-2*v) : (uint32_t)(2*v-1)); }
static void put_trailing(BW*b){ put(b,1,1); while(b->nb) put(b,1,0); }

static FILE *fout; static size_t frame_bytes;
static void write_nal(int ref_idc,int type,BW*b){
  static const uint8_t sc[4]={0,0,0,1}; fwrite(sc,1,4,fout);
  uint8_t h=(ref_idc<<5)|type; fwrite(&h,1,1,fout); frame_bytes+=5;
  int zeros=0;
  for(size_t i=0;i<b->n;i++){ uint8_t c=b->buf[i];
    if(zeros>=2 && c<=3){ uint8_t e=3; fwrite(&e,1,1,fout); frame_bytes++; zeros=0; }
    fwrite(&c,1,1,fout); frame_bytes++; zeros = c==0 ? zeros+1 : 0; }
}

/* ---------------- globals ---------------- */
static int W,H,PW,PH,MBW,MBH;
static int qpI=20,qpP=22,gop=60;
typedef struct { uint8_t *y,*u,*v; } Pic;
static Pic cur, rec, ref;
static uint8_t *nzY, *nzC;   /* total_coeff per 4x4: luma [MBH*4][MBW*4], chroma [2][MBH*2][MBW*2] */
static int8_t  *mvx, *mvy;   /* per MB motion vector (integer pel, stored in qpel units /4) */
static int *mvqx, *mvqy; static int8_t *mbref; /* per MB: quarter-pel mv, ref idx (-1 intra) */

static inline int clip1(int x){ return x<0?0:x>255?255:x; }

/* ---------------- transforms ---------------- */
static void fdct4(const int *in, int *out){ /* in: 16 residuals raster, out: coeffs raster */
  int t[16];
  for(int i=0;i<4;i++){ const int*r=in+i*4; int s03=r[0]+r[3], d03=r[0]-r[3], s12=r[1]+r[2], d12=r[1]-r[2];
    t[i*4+0]=s03+s12; t[i*4+1]=2*d03+d12; t[i*4+2]=s03-s12; t[i*4+3]=d03-2*d12; }
  for(int j=0;j<4;j++){ int s03=t[j]+t[12+j], d03=t[j]-t[12+j], s12=t[4+j]+t[8+j], d12=t[4+j]-t[8+j];
    out[j]=s03+s12; out[4+j]=2*d03+d12; out[8+j]=s03-s12; out[12+j]=d03-2*d12; }
}
static void idct4(int *d){ /* in place, d raster coeffs (already scaled) -> residual */
  int f[16];
  for(int i=0;i<4;i++){ int*r=d+i*4; int e0=r[0]+r[2], e1=r[0]-r[2], e2=(r[1]>>1)-r[3], e3=r[1]+(r[3]>>1);
    f[i*4+0]=e0+e3; f[i*4+1]=e1+e2; f[i*4+2]=e1-e2; f[i*4+3]=e0-e3; }
  for(int j=0;j<4;j++){ int g0=f[j]+f[8+j], g1=f[j]-f[8+j], g2=(f[4+j]>>1)-f[12+j], g3=f[4+j]+(f[12+j]>>1);
    d[j]=(g0+g3+32)>>6; d[4+j]=(g1+g2+32)>>6; d[8+j]=(g1-g2+32)>>6; d[12+j]=(g0-g3+32)>>6; }
}
/* 4x4 Hadamard H*X*H with H rows [1,1,1,1],[1,1,-1,-1],[1,-1,-1,1],[1,-1,1,-1] */
static void had4(const int*x,int*o){ int t[16];
  for(int i=0;i<4;i++){ const int*r=x+i*4; int a=r[0]+r[1], b=r[0]-r[1], c=r[2]+r[3], d=r[2]-r[3];
    t[i*4+0]=a+c; t[i*4+1]=a-c; t[i*4+2]=b-d; t[i*4+3]=b+d; }
  for(int j=0;j<4;j++){ int a=t[j]+t[4+j], b=t[j]-t[4+j], c=t[8+j]+t[12+j], d=t[8+j]-t[12+j];
    o[j]=a+c; o[4+j]=a-c; o[8+j]=b-d; o[12+j]=b+d; }
}
static inline int quant(int c,int qp,int pos,int intra){
  int qbits=15+qp/6, f=(1<<qbits)/(intra?3:6), m=MF[qp%6][pos_class(pos)];
  int a=c<0?-c:c; int z=(a*m+f)>>qbits; return c<0?-z:z;
}
static inline int dequant(int z,int qp,int pos){ return (z*V6[qp%6][pos_class(pos)])<<(qp/6); }

/* ---------------- CAVLC ---------------- */
static void cavlc_block(BW*b,const int *coef,int maxc,int nC){
  /* coef: maxc values in scan order */
  int tc=0,t1=0,last=-1;
  for(int i=0;i<maxc;i++) if(coef[i]){ tc++; last=i; }
  int lv[16], rn[16], k=0;             /* levels & runs from highest frequency down */
  if(tc){ int run=0; for(int i=last;i>=0;i--){ if(coef[i]){ if(k>0) rn[k-1]=run; lv[k++]=coef[i]; run=0; } else run++; } rn[k-1]=run; }
  for(int i=0;i<k && i<3;i++){ if(lv[i]==1||lv[i]==-1) t1++; else break; }
  if(nC==-1) put(b,chroma_dc_coeff_token_len[tc*4+t1],chroma_dc_coeff_token_bits[tc*4+t1]);
  else { int t = nC<2?0:nC<4?1:nC<8?2:3; put(b,coeff_token_len[t][tc*4+t1],coeff_token_bits[t][tc*4+t1]); }
  if(!tc) return;
  for(int i=0;i<t1;i++) put(b,1,lv[i]<0);
  int sl = (tc>10 && t1<3) ? 1 : 0;
  for(int i=t1;i<tc;i++){
    int l=lv[i]; int code = l>0 ? 2*l-2 : -2*l-1;
    if(i==t1 && t1<3) code-=2;
    if(sl==0){
      if(code<14){ put(b,code+1,1); }
      else if(code<30){ put(b,15,1); put(b,4,code-14); }
      else { put(b,16,1); if(code-30>=4096){ fprintf(stderr,"level overflow\n"); exit(1);} put(b,12,code-30); }
    } else {
      if(code < (15<<sl)){ put(b,(code>>sl)+1,1); put(b,sl,code&((1<<sl)-1)); }
      else { put(b,16,1); if(code-(15<<sl)>=4096){ fprintf(stderr,"level overflow\n"); exit(1);} put(b,12,code-(15<<sl)); }
    }
    if(sl==0) sl=1;
    int al=l<0?-l:l; if(al>(3<<(sl-1)) && sl<6) sl++;
  }
  if(tc<maxc){
    int tz=0; for(int i=0;i<last;i++) if(!coef[i]) tz++;
    if(nC==-1) put(b,chroma_dc_total_zeros_len[tc-1][tz],chroma_dc_total_zeros_bits[tc-1][tz]);
    else put(b,total_zeros_len[tc-1][tz],total_zeros_bits[tc-1][tz]);
    int zl=tz;
    for(int i=0;i<tc-1 && zl>0;i++){ int r=rn[i]; int zi=zl>7?6:zl-1; put(b,run_len[zi][r],run_bits[zi][r]); zl-=r; }
  }
}

/* nC for luma 4x4 block at absolute block coords (bx,by) */
static int nc_luma(int bx,int by){
  int a = bx>0, bb = by>0; int stride=MBW*4;
  int nA = a ? nzY[by*stride+bx-1] : 0, nB = bb ? nzY[(by-1)*stride+bx] : 0;
  if(a&&bb) return (nA+nB+1)>>1; if(a) return nA; if(bb) return nB; return 0;
}
static int nc_chroma(int c,int bx,int by){
  int stride=MBW*2; uint8_t*p=nzC+c*MBW*2*MBH*2;
  int a=bx>0, bb=by>0; int nA=a?p[by*stride+bx-1]:0, nB=bb?p[(by-1)*stride+bx]:0;
  if(a&&bb) return (nA+nB+1)>>1; if(a) return nA; if(bb) return nB; return 0;
}

/* ---------------- prediction ---------------- */
static void pred16(int mode,int mx,int my,uint8_t *p /*16x16*/){
  const uint8_t *Y=rec.y; int s=PW, x0=mx*16, y0=my*16;
  int top=my>0, left=mx>0;
  if(mode==0){ for(int y=0;y<16;y++) for(int x=0;x<16;x++) p[y*16+x]=Y[(y0-1)*s+x0+x]; }
  else if(mode==1){ for(int y=0;y<16;y++) for(int x=0;x<16;x++) p[y*16+x]=Y[(y0+y)*s+x0-1]; }
  else if(mode==2){ int sum=0,v;
    if(top&&left){ for(int i=0;i<16;i++) sum+=Y[(y0-1)*s+x0+i]+Y[(y0+i)*s+x0-1]; v=(sum+16)>>5; }
    else if(left){ for(int i=0;i<16;i++) sum+=Y[(y0+i)*s+x0-1]; v=(sum+8)>>4; }
    else if(top){ for(int i=0;i<16;i++) sum+=Y[(y0-1)*s+x0+i]; v=(sum+8)>>4; }
    else v=128;
    memset(p,v,256); }
  else { /* plane */
    #define PT(x) Y[(y0-1)*s+x0+(x)]
    #define PL(y) Y[(y0+(y))*s+x0-1]
    int Hh=0,Vv=0;
    for(int i=0;i<8;i++){ Hh+=(i+1)*(PT(8+i)-PT(6-i)); Vv+=(i+1)*(PL(8+i)-PL(6-i)); }
    /* PT(-1)/PL(-1) are the top-left sample; both macros resolve to Y[(y0-1)*s+x0-1] */
    int a=16*(PL(15)+PT(15)), bq=(5*Hh+32)>>6, c=(5*Vv+32)>>6;
    for(int y=0;y<16;y++) for(int x=0;x<16;x++) p[y*16+x]=clip1((a+bq*(x-7)+c*(y-7)+16)>>5);
    #undef PT
    #undef PL
  }
}
static void predc(int mode,int mx,int my,const uint8_t *C,uint8_t *p /*8x8*/){
  int s=PW/2, x0=mx*8, y0=my*8; int top=my>0, left=mx>0;
  #define CT(x) C[(y0-1)*s+x0+(x)]
  #define CL(y) C[(y0+(y))*s+x0-1]
  if(mode==0){ /* DC */
    for(int by=0;by<2;by++) for(int bx=0;bx<2;bx++){
      int xo=bx*4, yo=by*4, sT=0,sL=0,v;
      for(int i=0;i<4;i++){ if(top) sT+=CT(xo+i); if(left) sL+=CL(yo+i); }
      if((xo==0&&yo==0)||(xo>0&&yo>0)){ if(top&&left) v=(sT+sL+4)>>3; else if(left) v=(sL+2)>>2; else if(top) v=(sT+2)>>2; else v=128; }
      else if(xo>0){ if(top) v=(sT+2)>>2; else if(left) v=(sL+2)>>2; else v=128; }
      else { if(left) v=(sL+2)>>2; else if(top) v=(sT+2)>>2; else v=128; }
      for(int y=0;y<4;y++) for(int x=0;x<4;x++) p[(yo+y)*8+xo+x]=v; }
  } else if(mode==1){ for(int y=0;y<8;y++) for(int x=0;x<8;x++) p[y*8+x]=CL(y); }
  else if(mode==2){ for(int y=0;y<8;y++) for(int x=0;x<8;x++) p[y*8+x]=CT(x); }
  else { int Hh=0,Vv=0; for(int i=0;i<4;i++){ Hh+=(i+1)*(CT(4+i)-CT(2-i)); Vv+=(i+1)*(CL(4+i)-CL(2-i)); }
    int a=16*(CL(7)+CT(7)), bq=(34*Hh+32)>>6, c=(34*Vv+32)>>6;
    for(int y=0;y<8;y++) for(int x=0;x<8;x++) p[y*8+x]=clip1((a+bq*(x-3)+c*(y-3)+16)>>5); }
  #undef CT
  #undef CL
}

/* ---------------- residual coding helpers ---------------- */
typedef struct {
  int lumaDC[16];          /* intra16: zigzag-ordered DC levels */
  int luma[16][16];        /* per blk (luma4x4BlkIdx) levels in zigzag order (16 for inter, [1..15] for intra16 AC) */
  int chDC[2][4];
  int chAC[2][4][16];      /* zigzag order, index 0 unused */
  int cbpL, cbpC;
  uint8_t recY[256], recU[64], recV[64];
  int cost;                /* distortion estimate (SSD) */
} MBRes;

/* luma: intra16 (DC separate) or inter 4x4 */
static void code_luma(const uint8_t *src,int ss,const uint8_t *pred,int qp,int intra16,MBRes*r){
  int coef[16][16]; int dcin[16];
  for(int b=0;b<16;b++){ int bx=blk_x(b),by=blk_y(b); int res[16];
    for(int y=0;y<4;y++) for(int x=0;x<4;x++) res[y*4+x]=src[(by+y)*ss+bx+x]-pred[(by+y)*16+bx+x];
    fdct4(res,coef[b]); }
  int nzAC=0;
  int deq[16][16];
  for(int b=0;b<16;b++){
    for(int i=0;i<16;i++){ int pos=zigzag4[i];
      if(intra16 && i==0){ r->luma[b][0]=0; continue; }
      int z=quant(coef[b][pos],qp,pos,intra16); r->luma[b][i]=z; if(z) nzAC=1; }
  }
  if(intra16){
    /* DC hadamard; dc matrix index = spatial block (row,col) */
    int dc[16], t[16], h[16];
    for(int b=0;b<16;b++){ int bx=blk_x(b)/4, by=blk_y(b)/4; dc[by*4+bx]=coef[b][0]; }
    had4(dc,t); for(int i=0;i<16;i++) h[i]=t[i]>>1;
    int qbits=16+qp/6, f=(1<<qbits)/3, m=MF[qp%6][0];
    int lev[16];
    for(int i=0;i<16;i++){ int v=h[i], a=v<0?-v:v; int z=(a*m+f)>>qbits; lev[i]=v<0?-z:z; }
    for(int i=0;i<16;i++) r->lumaDC[i]=lev[zigzag4[i]];
    /* decoder-side DC reconstruction */
    int c2[16], t2[16], f2[16];
    memcpy(c2,lev,sizeof c2);
    (void)t2; had4(c2,f2);
    int LS=16*V6[qp%6][0];
    for(int b=0;b<16;b++){ int bx=blk_x(b)/4, by=blk_y(b)/4; int fv=f2[by*4+bx], dcv;
      if(qp>=36) dcv=(fv*LS)<<(qp/6-6); else dcv=(fv*LS+(1<<(5-qp/6)))>>(6-qp/6);
      deq[b][0]=dcv; }
  }
  r->cbpL = nzAC ? 15 : 0;
  for(int b=0;b<16;b++){
    for(int i=(intra16?1:0);i<16;i++){ int pos=zigzag4[i]; deq[b][pos]= r->cbpL ? dequant(r->luma[b][i],qp,pos) : 0; }
    if(!r->cbpL) for(int i=0;i<16;i++) r->luma[b][i]=0;
    if(!intra16) deq[b][0]= r->cbpL ? dequant(r->luma[b][0],qp,0) : 0;
    int bx=blk_x(b),by=blk_y(b);
    idct4(deq[b]);
    for(int y=0;y<4;y++) for(int x=0;x<4;x++) r->recY[(by+y)*16+bx+x]=clip1(pred[(by+y)*16+bx+x]+deq[b][y*4+x]);
  }
}
static void code_chroma(const uint8_t *su,const uint8_t *sv,int ss,const uint8_t *pu,const uint8_t *pv,int qp,int intra,MBRes*r){
  int qpc=chroma_qp_tab[qp];
  int anyDC=0, anyAC=0;
  int deq[2][4][16];
  for(int c=0;c<2;c++){ const uint8_t*s=c?sv:su; const uint8_t*p=c?pv:pu; int coef[4][16];
    for(int b=0;b<4;b++){ int bx=(b&1)*4, by=(b>>1)*4; int res[16];
      for(int y=0;y<4;y++) for(int x=0;x<4;x++) res[y*4+x]=s[(by+y)*ss+bx+x]-p[(by+y)*8+bx+x];
      fdct4(res,coef[b]); }
    int d0=coef[0][0],d1=coef[1][0],d2=coef[2][0],d3=coef[3][0];
    int f[4]={d0+d1+d2+d3, d0-d1+d2-d3, d0+d1-d2-d3, d0-d1-d2+d3};
    int qbits=16+qpc/6, fr=(1<<qbits)/(intra?3:6), m=MF[qpc%6][0];
    for(int i=0;i<4;i++){ int v=f[i],a=v<0?-v:v; int z=(a*m+fr)>>qbits; r->chDC[c][i]=v<0?-z:z; if(z) anyDC=1; }
    for(int b=0;b<4;b++){ r->chAC[c][b][0]=0; for(int i=1;i<16;i++){ int pos=zigzag4[i]; int z=quant(coef[b][pos],qpc,pos,intra); r->chAC[c][b][i]=z; if(z) anyAC=1; } }
  }
  r->cbpC = anyAC ? 2 : anyDC ? 1 : 0;
  for(int c=0;c<2;c++){ const uint8_t*p=c?pv:pu; uint8_t*o=c?r->recV:r->recU;
    int*l=r->chDC[c]; if(!r->cbpC) for(int i=0;i<4;i++) l[i]=0;
    int f[4]={l[0]+l[1]+l[2]+l[3], l[0]-l[1]+l[2]-l[3], l[0]+l[1]-l[2]-l[3], l[0]-l[1]-l[2]+l[3]};
    int LS=16*V6[qpc%6][0];
    for(int b=0;b<4;b++){
      deq[c][b][0]=((f[b]*LS)<<(qpc/6))>>5;
      for(int i=1;i<16;i++){ int pos=zigzag4[i]; if(r->cbpC<2) r->chAC[c][b][i]=0; deq[c][b][pos]=dequant(r->chAC[c][b][i],qpc,pos); }
      idct4(deq[c][b]); int bx=(b&1)*4, by=(b>>1)*4;
      for(int y=0;y<4;y++) for(int x=0;x<4;x++) o[(by+y)*8+bx+x]=clip1(p[(by+y)*8+bx+x]+deq[c][b][y*4+x]); }
  }
}

static int ssd(const uint8_t*a,int sa,const uint8_t*b,int sb,int w,int h){ int s=0; for(int y=0;y<h;y++) for(int x=0;x<w;x++){ int d=a[y*sa+x]-b[y*sb+x]; s+=d*d; } return s; }
static int sad(const uint8_t*a,int sa,const uint8_t*b,int sb,int w,int h){ int s=0; for(int y=0;y<h;y++) for(int x=0;x<w;x++){ int d=a[y*sa+x]-b[y*sb+x]; s+=d<0?-d:d; } return s; }

/* write residual for an MB (after mb_type etc.) and update nz tables */
static void write_residual(BW*b,int mx,int my,int intra16,MBRes*r){
  int stride=MBW*4;
  if(intra16) cavlc_block(b,r->lumaDC,16,nc_luma(mx*4,my*4));
  for(int blk=0;blk<16;blk++){ int bx=mx*4+blk_x(blk)/4, by=my*4+blk_y(blk)/4;
    int tc=0;
    if(r->cbpL){ int nC=nc_luma(bx,by);
      if(intra16){ cavlc_block(b,r->luma[blk]+1,15,nC); for(int i=1;i<16;i++) tc+=r->luma[blk][i]!=0; }
      else { cavlc_block(b,r->luma[blk],16,nC); for(int i=0;i<16;i++) tc+=r->luma[blk][i]!=0; } }
    nzY[by*stride+bx]=tc; }
  if(r->cbpC) for(int c=0;c<2;c++) cavlc_block(b,r->chDC[c],4,-1);
  for(int c=0;c<2;c++) for(int blk=0;blk<4;blk++){ int bx=mx*2+(blk&1), by=my*2+(blk>>1); int tc=0;
    if(r->cbpC==2){ cavlc_block(b,r->chAC[c][blk]+1,15,nc_chroma(c,bx,by)); for(int i=1;i<16;i++) tc+=r->chAC[c][blk][i]!=0; }
    nzC[c*MBW*2*MBH*2 + by*MBW*2+bx]=tc; }
}
static void store_rec(int mx,int my,MBRes*r){
  for(int y=0;y<16;y++) memcpy(rec.y+(my*16+y)*PW+mx*16, r->recY+y*16,16);
  for(int y=0;y<8;y++){ memcpy(rec.u+(my*8+y)*(PW/2)+mx*8, r->recU+y*8,8); memcpy(rec.v+(my*8+y)*(PW/2)+mx*8, r->recV+y*8,8); }
}
static void clear_nz(int mx,int my){
  for(int y=0;y<4;y++) for(int x=0;x<4;x++) nzY[(my*4+y)*MBW*4+mx*4+x]=0;
  for(int c=0;c<2;c++) for(int y=0;y<2;y++) for(int x=0;x<2;x++) nzC[c*MBW*2*MBH*2+(my*2+y)*MBW*2+mx*2+x]=0;
}

/* best intra16 for MB: returns cost (SSD + lambda*bits approx) and fills r, modes */
static const int lambda_tab[52]={ /* ~0.85*2^((qp-12)/3) scaled for SSD */
 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,2,3,3,4,5,6,7,9,11,14,18,22,28,36,45,57,72,90,114,144,181,228,287,362,456,575,724,912,1149,1448,1825,2299,2896,3649,4598,5793};
static int count_bits_intra(MBRes*r,int mx,int my);

static int try_intra(int mx,int my,int qp,MBRes*best,int*bmode,int*bcmode){
  int s=PW, x0=mx*16, y0=my*16;
  const uint8_t*src=cur.y+y0*s+x0;
  int top=my>0,left=mx>0;
  /* luma mode by SAD */
  int bm=-1,bs=1<<30; uint8_t p[256],bp[256];
  for(int m=0;m<4;m++){
    if(m==0&&!top) continue; if(m==1&&!left) continue; if(m==3&&!(top&&left)) continue;
    pred16(m,mx,my,p); int sa=sad(src,s,p,16,16,16); if(m==2) sa-=16; if(sa<bs){bs=sa;bm=m;memcpy(bp,p,256);} }
  int cm=-1,cs=1<<30; uint8_t pu[64],pv[64],bu[64],bv[64];
  const uint8_t*su=cur.u+(my*8)*(PW/2)+mx*8, *sv=cur.v+(my*8)*(PW/2)+mx*8;
  for(int m=0;m<4;m++){
    if(m==1&&!left) continue; if(m==2&&!top) continue; if(m==3&&!(top&&left)) continue;
    predc(m,mx,my,rec.u,pu); predc(m,mx,my,rec.v,pv);
    int sa=sad(su,PW/2,pu,8,8,8)+sad(sv,PW/2,pv,8,8,8); if(m==0) sa-=8; if(sa<cs){cs=sa;cm=m;memcpy(bu,pu,64);memcpy(bv,pv,64);} }
  code_luma(src,s,bp,qp,1,best);
  code_chroma(su,sv,PW/2,bu,bv,qp,1,best);
  *bmode=bm; *bcmode=cm;
  int dist=ssd(src,s,best->recY,16,16,16)+ssd(su,PW/2,best->recU,8,8,8)+ssd(sv,PW/2,best->recV,8,8,8);
  best->cost=dist + lambda_tab[qp]*count_bits_intra(best,mx,my);
  return best->cost;
}

/* rough bit estimate: count nonzero coefficients & magnitudes */
static int est_bits_block(const int*c,int n){ int b=1; for(int i=0;i<n;i++) if(c[i]){ int a=c[i]<0?-c[i]:c[i]; b+=3; while(a>1){ b+=2; a>>=1; } } return b; }
static int count_bits_intra(MBRes*r,int mx,int my){ (void)mx;(void)my; int b=6+est_bits_block(r->lumaDC,16);
  if(r->cbpL) for(int i=0;i<16;i++) b+=est_bits_block(r->luma[i]+1,15);
  if(r->cbpC){ b+=est_bits_block(r->chDC[0],4)+est_bits_block(r->chDC[1],4); }
  if(r->cbpC==2) for(int c=0;c<2;c++) for(int i=0;i<4;i++) b+=est_bits_block(r->chAC[c][i]+1,15);
  return b; }
static int count_bits_inter(MBRes*r){ int b=4;
  if(r->cbpL) for(int i=0;i<16;i++) b+=est_bits_block(r->luma[i],16);
  if(r->cbpC){ b+=est_bits_block(r->chDC[0],4)+est_bits_block(r->chDC[1],4); }
  if(r->cbpC==2) for(int c=0;c<2;c++) for(int i=0;i<4;i++) b+=est_bits_block(r->chAC[c][i]+1,15);
  return b; }

/* ---------------- motion vector prediction (16x16, single ref) ---------------- */
/* neighbours: A left, B top, C top-right (or D top-left if C unavailable). mv in quarter-pel. */
static void mv_pred(int mx,int my,int *px,int *py){
  int aA=mx>0, aB=my>0, aC=(my>0 && mx<MBW-1), aD=(mx>0&&my>0);
  int rA=-1,rB=-1,rC=-1, ax=0,ay=0,bx=0,by=0,cx=0,cy=0;
  if(aA){ int i=my*MBW+mx-1; rA=mbref[i]; if(rA>=0){ax=mvqx[i];ay=mvqy[i];} }
  if(aB){ int i=(my-1)*MBW+mx; rB=mbref[i]; if(rB>=0){bx=mvqx[i];by=mvqy[i];} }
  if(aC){ int i=(my-1)*MBW+mx+1; rC=mbref[i]; if(rC>=0){cx=mvqx[i];cy=mvqy[i];} }
  else if(aD){ int i=(my-1)*MBW+mx-1; rC=mbref[i]; aC=1; if(rC>=0){cx=mvqx[i];cy=mvqy[i];} else {cx=cy=0;} }
  /* when B and C (and D) unavailable and A available: use A */
  if(!aB && !aC && aA){ *px=ax; *py=ay; return; }
  int n=(rA==0)+(rB==0)+(rC==0);
  if(n==1){ if(rA==0){*px=ax;*py=ay;} else if(rB==0){*px=bx;*py=by;} else {*px=cx;*py=cy;} return; }
  #define MED(a,b,c) ((a)>(b)?((b)>(c)?(b):((a)>(c)?(c):(a))):((a)>(c)?(a):((b)>(c)?(c):(b))))
  *px=MED(ax,bx,cx); *py=MED(ay,by,cy);
}
static void skip_mv(int mx,int my,int*px,int*py){
  if(mx==0||my==0){ *px=*py=0; return; }
  int i=my*MBW+mx-1, j=(my-1)*MBW+mx;
  if((mbref[i]==0 && mvqx[i]==0 && mvqy[i]==0) || (mbref[j]==0 && mvqx[j]==0 && mvqy[j]==0)){ *px=*py=0; return; }
  mv_pred(mx,my,px,py);
}

/* inter prediction with integer mv (quarter-pel units multiple of 4), clamped reference access */
static void pred_inter(int mx,int my,int qx,int qy,uint8_t*py,uint8_t*pu,uint8_t*pv){
  int dx=qx>>2, dy=qy>>2;
  for(int y=0;y<16;y++){ int sy=my*16+y+dy; sy=sy<0?0:sy>=PH?PH-1:sy;
    for(int x=0;x<16;x++){ int sx=mx*16+x+dx; sx=sx<0?0:sx>=PW?PW-1:sx; py[y*16+x]=ref.y[sy*PW+sx]; } }
  /* chroma mv = luma mv (in 1/8 chroma pel); integer luma mv -> half chroma pel when odd */
  int cqx=qx, cqy=qy; /* chroma eighth-pel units == luma quarter-pel value */
  int cdx=cqx>>3, cdy=cqy>>3, fx=cqx&7, fy=cqy&7; int cw=PW/2, ch=PH/2;
  for(int c=0;c<2;c++){ const uint8_t*R=c?ref.v:ref.u; uint8_t*o=c?pv:pu;
    for(int y=0;y<8;y++) for(int x=0;x<8;x++){
      int x0=mx*8+x+cdx, y0=my*8+y+cdy;
      #define CP(xx,yy) R[((yy)<0?0:(yy)>=ch?ch-1:(yy))*cw + ((xx)<0?0:(xx)>=cw?cw-1:(xx))]
      int A=CP(x0,y0),B=CP(x0+1,y0),C=CP(x0,y0+1),D=CP(x0+1,y0+1);
      #undef CP
      o[y*8+x]=((8-fx)*(8-fy)*A + fx*(8-fy)*B + (8-fx)*fy*C + fx*fy*D + 32)>>6; } }
}

/* ---------------- frame encoding ---------------- */
static int frame_num=0, idr_id=0;
static void write_sps_pps(void){
  BW b; bw_init(&b);
  put(&b,8,66); put(&b,8,0xC0); put(&b,8,40);
  put_ue(&b,0); put_ue(&b,4); put_ue(&b,2); put_ue(&b,1); put(&b,1,0);
  put_ue(&b,MBW-1); put_ue(&b,MBH-1); put(&b,1,1); put(&b,1,1);
  int cr=(PW-W)/2, cb=(PH-H)/2;
  if(cr||cb){ put(&b,1,1); put_ue(&b,0); put_ue(&b,cr); put_ue(&b,0); put_ue(&b,cb); } else put(&b,1,0);
  put(&b,1,1); /* vui */
  put(&b,1,0); put(&b,1,0);
  put(&b,1,1); put(&b,3,5); put(&b,1,0); put(&b,1,1); put(&b,8,1); put(&b,8,1); put(&b,8,1);
  put(&b,1,0);
  put(&b,1,1); put(&b,32,1); put(&b,32,60); put(&b,1,1);
  put(&b,1,0); put(&b,1,0); put(&b,1,0);
  put(&b,1,1); put(&b,1,1); put_ue(&b,0); put_ue(&b,0); put_ue(&b,16); put_ue(&b,16); put_ue(&b,0); put_ue(&b,1);
  put_trailing(&b); write_nal(3,7,&b); free(b.buf);
  bw_init(&b);
  put_ue(&b,0); put_ue(&b,0); put(&b,1,0); put(&b,1,0); put_ue(&b,0); put_ue(&b,0); put_ue(&b,0);
  put(&b,1,0); put(&b,2,0); put_se(&b,0); put_se(&b,0); put_se(&b,0); put(&b,1,1); put(&b,1,0); put(&b,1,0);
  put_trailing(&b); write_nal(3,8,&b); free(b.buf);
}

static int search_range=16;
static void encode_frame(int idr){
  BW b; bw_init(&b);
  int qp = idr ? qpI : qpP;
  put_ue(&b,0); put_ue(&b, idr?7:5); put_ue(&b,0); put(&b,8,frame_num&255);
  if(idr) put_ue(&b,idr_id);
  if(!idr){ put(&b,1,0); put(&b,1,0); }
  if(idr){ put(&b,1,0); put(&b,1,0); } else put(&b,1,0);
  put_se(&b,qp-26); put_ue(&b,1);
  int skip=0;
  for(int my=0;my<MBH;my++) for(int mx=0;mx<MBW;mx++){
    int idx=my*MBW+mx;
    MBRes ri; int im,icm;
    if(idr){
      try_intra(mx,my,qp,&ri,&im,&icm);
      put_ue(&b, 1+im+4*ri.cbpC+12*(ri.cbpL?1:0));
      put_ue(&b,icm); put_se(&b,0);
      write_residual(&b,mx,my,1,&ri); store_rec(mx,my,&ri); mbref[idx]=-1; mvqx[idx]=mvqy[idx]=0;
      continue;
    }
    const uint8_t*sy=cur.y+my*16*PW+mx*16, *su=cur.u+my*8*(PW/2)+mx*8, *sv=cur.v+my*8*(PW/2)+mx*8;
    uint8_t py[256],pu[64],pv[64];
    /* 1) skip candidate */
    int sx,syv; skip_mv(mx,my,&sx,&syv);
    pred_inter(mx,my,sx,syv,py,pu,pv);
    MBRes rs; code_luma(sy,PW,py,qp,0,&rs); code_chroma(su,sv,PW/2,pu,pv,qp,0,&rs);
    if(rs.cbpL==0 && rs.cbpC==0){
      /* skip is exact under our quantiser */
      skip++; clear_nz(mx,my); mbref[idx]=0; mvqx[idx]=sx; mvqy[idx]=syv;
      for(int y=0;y<16;y++) memcpy(rec.y+(my*16+y)*PW+mx*16,py+y*16,16);
      for(int y=0;y<8;y++){ memcpy(rec.u+(my*8+y)*(PW/2)+mx*8,pu+y*8,8); memcpy(rec.v+(my*8+y)*(PW/2)+mx*8,pv+y*8,8); }
      continue;
    }
    /* 2) motion search (integer, full search small window around 0 and pred) */
    int pmx,pmy; mv_pred(mx,my,&pmx,&pmy);
    int bestx=0,besty=0,bests=1<<30;
    int cands[3][2]={{0,0},{(pmx>>2)<<2,(pmy>>2)<<2},{(sx>>2)<<2,(syv>>2)<<2}};
    for(int c=0;c<3;c++){ int cx=cands[c][0]>>2, cy=cands[c][1]>>2;
      for(int dy=-search_range;dy<=search_range;dy++) for(int dx=-search_range;dx<=search_range;dx++){
        int vx=cx+dx, vy=cy+dy; int rx=mx*16+vx, ry=my*16+vy;
        if(rx<0||ry<0||rx+16>PW||ry+16>PH) continue;
        int s=sad(sy,PW,ref.y+ry*PW+rx,PW,16,16);
        int mvcost = (abs(vx*4-pmx)+abs(vy*4-pmy))/2;
        if(s+mvcost<bests){ bests=s+mvcost; bestx=vx*4; besty=vy*4; } }
      if(c==0 && bests<64) break; }
    pred_inter(mx,my,bestx,besty,py,pu,pv);
    MBRes rp; code_luma(sy,PW,py,qp,0,&rp); code_chroma(su,sv,PW/2,pu,pv,qp,0,&rp);
    int dist=ssd(sy,PW,rp.recY,16,16,16)+ssd(su,PW/2,rp.recU,8,8,8)+ssd(sv,PW/2,rp.recV,8,8,8);
    int mvbits = 2 + 2*(abs(bestx-pmx)>0) + 2*(abs(besty-pmy)>0);
    rp.cost = dist + lambda_tab[qp]*(count_bits_inter(&rp)+mvbits);
    try_intra(mx,my,qp,&ri,&im,&icm);
    ri.cost += lambda_tab[qp]*4;
    put_ue(&b,skip); skip=0;
    if(ri.cost < rp.cost){
      put_ue(&b, 5+1+im+4*ri.cbpC+12*(ri.cbpL?1:0));
      put_ue(&b,icm); put_se(&b,0);
      write_residual(&b,mx,my,1,&ri); store_rec(mx,my,&ri); mbref[idx]=-1; mvqx[idx]=mvqy[idx]=0;
    } else {
      put_ue(&b,0);                       /* P_L0_16x16 */
      put_se(&b,bestx-pmx); put_se(&b,besty-pmy);
      /* map cbp into subset {0,16,32,15,47} */
      int cbpC=rp.cbpC, cbpL=rp.cbpL;
      if(cbpL && cbpC==1){ cbpC=2; rp.cbpC=2; }
      int cbp=cbpL|(cbpC<<4); int code=-1; for(int i=0;i<48;i++) if(golomb_to_inter_cbp[i]==cbp){code=i;break;}
      put_ue(&b,code);
      if(cbp) put_se(&b,0);
      write_residual(&b,mx,my,0,&rp); store_rec(mx,my,&rp);
      mbref[idx]=0; mvqx[idx]=bestx; mvqy[idx]=besty;
    }
  }
  if(skip) put_ue(&b,skip);
  put_trailing(&b);
  write_nal(3, idr?5:1, &b); free(b.buf);
}

static void pad_plane(uint8_t*p,int w,int h,int pw,int ph){
  for(int y=0;y<h;y++) for(int x=w;x<pw;x++) p[y*pw+x]=p[y*pw+w-1];
  for(int y=h;y<ph;y++) memcpy(p+y*pw,p+(h-1)*pw,pw);
}

int main(int argc,char**argv){
  if(argc<5){ fprintf(stderr,"usage: h264enc W H out.h264 out.idx [-q qpI qpP] [-g gop] [-i420] [-recon f]\n"); return 1; }
  W=atoi(argv[1]); H=atoi(argv[2]); int i420=0; const char*recf=NULL;
  for(int i=5;i<argc;i++){
    if(!strcmp(argv[i],"-q")){ qpI=atoi(argv[++i]); qpP=atoi(argv[++i]); }
    else if(!strcmp(argv[i],"-g")) gop=atoi(argv[++i]);
    else if(!strcmp(argv[i],"-i420")) i420=1;
    else if(!strcmp(argv[i],"-recon")) recf=argv[++i];
    else if(!strcmp(argv[i],"-sr")) search_range=atoi(argv[++i]);
  }
  MBW=(W+15)/16; MBH=(H+15)/16; PW=MBW*16; PH=MBH*16;
  size_t ysz=(size_t)PW*PH;
  Pic*ps[3]={&cur,&rec,&ref}; for(int i=0;i<3;i++){ ps[i]->y=calloc(ysz*3/2,1); ps[i]->u=ps[i]->y+ysz; ps[i]->v=ps[i]->u+ysz/4; }
  nzY=calloc(MBW*4*MBH*4,1); nzC=calloc(2*MBW*2*MBH*2,1);
  mvqx=calloc(MBW*MBH,sizeof(int)); mvqy=calloc(MBW*MBH,sizeof(int)); mbref=calloc(MBW*MBH,1);
  fout=fopen(argv[3],"wb"); FILE*fidx=fopen(argv[4],"w"); FILE*frec=recf?fopen(recf,"wb"):NULL;
  size_t insz = i420 ? (size_t)W*H*3/2 : (size_t)W*H*4;
  uint8_t*in=malloc(insz);
  /* static dither pattern (blue-ish noise via hash) */
  int n=0;
  while(fread(in,1,insz,stdin)==insz){
    if(i420){
      for(int y=0;y<H;y++) memcpy(cur.y+y*PW,in+y*W,W);
      for(int y=0;y<H/2;y++){ memcpy(cur.u+y*(PW/2),in+W*H+y*(W/2),W/2); memcpy(cur.v+y*(PW/2),in+W*H*5/4+y*(W/2),W/2); }
    } else {
      /* RGBA -> BT.709 limited range, 2x2 chroma average, static dither */
      for(int y=0;y<H;y++) for(int x=0;x<W;x++){ const uint8_t*p=in+((size_t)y*W+x)*4;
        uint32_t hsh=(uint32_t)(x*73856093u ^ y*19349663u); hsh^=hsh>>13; hsh*=0x5bd1e995u; hsh^=hsh>>15;
        float d=((hsh&255)/255.0f + ((hsh>>8)&255)/255.0f - 1.0f)*0.5f;
        float Yf=16.0f + (65.481f*p[0]+220.2185f*0 + 0.0f)/255.0f; (void)Yf;
        float yy = 16.0f + 219.0f*(0.2126f*p[0]+0.7152f*p[1]+0.0722f*p[2])/255.0f + d;
        int yi=(int)(yy+0.5f); cur.y[y*PW+x]=yi<16?16:yi>235?235:yi; }
      for(int y=0;y<H/2;y++) for(int x=0;x<W/2;x++){
        float r=0,g=0,bb=0; for(int k=0;k<4;k++){ const uint8_t*p=in+((size_t)(2*y+(k>>1))*W+2*x+(k&1))*4; r+=p[0]; g+=p[1]; bb+=p[2]; }
        r/=4; g/=4; bb/=4; float Y=0.2126f*r+0.7152f*g+0.0722f*bb;
        int cb=(int)(128.0f + 224.0f*(bb-Y)/1.8556f/255.0f + 0.5f), cr=(int)(128.0f + 224.0f*(r-Y)/1.5748f/255.0f + 0.5f);
        cur.u[y*(PW/2)+x]=cb<16?16:cb>240?240:cb; cur.v[y*(PW/2)+x]=cr<16?16:cr>240?240:cr; }
    }
    pad_plane(cur.y,W,H,PW,PH); pad_plane(cur.u,W/2,H/2,PW/2,PH/2); pad_plane(cur.v,W/2,H/2,PW/2,PH/2);
    int idr = (n%gop)==0;
    frame_bytes=0;
    if(idr){ frame_num=0; write_sps_pps(); }
    encode_frame(idr);
    if(idr) idr_id^=1;
    frame_num=(frame_num+1)&255;
    fprintf(fidx,"%zu %d\n",frame_bytes,idr);
    if(frec){ for(int y=0;y<H;y++) fwrite(rec.y+y*PW,1,W,frec); for(int y=0;y<H/2;y++) fwrite(rec.u+y*(PW/2),1,W/2,frec); for(int y=0;y<H/2;y++) fwrite(rec.v+y*(PW/2),1,W/2,frec); }
    /* rec -> ref */
    Pic t=ref; ref=rec; rec=t;
    n++;
    if(n%30==0){ fprintf(stderr,"\rframe %d",n); }
  }
  fprintf(stderr,"\nencoded %d frames\n",n);
  fclose(fout); fclose(fidx); if(frec) fclose(frec);
  return 0;
}
