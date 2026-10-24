/* Minimal host for the game's real Berry code; device services are mocked. */
#include "berry.h"
#include "be_vm.h"
#include <time.h>
#include <stdio.h>
#include <stdlib.h>
static unsigned frame[16][52];
static int px(bvm *vm) { int x=be_toint(vm,1),y=be_toint(vm,2); if(x>=0&&x<52&&y>=0&&y<16) frame[y][x]=(unsigned)be_toint(vm,3); be_return_nil(vm); }
static void put(int x,int y,unsigned c){if(x>=0&&x<52&&y>=0&&y<16)frame[y][x]=c;}
static int clear_frame(bvm *vm){for(int y=0;y<16;y++)for(int x=0;x<52;x++)frame[y][x]=0;be_return_nil(vm);}
static int rectangle(bvm *vm){int x=be_toint(vm,1),y=be_toint(vm,2),w=be_toint(vm,3),h=be_toint(vm,4);unsigned c=be_toint(vm,5);for(int yy=y;yy<y+h;yy++)for(int xx=x;xx<x+w;xx++)put(xx,yy,c);be_return_nil(vm);}
static int draw_line(bvm *vm){int x=be_toint(vm,1),y=be_toint(vm,2),x2=be_toint(vm,3),y2=be_toint(vm,4);unsigned c=be_toint(vm,5);int dx=abs(x2-x),sx=x<x2?1:-1,dy=-abs(y2-y),sy=y<y2?1:-1,err=dx+dy;for(;;){put(x,y,c);if(x==x2&&y==y2)break;int e=2*err;if(e>=dy){err+=dy;x+=sx;}if(e<=dx){err+=dx;y+=sy;}}be_return_nil(vm);}
static int circle(bvm *vm){int x=be_toint(vm,1),y=be_toint(vm,2),r=be_toint(vm,3);unsigned c=be_toint(vm,4);for(int yy=-r;yy<=r;yy++)for(int xx=-r;xx<=r;xx++)if(xx*xx+yy*yy<=r*r)put(x+xx,y+yy,c);be_return_nil(vm);}
static int ins(bvm *vm){be_pushint(vm,vm->counter_ins);be_return(vm);}
static int heap(bvm *vm){be_pushint(vm,vm->gc.usage);be_return(vm);}
static int wall_us(bvm *vm){struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);be_pushint(vm,(bint)((t.tv_sec%1000)*1000000+t.tv_nsec/1000));be_return(vm);}
static int dump(bvm *vm) { printf("FRAME "); for(int y=0;y<16;y++)for(int x=0;x<52;x++)printf("%06x",frame[y][x]&0xffffff); puts(""); be_return_nil(vm); }
static int run(bvm *vm,const char *path,int keep) {
 FILE *f=fopen(path,"rb"); if(!f){perror(path);return 1;} fseek(f,0,SEEK_END); long n=ftell(f); rewind(f); char *s=malloc(n+1); fread(s,1,n,f);s[n]=0;fclose(f);
 int err=be_loadbuffer(vm,path,s,n);free(s);if(!err)err=be_pcall(vm,0);
 if(err){fprintf(stderr,"%s: %s: %s\n",path,be_tostring(vm,-2),be_tostring(vm,-1));return 1;}
 if(keep)be_setglobal(vm,"game");be_pop(vm,be_top(vm));return 0;
}
int main(int argc,char **argv){bvm *vm=be_vm_new();be_regfunc(vm,"pixel",px);be_regfunc(vm,"dump_frame",dump);be_regfunc(vm,"clear",clear_frame);be_regfunc(vm,"rect_fill",rectangle);be_regfunc(vm,"line",draw_line);be_regfunc(vm,"circle_fill",circle);be_regfunc(vm,"instructions",ins);be_regfunc(vm,"heap_bytes",heap);be_regfunc(vm,"wall_us",wall_us);for(int i=1;i<argc;i++)if(run(vm,argv[i],i==2)){be_vm_delete(vm);return 1;}be_vm_delete(vm);return 0;}
void *awtrix_script_heap_alloc(size_t n){return malloc(n);}
void *awtrix_script_heap_realloc(void *p,size_t n){return realloc(p,n);}
void awtrix_script_heap_free(void *p){free(p);}
