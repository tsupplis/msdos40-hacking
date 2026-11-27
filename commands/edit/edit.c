/* EDIT for MS-DOS, derived from Kilo and its CP/M-86 port.
 *
 * -----------------------------------------------------------------------
 *
 * Copyright (C) 2016 Salvatore Sanfilippo <antirez at gmail dot com>
 *
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 *  *  Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 *
 *  *  Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <io.h>
#include <process.h>
#include "fsave.h"
#include "screen.h"

/* Each allocation fits one segment. The compact model puts row text on the
 * far heap. Display columns are long because tabs can expand eightfold. */
#define MAX_LINE 32766
typedef struct {
    char *chars;
    int size;
    unsigned char eol;     /* 0 at EOF, 1 for LF, 2 for CRLF */
} erow;

static struct {
    erow *row;
    int numrows, cap, cx, cy, top, height, width, dirty, eofmark;
    int matchlen, marked, ax, ay;
    long left;
    char *filename;
    char message[160];
} E;

static int reserveRows(int needed)
{
    unsigned cap;
    erow *rows;
    if (needed <= E.cap) return 1;
    cap = ((unsigned)needed+63U) & ~63U;
    if ((unsigned long)cap*sizeof(erow) > 65520UL) cap = needed;
    if ((unsigned long)cap*sizeof(erow) > 65520UL) return 0;
    rows = realloc(E.row,cap*sizeof(erow));
    if (!rows) return 0;
    E.row = rows;
    E.cap = cap;
    return 1;
}

static int editorInsertRow(int at, const char *s, int len, int eol)
{
    erow fresh;
    fresh.chars = malloc(len+1U);
    if (!fresh.chars) return 0;
    memcpy(fresh.chars,s,len);
    fresh.chars[len] = 0;
    fresh.size = len;
    fresh.eol = (unsigned char)eol;
    if (!reserveRows(E.numrows+1)) { free(fresh.chars); return 0; }
    memmove(E.row+at+1,E.row+at,(E.numrows-at)*sizeof(erow));
    E.row[at] = fresh;
    E.numrows++;
    return 1;
}

/* Read bytes in binary mode. Only a final Ctrl-Z is a DOS EOF marker.
 * Refuse embedded NUL/Ctrl-Z instead of offering a truncated file to save. */
static int editorOpen(char *filename)
{
    FILE *fp;
    char *line = NULL, *p;
    unsigned cap = 0;
    int len = 0, c, ok = 1, eol;
    E.filename = filename;
    fp = fopen(filename,"rb");
    if (!fp) return errno == ENOENT && editorInsertRow(0,"",0,0);
    if (isatty(fileno(fp))) { fclose(fp); return 0; }
    while ((c = fgetc(fp)) != EOF) {
        if (c == 26) {
            E.eofmark = 1;
            ok = fgetc(fp) == EOF;
            break;
        }
        if (!c) { ok = 0; break; }
        if (c == '\n') {
            eol = len && line[len-1] == '\r' ? 2 : 1;
            if (eol == 2) len--;
            if (len > MAX_LINE ||
                !editorInsertRow(E.numrows,line ? line : "",len,eol)) {
                ok = 0; break;
            }
            len = 0;
        } else {
            if (len == MAX_LINE+1) { ok = 0; break; }
            if ((unsigned)len == cap) {
                cap = !cap ? 128 : cap < 16384U ? cap*2 : 32767U;
                p = realloc(line,cap);
                if (!p) { ok = 0; break; }
                line = p;
            }
            line[len++] = (char)c;
        }
    }
    if (ferror(fp)) ok = 0;
    if (fclose(fp)) ok = 0;
    if (ok) ok = len <= MAX_LINE && editorInsertRow(E.numrows,line ? line : "",len,0);
    free(line);
    return ok;
}

