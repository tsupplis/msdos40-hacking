/* File operations with allocation and I/O failures, without terminal input. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dos.h>
static int allocations, fail_alloc, fail_close, fail_write;
static int fail_read;
static int test_getc(FILE *f)
{
    if (fail_read && --fail_read == 0) {
        f->_flag |= _IOERR;
        return EOF;
    }
    return getc(f);
}
static void *test_malloc(size_t n)
{
    if (++allocations == fail_alloc)
        return NULL;
    return malloc(n);
}
static void *test_realloc(void *p, size_t n)
{
    if (++allocations == fail_alloc)
        return NULL;
    return realloc(p, n);
}
static int test_close(FILE *f)
{
    int result = fclose(f);
    if (fail_close && --fail_close == 0)
        return EOF;
    return result;
}
static size_t test_write(const void *p, size_t size, size_t n, FILE *f)
{
    if (fail_write) {
        fail_write = 0;
        return 0;
    }
    return fwrite(p, size, n, f);
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
    if (!ok) {
        printf("FAIL: %s\n", message);
        exit(1);
    }
}

static void clipboardFailures(void)
{
    selection s;
    int n;
    E.ay = E.ax = E.cy = 0;
    E.cx = 1;
    E.marked = 1;
    s = selected();
    need(copySelection(s, 0), "initial clipboard");
    E.ay = 1;
    E.ax = 2;
    s = selected();
    /* Two rows copied, one replacement row prepared. */
    for (n = 1; n <= 5; ++n) {
        fail_alloc = n;
        allocations = 0;
        need(!copySelection(s, 1), "cut allocation refused");
        need(!E.dirty && E.marked && !strcmp(E.row[0].chars, "first") &&
                 !strcmp(E.row[1].chars, "last"),
             "cut kept text and selection");
        need(clipboard.count == 1 && !strcmp(clipboard.rows[0].chars, "f"),
             "cut kept prior clipboard");
    }
    fail_alloc = 0;
    need(copySelection(s, 1), "multiline cut");
    need(E.numrows == 1 && !strcmp(E.row[0].chars, "fst"), "cut contents");
    s = selected();
    for (n = 1; n <= 3; ++n) {
        fail_alloc = n;
        allocations = 0;
        need(!replaceBlock(s, clipboard.rows, clipboard.count), "paste refused");
        need(E.numrows == 1 && !strcmp(E.row[0].chars, "fst"), "paste kept text");
    }
    fail_alloc = 0;
    need(replaceBlock(s, clipboard.rows, clipboard.count), "paste after failure");
    need(editorSave(), "save restored file");
}

static void diskText(const char *text)
{
    FILE *fp = fopen("B:EDIT.TXT", "wb");
    need(fp != NULL, "open external writer");
    need(fputs(text, fp) != EOF && fclose(fp) == 0, "external write");
}

static void expectText(const char *text)
{
    char buffer[64];
    FILE *fp = fopen("B:EDIT.TXT", "rb");
    unsigned length = strlen(text);
    need(fp != NULL && fread(buffer, 1, sizeof(buffer), fp) == length &&
             !memcmp(buffer, text, length) && !ferror(fp),
         "disk contents");
    need(!fclose(fp), "close sample");
}

static void saveChanges(void)
{
    diskText("other");
    need(editorSave(), "clean save");
    expectText("other");
    need(editorInsertChar('x'), "edit");
    E.dirty = 1;
    need(!editorSave() && E.confirm_save && E.dirty, "changed on disk");
    expectText("other");
    diskText("third");
    need(!editorSave() && E.confirm_save && E.dirty, "confirmation version changed");
    expectText("third");
    need(editorSave() && !E.dirty, "confirm latest version");
    expectText("xfirst");
    need(editorInsertChar('y'), "second edit");
    E.dirty = 1;
    need(editorSave(), "new saved baseline");
    expectText("xyfirst");
    need(!unlink("B:EDIT.TXT"), "external deletion");
    E.dirty = 1;
    need(!editorSave() && E.confirm_save, "deleted since load");
    need(editorSave(), "confirm recreation");
    expectText("xyfirst");
}

static void undoFailures(void)
{
    int i;
    E.cx = E.row[0].size;
    for (i = 1; i <= 4; ++i) {
        fail_alloc = i;
        allocations = 0;
        need(!applyEdit(DEL_KEY, selected()), "failed join");
        need(!history_count && E.numrows == 2 && !E.dirty, "failed edit kept history");
    }
    fail_alloc = 0;
    need(applyEdit(DEL_KEY, selected()), "join");
    need(!strcmp(E.row[0].chars, "firstlast"), "joined contents");
    for (i = 1; i <= 3; ++i) {
        fail_alloc = i;
        allocations = 0;
        need(!undoEdit(), "failed undo");
        need(history_count == 1 && E.numrows == 1 && E.dirty &&
                 !strcmp(E.row[0].chars, "firstlast"),
             "failed undo kept edit and history");
    }
    fail_alloc = 0;
    need(undoEdit(), "retry undo");
    need(!history_count && !E.dirty && E.cx == 5 && !E.cy && E.numrows == 2 &&
             E.row[0].eol == 2,
         "restored line break and cursor");
    need(applyEdit(13, selected()) && undoEdit(), "undo line split");
    need(applyEdit(8, selected()) && undoEdit(), "undo backspace");
    need(!strcmp(E.row[0].chars, "first") && !strcmp(E.row[1].chars, "last"),
         "original text after undo");
}

