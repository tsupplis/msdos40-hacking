/* File operations with allocation and I/O failures, without terminal input. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static int allocations, fail_alloc, fail_close, fail_write;
static int fail_read;
static int test_getc(FILE *f)
{
    if (fail_read && --fail_read==0) { f->_flag |= _IOERR; return EOF; }
    return getc(f);
}
static void *test_malloc(size_t n)
{
    if (++allocations==fail_alloc) return NULL;
    return malloc(n);
}
static void *test_realloc(void *p, size_t n)
{
    if (++allocations==fail_alloc) return NULL;
    return realloc(p,n);
}
static int test_close(FILE *f)
{
    int result = fclose(f);
    if (fail_close && --fail_close==0) return EOF;
    return result;
}
static size_t test_write(const void *p, size_t size, size_t n, FILE *f)
{
    if (fail_write) { fail_write=0; return 0; }
    return fwrite(p,size,n,f);
}
#define malloc test_malloc
#define realloc test_realloc
#define fclose test_close
#define fwrite test_write

#define fgetc test_getc
#define main edit_main
#include "edit.c"
#undef main
#undef malloc
#undef realloc
#undef fclose
#undef fwrite


static void need(int ok, char *message)
{
    if (!ok) { printf("FAIL: %s\n",message); exit(1); }
}

static void clipboardFailures(void)
{
    selection s;
    int n;
    E.ay = E.ax = E.cy = 0;
    E.cx = 1;
    E.marked = 1;
    s = selected();
    need(copySelection(s,0),"initial clipboard");
    E.ay = 1; E.ax = 2;
    s = selected();
    /* Two rows copied, one replacement row prepared. */
    for (n = 1; n <= 5; ++n) {
        fail_alloc = n; allocations = 0;
        need(!copySelection(s,1),"cut allocation refused");
        need(!E.dirty && E.marked && !strcmp(E.row[0].chars,"first") &&
             !strcmp(E.row[1].chars,"last"),"cut kept text and selection");
        need(clipboard.count == 1 && !strcmp(clipboard.rows[0].chars,"f"),
             "cut kept prior clipboard");
    }
    fail_alloc = 0;
    need(copySelection(s,1),"multiline cut");
    need(E.numrows == 1 && !strcmp(E.row[0].chars,"fst"),"cut contents");
    s = selected();
    for (n = 1; n <= 3; ++n) {
        fail_alloc = n; allocations = 0;
        need(!replaceBlock(s,clipboard.rows,clipboard.count),"paste refused");
        need(E.numrows == 1 && !strcmp(E.row[0].chars,"fst"),"paste kept text");
    }
    fail_alloc = 0;
    need(replaceBlock(s,clipboard.rows,clipboard.count),"paste after failure");
    need(editorSave(),"save restored file");
}

int main(int argc, char **argv)
{
    int mode, result;
    need(argc==2,"mode argument");
    mode=atoi(argv[1]);
    if (mode >= 10 && mode <= 13) fail_alloc = mode-9;
    if (mode == 16) fail_close = 1;
    if (mode == 17) fail_read = 10;
    result = editorOpen("B:EDIT.TXT");
    if (mode == 31 || mode == 32) {
        selection s;
        need(result,"clipboard source loaded");
        if (mode == 31) clipboardFailures();
        else {
            E.marked = 1;
            E.cy = E.numrows-1; E.cx = E.row[E.cy].size;
            s = selected();
            need(copySelection(s,1) && E.numrows == 1,"large cut");
            s = selected();
            need(replaceBlock(s,clipboard.rows,clipboard.count),"large paste");
            need(editorSave(),"save large paste");
        }
        puts("EDIT PASS");
        return 0;
    }
    if (mode == 30) return result ? 0 : 2;
    if (mode >= 10) {
        need(!result,"partial load rejected");
    } else {
        need(result && E.numrows==2,"complete load");
        need(!strcmp(E.row[1].chars,"last"),"final line");
        E.cx=E.row[0].size;
        allocations=0; fail_alloc=1;
        need(!editorDelete(),"failed join");
        need(E.numrows==2 && E.cx==E.row[0].size,"join retained both rows");
        allocations=0;
        need(!editorInsertChar('x'),"failed insert");
        allocations=0;
        need(!editorInsertNewline(),"failed split");
        need(!strcmp(E.row[0].chars,"first") && !E.dirty,"original intact");
        memcpy(E.row[0].chars,"saved",5);
        E.dirty=1;
        fail_close=mode==1;
        fail_write=mode==2;
        allocations=0; fail_alloc=1;
        result=editorSave();
        need(allocations==0,"save allocates no document copy");
        need(result==(mode==0),"save result");
        need((E.dirty!=0)==(mode!=0),"dirty retained on failed save");
    }
    puts("EDIT PASS");
    return 0;
}