static int editorSave(void)
{
    char temporary[FS_NAME];
    FILE *fp = fs_create(temporary,sizeof(temporary),E.filename);
    int i, ok = 1;
    erow *row;
    if (fp) {
        for (i = 0; i < E.numrows && ok; ++i) {
            row = &E.row[i];
            ok = fwrite(row->chars,1,row->size,fp) == (unsigned)row->size;
            if (ok && row->eol)
                ok = fwrite("\r\n"+2-row->eol,1,row->eol,fp) == row->eol;
        }
        if (E.eofmark && putc(26,fp) == EOF) ok = 0;
        if (ferror(fp)) ok = 0;
        if (fclose(fp)) ok = 0;
        if (ok) {
            if (!fs_commit(temporary,E.filename,NULL)) {
                sprintf(E.message,"Save failed. Edited copy: %s",temporary);
                return 0;
            }
            E.dirty = 0;
            strcpy(E.message,"Saved.");
            return 1;
        }
        unlink(temporary);
    }
    strcpy(E.message,"Save failed. Check space and directory permissions.");
    return 0;
}

static int editorInsertChar(int c)
{
    erow *r = &E.row[E.cy];
    char *p;
    if (r->size == MAX_LINE || !(p = realloc(r->chars,r->size+2U))) return 0;
    r->chars = p;
    memmove(p+E.cx+1,p+E.cx,r->size-E.cx+1);
    p[E.cx++] = (char)c;
    r->size++;
    return 1;
}

static int editorInsertNewline(void)
{
    erow *r = &E.row[E.cy];
    if (!editorInsertRow(E.cy+1,r->chars+E.cx,r->size-E.cx,r->eol)) return 0;
    r = &E.row[E.cy++];
    r->size = E.cx;
    r->chars[E.cx] = 0;
    r->eol = 2;
    E.cx = 0;
    return 1;
}

/* Delete forward. Allocate the joined line before removing its successor. */
static int editorDelete(void)
{
    erow *r = &E.row[E.cy], *next;
    char *p;
    if (E.cx < r->size) {
        memmove(r->chars+E.cx,r->chars+E.cx+1,r->size-E.cx);
        r->size--;
    } else {
        next = r+1;
        if (E.cy+1 == E.numrows) return 1;
        if ((long)r->size+next->size > MAX_LINE ||
            !(p = realloc(r->chars,r->size+next->size+1U))) return 0;
        r->chars = p;
        memcpy(p+r->size,next->chars,next->size+1);
        r->size += next->size;
        r->eol = next->eol;
        free(next->chars);
        E.numrows--;
        memmove(next,next+1,(E.numrows-E.cy-1)*sizeof(erow));
    }
    E.dirty = 1;
    return 1;
}

static void editorMoveCursor(int key)
{
    switch (key) {
    case HOME_KEY: E.cx = 0; break;
    case END_KEY: E.cx = E.row[E.cy].size; break;
    case ARROW_LEFT:
        if (E.cx) E.cx--;
        else if (E.cy) E.cx = E.row[--E.cy].size;
        break;
    case ARROW_RIGHT:
        if (E.cx < E.row[E.cy].size) E.cx++;
        else if (E.cy+1 < E.numrows) { E.cy++; E.cx = 0; }
        break;
    case ARROW_UP: if (E.cy) E.cy--; break;
    case ARROW_DOWN: if (E.cy+1 < E.numrows) E.cy++; break;
    case PAGE_UP: E.cy -= E.height; if (E.cy < 0) E.cy = 0; break;
    case PAGE_DOWN: E.cy += E.height; if (E.cy >= E.numrows) E.cy = E.numrows-1; break;
    }
    if (E.cx > E.row[E.cy].size) E.cx = E.row[E.cy].size;
}

typedef struct {
    int y, x, endy, endx;
} selection;

typedef struct {
    erow *rows;
    int count;
} block;

static block clipboard;

static selection selected(void)
{
    selection s;
    s.y = s.endy = E.cy;
    s.x = s.endx = E.cx;
    if (E.marked) {
        if (E.ay < E.cy || (E.ay == E.cy && E.ax < E.cx)) {
            s.y = E.ay;
            s.x = E.ax;
        } else {
            s.endy = E.ay;
            s.endx = E.ax;
        }
    }
    return s;
}

static void freeBlock(block *b)
{
    while (b->count) free(b->rows[--b->count].chars);
    free(b->rows);
    b->rows = NULL;
}