int main(int argc, char **argv)
{
    int mode, result;
    need(argc == 2, "mode argument");
    mode = atoi(argv[1]);
    if (mode >= 10 && mode <= 13)
        fail_alloc = mode - 9;
    if (mode == 16)
        fail_close = 1;
    if (mode == 17)
        fail_read = 10;
    result = editorOpen("B:EDIT.TXT", 1);
    if (mode == 39) {
        int n;
        need(result && E.numrows == 2, "replace source");
        for (n = 1; n <= 4; ++n) {
            allocations = 0;
            fail_alloc = n;
            need(!replaceAll("a", "bb", NULL), "allocation failure");
            need(!E.dirty && !history_count && !strcmp(E.row[0].chars, "aa") &&
                     !strcmp(E.row[1].chars, "a"),
                 "replace failure atomic");
        }
        fail_alloc = 0;
        need(replaceAll("a", "a", NULL) && !history_count, "identical is no edit");
        need(replaceAll("a", "aa", NULL) && history_count == 1, "one undo entry");
        need(!strcmp(E.row[0].chars, "aaaa") && !strcmp(E.row[1].chars, "aa"),
             "non-overlapping replacements");
        need(undoEdit() && !E.dirty && E.row[0].eol == 2, "restore state");
        need(!strcmp(E.row[0].chars, "aa") && !strcmp(E.row[1].chars, "a"), "restore text");
        need(replaceAll("a", "", NULL) && editorSave(), "save global deletion");
        puts("EDIT PASS");
        return 0;
    }
    if (mode == 40) {
        need(result && !replaceAll("a", "aa", NULL), "oversize row rejected");
        need(!E.dirty && !history_count && !strcmp(E.row[0].chars, "a") &&
                 E.row[1].size == 32766,
             "oversize preserves all rows");
        puts("EDIT PASS");
        return 0;
    }
    if (mode == 38) {
        need(result, "undo source loaded");
        undoFailures();
        puts("EDIT PASS");
        return 0;
    }
    if (mode >= 33 && mode <= 37) {
        int i;
        need(result, "load review fixture");
        switch (mode) {
        case 33:
            saveChanges();
            break;
        case 34:
            for (i = 0; i < 100; ++i) {
                E.cx = i % 2;
                need(editorInsertNewline(), "repeated long line split");
            }
            need(E.numrows == 101 && E.row[100].size == 31950, "split contents");
            E.dirty = 1;
            need(editorSave(), "save split file");
            break;
        case 35:
            need(!_dos_setfileattr("B:EDIT.TXT", _A_RDONLY), "set read-only");
            E.dirty = 1;
            for (i = 0; i < 3; ++i)
                need(!editorSave() && E.dirty && strstr(E.message, "protected"),
                     "protected save");
            need(!_dos_setfileattr("B:EDIT.TXT", 0), "clear read-only");
            need(access("B:FS0000.TMP", 0) != 0, "no temporary on protected save");
            expectText("first");
            break;
        case 36:
            need(editorSave(), "save new empty file");
            expectText("");
            break;
        case 37:
            diskText("appeared");
            need(!editorSave() && E.confirm_save, "new name occupied");
            expectText("appeared");
            need(editorSave(), "confirm replacement of new file");
            expectText("");
            break;
        }
        puts("EDIT PASS");
        return 0;
    }
    if (mode == 31 || mode == 32) {
        selection s;
        need(result, "clipboard source loaded");
        if (mode == 31)
            clipboardFailures();
        else {
            E.marked = 1;
            E.cy = E.numrows - 1;
            E.cx = E.row[E.cy].size;
            s = selected();
            need(copySelection(s, 1) && E.numrows == 1, "large cut");
            s = selected();
            need(replaceBlock(s, clipboard.rows, clipboard.count), "large paste");
            need(editorSave(), "save large paste");
        }
        puts("EDIT PASS");
        return 0;
    }
    if (mode == 30)
        return result ? 0 : 2;
    if (mode >= 10) {
        need(!result, "partial load rejected");
    } else {
        need(result && E.numrows == 2, "complete load");
        need(!strcmp(E.row[1].chars, "last"), "final line");
        E.cx = E.row[0].size;
        allocations = 0;
        fail_alloc = 1;
        need(!editorDelete(), "failed join");
        need(E.numrows == 2 && E.cx == E.row[0].size, "join retained both rows");
        allocations = 0;
        need(!editorInsertChar('x'), "failed insert");
        allocations = 0;
        need(!editorInsertNewline(), "failed split");
        need(!strcmp(E.row[0].chars, "first") && !E.dirty, "original intact");
        memcpy(E.row[0].chars, "saved", 5);
        E.dirty = 1;
        fail_close = mode == 1;
        fail_write = mode == 2;
        allocations = 0;
        fail_alloc = 1;
        result = editorSave();
        need(allocations == 0, "save allocates no document copy");
        need(result == (mode == 0), "save result");
        need((E.dirty != 0) == (mode != 0), "dirty retained on failed save");
    }
    puts("EDIT PASS");
    return 0;
}