/* Each fragment fits a segment, but the complete clipboard may exceed 64K. */
static int copyBlock(selection s, block *b)
{
    int y, x, end;
    erow *r, *out;
    b->rows = malloc((s.endy-s.y+1)*sizeof(erow));
    if (!b->rows) return 0;
    for (y = s.y; y <= s.endy; ++y) {
        r = E.row+y;
        x = y == s.y ? s.x : 0;
        end = y == s.endy ? s.endx : r->size;
        out = b->rows+b->count;
        out->size = end-x;
        out->chars = malloc(out->size+1U);
        if (!out->chars) { freeBlock(b); return 0; }
        memcpy(out->chars,r->chars+x,out->size);
        out->chars[out->size] = 0;
        out->eol = (unsigned char)(y == s.endy ? 0 : r->eol);
        ++b->count;
    }
    return 1;
}

/* Splice whole rows only after every allocation succeeds. Preserve each
 * copied separator and the original line ending following the replacement. */
static int replaceBlock(selection s, const erow *input, int count)
{
    block fresh;
    int total = E.numrows - (s.endy-s.y+1) + count;
    int i, left, right, cursor = 0;
    erow *out;
    long size;
    if ((unsigned long)total*sizeof(erow) > 65520UL) return 0;
    fresh.count = 0;
    fresh.rows = malloc(count*sizeof(erow));
    if (!fresh.rows) return 0;
    for (i = 0; i < count; ++i) {
        left = i == 0 ? s.x : 0;
        right = i == count-1 ? E.row[s.endy].size-s.endx : 0;
        size = (long)left+input[i].size+right;
        out = fresh.rows+i;
        if (size > MAX_LINE || !(out->chars = malloc((unsigned)size+1))) {
            freeBlock(&fresh);
            return 0;
        }
        cursor = left+input[i].size;
        memcpy(out->chars,E.row[s.y].chars,left);
        memcpy(out->chars+left,input[i].chars,input[i].size);
        memcpy(out->chars+cursor,E.row[s.endy].chars+s.endx,right);
        out->size = (int)size;
        out->chars[out->size] = 0;
        out->eol = i == count-1 ? E.row[s.endy].eol : input[i].eol;
        ++fresh.count;
    }
    if (!reserveRows(total)) { freeBlock(&fresh); return 0; }
    for (i = s.y; i <= s.endy; ++i) free(E.row[i].chars);
    memmove(E.row+s.y+count,E.row+s.endy+1,(E.numrows-s.endy-1)*sizeof(erow));
    memcpy(E.row+s.y,fresh.rows,count*sizeof(erow));
    free(fresh.rows);
    E.numrows = total;
    E.cy = s.y+count-1;
    E.cx = cursor;
    E.marked = 0;
    E.dirty = 1;
    return 1;
}

static int copySelection(selection s, int cut)
{
    block fresh;
    static erow empty = {"",0,0};
    if (s.y == s.endy && s.x == s.endx) {
        strcpy(E.message,"Select text with Shift and a movement key.");
        return 1;
    }
    fresh.count = 0;
    if (!copyBlock(s,&fresh)) return 0;
    if (cut && !replaceBlock(s,&empty,1)) { freeBlock(&fresh); return 0; }
    freeBlock(&clipboard);
    clipboard = fresh;
    strcpy(E.message,cut ? "Cut." : "Copied.");
    return 1;
}

static long nextColumn(long col, char c)
{
    return c == '\t' ? (col | 7L)+1 : col+1;
}

static void editorRefreshScreen(void)
{
    char line[81], status[100];
    long cursor = 0, col, next;
    int i, y, n, first, last;
    selection s;
    int start, end, ry;
    erow *r = &E.row[E.cy];
    s = selected();
    for (i = 0; i < E.cx; i++) cursor = nextColumn(cursor,r->chars[i]);
    if (cursor < E.left) E.left = cursor;
    if (cursor >= E.left+E.width) E.left = cursor-E.width+1;
    if (E.cy < E.top) E.top = E.cy;
    if (E.cy >= E.top+E.height) E.top = E.cy-E.height+1;
    for (y = 0; y < E.height; y++) {
        n = first = last = 0;
        if (y+E.top >= E.numrows) line[n++] = '~';
        else {
            ry = y+E.top;
            r = &E.row[ry];
            start = ry == s.y ? s.x : 0;
            end = ry == s.endy ? s.endx : r->size;
            if (ry < s.y || ry > s.endy) end = 0;
            if (ry == E.cy && E.matchlen) {
                start = E.cx;
                end = start+E.matchlen;
            }
            col = 0;
            for (i = 0; i < r->size && n < E.width; i++) {
                next = nextColumn(col,r->chars[i]);
                if (i == start) first = n;
                if (next <= E.left) { col = next; continue; }
                while (col < next && n < E.width) {
                    if (col >= E.left)
                        line[n++] = (char)(r->chars[i] == '\t' ? ' ' :
                            (unsigned char)r->chars[i] < 32 ? '?' : r->chars[i]);
                    col++;
                }
                if (i >= start && i < end) last = n;
            }
            if (ry >= s.y && ry < s.endy && i == r->size && col >= E.left && n < E.width) {
                if (start == r->size) first = n;
                last = E.width;
            }
        }
        screenLine(y,line,n,7,first,last);
    }
    sprintf(status,"EDIT %.32s%s  Ln %d/%d Col %ld",E.filename,
            E.dirty ? " *" : "",E.cy+1,E.numrows,cursor+1);
    screenLine(E.height,status,strlen(status),0x70,0,0);
    screenLine(E.height+1,E.message,strlen(E.message),7,0,0);
    screenCursor(E.cy-E.top,(int)(cursor-E.left));
}

/* All lines fit the 40-column display. The caller redraws its own view. */
static void editorHelp(void)
{
    static const char *lines[] = {
        "EDIT Help",
        "",
        "Arrows          Move cursor",
        "Home / End      Start / end of line",
        "PgUp / PgDn     Move one screen",
        "Enter           Split line",
        "Backspace / Del Delete left / at cursor",
        "",
        "Shift+movement  Extend selection",
        "Esc             Clear selection",
        "Ctrl-C / Ctrl-X Copy / cut selection",
        "Ctrl-V          Paste at cursor or",
        "                replace selection",
        "",
        "Ctrl-F          Find exact text",
        "Ctrl-Shift-F    Find ignoring case",
        "In Find: arrows cycle matching lines.",
        "Enter accepts. Esc restores position.",
        "",
        "Ctrl-S          Save file",
        "Ctrl-Q          Quit (twice if unsaved)"
    };
    int row, key;
    const char *line;
    for (row = 0; row < E.height+1; ++row) {
        line = (unsigned)row < sizeof(lines)/sizeof(lines[0]) ? lines[row] : (const char *)"";
        screenLine(row,line,strlen(line),row == 0 ? 0x70 : 7,0,0);
    }
    line = "Esc or F1 to return";
    screenLine(row,line,strlen(line),0x70,0,0);
    screenCursor(row,0);
    do {
        key = editorReadKey();
    } while (key != 27 && key != HELP_KEY);
}

/* Incremental literal search. Arrow keys cycle matching rows in either
 * direction; Escape restores the entry position. */
static char *findFolded(char *text, const char *query, const unsigned char *fold)
{
    unsigned i;
    for (; *text; ++text) {
        for (i = 0; query[i]; ++i)
            if (!text[i] || fold[(unsigned char)text[i]] != fold[(unsigned char)query[i]]) break;
        if (!query[i]) return text;
    }
    return NULL;
}

static void editorFind(int folded)
{
    char query[65], *match;
    int len = 0, x = E.cx, y = E.cy, row = y, step, i, c;
    long left = E.left;
    int top = E.top;
    unsigned char fold[256];
    if (folded) caseTable(fold);
    query[0] = 0;
    for (;;) {
        sprintf(E.message,folded ? "Find (ignore case): %s" : "Find: %s",query);
        editorRefreshScreen();
        c = editorReadKey();
        if (c == HELP_KEY) { editorHelp(); continue; }
        if (c == 27 || c == 13) break;
        step = 1;
        if (c == ARROW_UP || c == ARROW_LEFT) { step = -1; row--; }
        else if (c == ARROW_DOWN || c == ARROW_RIGHT) row++;
        else {
            if (c == 8 && len) len--;
            else if (c >= 32 && c <= 255 && len < 64) query[len++] = (char)c;
            else continue;
            query[len] = 0;
            row = y;
        }
        E.matchlen = 0;
        for (i = 0; len && i < E.numrows; i++,row += step) {
            if (row < 0) row = E.numrows-1;
            if (row >= E.numrows) row = 0;
            match = folded ? findFolded(E.row[row].chars,query,fold) : strstr(E.row[row].chars,query);
            if (match) { E.matchlen = len; E.cy = row; E.cx = match-E.row[row].chars; break; }
        }
    }
    E.matchlen = 0;
    if (c == 27) { E.cx = x; E.cy = y; E.left = left; E.top = top; }
    E.message[0] = 0;
}

static void editorLoop(void)
{
    int c, confirm = 0, ok, x, y;
    selection s;
    char ch;
    erow insert[2];
    strcpy(E.message,"F1 Help  Ctrl-S Save  Ctrl-F Find  Ctrl-Q Quit");
    for (;;) {
        editorRefreshScreen();
        c = editorReadKey();
        if (c == 17) {
            if (!E.dirty || confirm) return;
            strcpy(E.message,"Unsaved changes. Press Ctrl-Q again to discard.");
            confirm = 1;
            continue;
        }
        confirm = 0;
        ok = 1;
        s = selected();
        if (c & SELECT_KEY) {
            if (!E.marked) { E.ax = E.cx; E.ay = E.cy; E.marked = 1; }
            editorMoveCursor(c & ~SELECT_KEY);
            continue;
        }
        if ((s.y != s.endy || s.x != s.endx) &&
            (c == 8 || c == DEL_KEY || c == 13 || c == 9 || (c >= 32 && c <= 255))) {
            ch = (char)c;
            insert[0].chars = &ch;
            insert[0].size = c == 9 || (c >= 32 && c <= 255);
            insert[0].eol = 2;
            insert[1] = insert[0];
            ok = replaceBlock(s,insert,c == 13 ? 2 : 1);
        } else switch (c) {
        case 3: case 24: ok = copySelection(s,c == 24); break;
        case 22:
            if (clipboard.count) ok = replaceBlock(s,clipboard.rows,clipboard.count);
            else strcpy(E.message,"Clipboard is empty.");
            break;
        case 27: E.marked = 0; break;
        case HELP_KEY: editorHelp(); break;
        case 19: editorSave(); break;
        case 6: case FIND_FOLDED: E.marked = 0; editorFind(c == FIND_FOLDED); break;
        case 13: E.marked = 0; ok = editorInsertNewline(); if (ok) E.dirty = 1; break;
        case 8:
            E.marked = 0;
            x = E.cx; y = E.cy;
            editorMoveCursor(ARROW_LEFT);
            if (x != E.cx || y != E.cy) ok = editorDelete();
            if (!ok) { E.cx = x; E.cy = y; }
            break;
        case DEL_KEY: E.marked = 0; ok = editorDelete(); break;
        default:
            E.marked = 0;
            if (c >= ARROW_LEFT) editorMoveCursor(c);
            else if (c == 9 || (c >= 32 && c <= 255)) {
                ok = editorInsertChar(c);
                if (ok) E.dirty = 1;
            }
        }
        if (!ok) strcpy(E.message,"Edit refused. Line limit or insufficient memory.");
    }
}

int main(int argc, char **argv)
{
    int status;
    if (argc == 2 && !strcmp(argv[1],"/?")) {
        status = spawnlp(P_WAIT,"HELP.COM","HELP","EDIT",NULL);
        if (status >= 0) return status;
        fputs("No help available\n",stderr);
        return 1;
    }
    if (argc != 2 || !*argv[1] || strpbrk(argv[1],"/*?\"") || strlen(argv[1]) >= FS_NAME) {
        fputs(argc == 1 ? "EDIT: Required parameters missing.\n" :
              "EDIT: Invalid parameter.\n",stderr);
        return 1;
    }
    if (!editorOpen(argv[1])) {
        fputs("EDIT: Cannot load complete text file.\n",stderr);
        return 1;
    }
    if (!isatty(0) || !isatty(1) || !screenOpen(&E.height,&E.width)) {
        fputs("EDIT: PC text console required.\n",stderr);
        return 1;
    }
    editorLoop();
    screenClose();
    return 0;
}
