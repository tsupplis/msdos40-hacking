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
#define PROMPT_LIMIT 64
typedef struct {
    char *chars;
    int size;
    unsigned char eol; /* 0 at EOF, 1 for LF, 2 for CRLF */
} erow;

typedef struct {
    erow *row;
    int numrows, cap, cx, cy, top, height, width, dirty, eofmark;
    int matchlen, marked, ax, ay;
    long left;
    file_stamp saved, observed;
    int confirm_save, needs_crlf;
    char filename[FS_NAME];
    char message[160];
} editor_state;
static editor_state E;

static int reserveRows(int needed)
{
    unsigned cap;
    erow *rows;
    if (needed <= E.cap)
        return 1;
    cap = ((unsigned)needed + 63U) & ~63U;
    if ((unsigned long)cap * sizeof(erow) > 65520UL)
        cap = needed;
    if ((unsigned long)cap * sizeof(erow) > 65520UL)
        return 0;
    rows = realloc(E.row, cap * sizeof(erow));
    if (!rows)
        return 0;
    E.row = rows;
    E.cap = cap;
    return 1;
}

static int editorInsertRow(int at, const char *s, int len, int eol)
{
    erow fresh;
    fresh.chars = malloc(len + 1U);
    if (!fresh.chars)
        return 0;
    memcpy(fresh.chars, s, len);
    fresh.chars[len] = 0;
    fresh.size = len;
    fresh.eol = (unsigned char)eol;
    if (!reserveRows(E.numrows + 1)) {
        free(fresh.chars);
        return 0;
    }
    memmove(E.row + at + 1, E.row + at, (E.numrows - at) * sizeof(erow));
    E.row[at] = fresh;
    E.numrows++;
    return 1;
}

static const char *ending(int eol) { return eol == 2 ? "\r\n" : "\n"; }

static void countRow(file_stamp *stamp, const erow *row)
{
    fs_count(stamp, row->chars, row->size);
    fs_count(stamp, ending(row->eol), row->eol);
}

/* Read bytes in binary mode. Only a final Ctrl-Z is a DOS EOF marker.
 * Refuse embedded NUL/Ctrl-Z instead of offering a truncated file to save. */
static int editorOpen(char *filename, int allow_new)
{
    FILE *fp;
    char *line = NULL, *p;
    unsigned cap = 0;
    int len = 0, c, ok = 1, eol;
    strcpy(E.filename, filename);
    E.saved.size = -1;
    if (!*filename)
        return editorInsertRow(0, "", 0, 0);
    fp = fopen(filename, "rb");
    if (!fp)
        return allow_new && errno == ENOENT && editorInsertRow(0, "", 0, 0);
    if (isatty(fileno(fp))) {
        fclose(fp);
        return 0;
    }
    while ((c = fgetc(fp)) != EOF) {
        if (c == 26) {
            E.eofmark = 1;
            ok = fgetc(fp) == EOF;
            break;
        }
        if (!c) {
            ok = 0;
            break;
        }
        if (c == '\n') {
            eol = len && line[len - 1] == '\r' ? 2 : 1;
            if (eol == 2)
                len--;
            if (len > MAX_LINE || !editorInsertRow(E.numrows, line ? line : "", len, eol)) {
                ok = 0;
                break;
            }
            len = 0;
        } else {
            if (len == MAX_LINE + 1) {
                ok = 0;
                break;
            }
            if ((unsigned)len == cap) {
                cap = !cap ? 128 : cap < 16384U ? cap * 2 : 32767U;
                p = realloc(line, cap);
                if (!p) {
                    ok = 0;
                    break;
                }
                line = p;
            }
            line[len++] = (char)c;
        }
    }
    if (ferror(fp))
        ok = 0;
    if (fclose(fp))
        ok = 0;
    if (ok)
        ok = len <= MAX_LINE && editorInsertRow(E.numrows, line ? line : "", len, 0);
    if (ok) {
        int i;
        /* Fingerprint disk bytes before normalizing rows for editing and saving. */
        fs_reset(&E.saved);
        for (i = 0; i < E.numrows; ++i) {
            countRow(&E.saved, E.row + i);
            if (E.row[i].eol == 1) {
                E.row[i].eol = 2;
                E.needs_crlf = 1;
            }
        }
        if (E.eofmark)
            fs_count(&E.saved, "\032", 1);
    }
    free(line);
    return ok;
}

/* Recovery files are siblings of the document. Show their short names so
 * both remain visible even on a 40-column display. */
static const char *leaf(const char *path)
{
    const char *name = path;
    while (*path) {
        if (*path == ':' || *path == '\\' || *path == '/')
            name = path + 1;
        ++path;
    }
    return name;
}

static int editorSave(void)
{
    char temporary[FS_NAME];
    file_stamp written;
    const file_stamp *expected = E.confirm_save ? &E.observed : &E.saved;
    save_result result;
    FILE *fp;
    int i, status, ok = 1;
    erow *row;
    E.confirm_save = 0;
    if (!E.dirty && !E.needs_crlf && E.saved.size >= 0) {
        strcpy(E.message, "No changes.");
        return 1;
    }
    status = fs_writable(E.filename);
    if (status == SAVE_OK) {
        fp = fs_create(temporary, sizeof(temporary), E.filename);
        if (!fp)
            goto write_error;
        fs_reset(&written);
        for (i = 0; i < E.numrows && ok; ++i) {
            row = &E.row[i];
            ok = fwrite(row->chars, 1, row->size, fp) == (unsigned)row->size;
            if (ok && row->eol)
                ok = fwrite(ending(row->eol), 1, row->eol, fp) == row->eol;
            countRow(&written, row);
        }
        if (E.eofmark) {
            if (putc(26, fp) == EOF)
                ok = 0;
            fs_count(&written, "\032", 1);
        }
        if (ferror(fp))
            ok = 0;
        if (fclose(fp))
            ok = 0;
        if (!ok) {
            unlink(temporary);
            goto write_error;
        }
        status = fs_commit(temporary, E.filename, expected, &result);
        if (status == SAVE_OK) {
            E.saved = written;
            E.needs_crlf = 0;
            E.dirty = 0;
            if (result.backup[0])
                sprintf(E.message, "Saved. Previous: %s", leaf(result.backup));
            else
                strcpy(E.message, "Saved.");
            return 1;
        }
        if (status == SAVE_ERROR || unlink(temporary)) {
            if (result.backup[0])
                sprintf(E.message, "Old:%s Edited:%s", leaf(result.backup), leaf(temporary));
            else
                sprintf(E.message, "Save failed. Edited copy: %s", leaf(temporary));
            return 0;
        }
        if (status == SAVE_CHANGED) {
            E.observed = result.observed;
            E.confirm_save = 1;
            strcpy(E.message, "Disk file changed. Ctrl-S to overwrite.");
            return 0;
        }
    }
    if (status == SAVE_PROTECTED) {
        strcpy(E.message, "Save failed. Destination is protected.");
        return 0;
    }
write_error:
    strcpy(E.message, "Save failed. Check space and directory permissions.");
    return 0;
}

static int editorInsertChar(int c)
{
    erow *r = &E.row[E.cy];
    char *p;
    if (r->size == MAX_LINE || !(p = realloc(r->chars, r->size + 2U)))
        return 0;
    r->chars = p;
    memmove(p + E.cx + 1, p + E.cx, r->size - E.cx + 1);
    p[E.cx++] = (char)c;
    r->size++;
    return 1;
}

static int editorInsertNewline(void)
{
    erow *r = &E.row[E.cy];
    char *smaller;
    if (!E.cx) {
        if (!editorInsertRow(E.cy, "", 0, 2))
            return 0;
        ++E.cy;
        return 1;
    }
    if (!editorInsertRow(E.cy + 1, r->chars + E.cx, r->size - E.cx, r->eol))
        return 0;
    r = &E.row[E.cy++];
    if (E.cx < r->size) {
        smaller = realloc(r->chars, E.cx + 1U);
        if (smaller)
            r->chars = smaller;
    }
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
        memmove(r->chars + E.cx, r->chars + E.cx + 1, r->size - E.cx);
        r->size--;
    } else {
        next = r + 1;
        if (E.cy + 1 == E.numrows)
            return 1;
        if ((long)r->size + next->size > MAX_LINE ||
            !(p = realloc(r->chars, r->size + next->size + 1U)))
            return 0;
        r->chars = p;
        memcpy(p + r->size, next->chars, next->size + 1);
        r->size += next->size;
        r->eol = next->eol;
        free(next->chars);
        E.numrows--;
        memmove(next, next + 1, (E.numrows - E.cy - 1) * sizeof(erow));
    }
    E.dirty = 1;
    return 1;
}

static void editorMoveCursor(int key)
{
    switch (key) {
    case HOME_KEY:
        E.cx = 0;
        break;
    case END_KEY:
        E.cx = E.row[E.cy].size;
        break;
    case ARROW_LEFT:
        if (E.cx)
            E.cx--;
        else if (E.cy)
            E.cx = E.row[--E.cy].size;
        break;
    case ARROW_RIGHT:
        if (E.cx < E.row[E.cy].size)
            E.cx++;
        else if (E.cy + 1 < E.numrows) {
            E.cy++;
            E.cx = 0;
        }
        break;
    case ARROW_UP:
        if (E.cy)
            E.cy--;
        break;
    case ARROW_DOWN:
        if (E.cy + 1 < E.numrows)
            E.cy++;
        break;
    case PAGE_UP:
        E.cy -= E.height;
        if (E.cy < 0)
            E.cy = 0;
        break;
    case PAGE_DOWN:
        E.cy += E.height;
        if (E.cy >= E.numrows)
            E.cy = E.numrows - 1;
        break;
    }
    if (E.cx > E.row[E.cy].size)
        E.cx = E.row[E.cy].size;
}

/* Ordered half-open range. Columns index stored bytes, before tab expansion. */
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
    while (b->count)
        free(b->rows[--b->count].chars);
    free(b->rows);
    b->rows = NULL;
}

/* Each fragment fits a segment, but the complete clipboard may exceed 64K. */
static int copyBlock(selection s, block *b)
{
    int y, x, end;
    erow *r, *out;
    b->rows = malloc((s.endy - s.y + 1) * sizeof(erow));
    if (!b->rows)
        return 0;
    for (y = s.y; y <= s.endy; ++y) {
        r = E.row + y;
        x = y == s.y ? s.x : 0;
        end = y == s.endy ? s.endx : r->size;
        out = b->rows + b->count;
        out->size = end - x;
        out->chars = malloc(out->size + 1U);
        if (!out->chars) {
            freeBlock(b);
            return 0;
        }
        memcpy(out->chars, r->chars + x, out->size);
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
    int total = E.numrows - (s.endy - s.y + 1) + count;
    int i, left, right, cursor = 0;
    erow *out;
    long size;
    if ((unsigned long)total * sizeof(erow) > 65520UL)
        return 0;
    fresh.count = 0;
    fresh.rows = malloc(count * sizeof(erow));
    if (!fresh.rows)
        return 0;
    for (i = 0; i < count; ++i) {
        left = i == 0 ? s.x : 0;
        right = i == count - 1 ? E.row[s.endy].size - s.endx : 0;
        size = (long)left + input[i].size + right;
        out = fresh.rows + i;
        if (size > MAX_LINE || !(out->chars = malloc((unsigned)size + 1))) {
            freeBlock(&fresh);
            return 0;
        }
        cursor = left + input[i].size;
        memcpy(out->chars, E.row[s.y].chars, left);
        memcpy(out->chars + left, input[i].chars, input[i].size);
        memcpy(out->chars + cursor, E.row[s.endy].chars + s.endx, right);
        out->size = (int)size;
        out->chars[out->size] = 0;
        out->eol = i == count - 1 ? E.row[s.endy].eol : input[i].eol;
        ++fresh.count;
    }
    if (!reserveRows(total)) {
        freeBlock(&fresh);
        return 0;
    }
    for (i = s.y; i <= s.endy; ++i)
        free(E.row[i].chars);
    memmove(E.row + s.y + count, E.row + s.endy + 1, (E.numrows - s.endy - 1) * sizeof(erow));
    memcpy(E.row + s.y, fresh.rows, count * sizeof(erow));
    free(fresh.rows);
    E.numrows = total;
    E.cy = s.y + count - 1;
    E.cx = cursor;
    E.marked = 0;
    E.dirty = 1;
    return 1;
}

static int copySelection(selection s, int cut)
{
    block fresh;
    static erow empty = {"", 0, 0};
    if (s.y == s.endy && s.x == s.endx) {
        strcpy(E.message, "Select text with Shift and a movement key.");
        return 1;
    }
    fresh.count = 0;
    if (!copyBlock(s, &fresh))
        return 0;
    if (cut && !replaceBlock(s, &empty, 1)) {
        freeBlock(&fresh);
        return 0;
    }
    freeBlock(&clipboard);
    clipboard = fresh;
    strcpy(E.message, cut ? "Cut." : "Copied.");
    return 1;
}

/* A local edit owns the removed bytes and records the range to replace on
 * undo. Global replace owns the old buffers for changed rows instead. Row
 * indices remain valid because later edits must be undone first. */
#define UNDO_DEPTH 5
typedef struct row_change {
    int index, size;
    char *chars;
    struct row_change *next;
} row_change;
typedef struct {
    row_change *changes;
    block removed;
    selection range;
    int cx, cy, ax, ay, marked, dirty;
} undo_entry;
static undo_entry history[UNDO_DEPTH];
static int history_count;
static erow empty_row = {"", 0, 0};

static void freeChanges(row_change *p)
{
    while (p) {
        row_change *next = p->next;
        free(p->chars);
        free(p);
        p = next;
    }
}

/* The same swap commits prepared text and later restores the original. */
static void swapChanges(row_change *p)
{
    for (; p; p = p->next) {
        erow *row = E.row + p->index;
        char *chars = row->chars;
        int size = row->size;
        row->chars = p->chars;
        row->size = p->size;
        p->chars = chars;
        p->size = size;
    }
}

static void beginEdit(undo_entry *u)
{
    memset(u, 0, sizeof(*u));
    u->cx = E.cx;
    u->cy = E.cy;
    u->marked = E.marked;
    u->ax = E.ax;
    u->ay = E.ay;
    u->dirty = E.dirty;
}

static void rememberEdit(const undo_entry *u)
{
    if (history_count == UNDO_DEPTH) {
        freeChanges(history[0].changes);
        freeBlock(&history[0].removed);
        --history_count;
        memmove(history, history + 1, history_count * sizeof(*u));
    }
    history[history_count++] = *u;
}

static int undoEdit(void)
{
    undo_entry *u;
    erow *rows;
    int count;
    if (!history_count) {
        strcpy(E.message, "Nothing to undo.");
        return 1;
    }
    u = history + history_count - 1;
    rows = u->removed.count ? u->removed.rows : &empty_row;
    count = u->removed.count ? u->removed.count : 1;
    if (u->changes) {
        swapChanges(u->changes);
        freeChanges(u->changes);
    } else if (!replaceBlock(u->range, rows, count))
        return 0;
    E.cx = u->cx;
    E.cy = u->cy;
    E.ax = u->ax;
    E.ay = u->ay;
    E.marked = u->marked;
    E.dirty = u->dirty;
    freeBlock(&u->removed);
    --history_count;
    strcpy(E.message, "Undone.");
    return 1;
}

static int applyEdit(int key, selection s)
{
    undo_entry u;
    erow insert[2];
    char ch = (char)key;
    int has_selection = s.y != s.endy || s.x != s.endx;
    int ok;

    if (key == 24 && !has_selection)
        return copySelection(s, 1);
    if (key == 22 && !clipboard.count) {
        strcpy(E.message, "Clipboard is empty.");
        return 1;
    }
    beginEdit(&u);
    if (!has_selection && (key == 8 || key == DEL_KEY)) {
        editorMoveCursor(key == 8 ? ARROW_LEFT : ARROW_RIGHT);
        if (key == 8) {
            s.x = E.cx;
            s.y = E.cy;
        } else {
            s.endx = E.cx;
            s.endy = E.cy;
        }
        E.cx = u.cx;
        E.cy = u.cy;
        if (s.y == s.endy && s.x == s.endx)
            return 1;
    }
    if ((s.y != s.endy || s.x != s.endx) && !copyBlock(s, &u.removed))
        return 0;
    if (key == 24)
        ok = copySelection(s, 1);
    else if (key == 22)
        ok = replaceBlock(s, clipboard.rows, clipboard.count);
    else if (has_selection) {
        insert[0] = empty_row;
        insert[0].chars = &ch;
        insert[0].size = key == 9 || (key >= 32 && key <= 255);
        insert[0].eol = 2;
        insert[1] = empty_row;
        ok = replaceBlock(s, insert, key == 13 ? 2 : 1);
    } else if (key == 8 || key == DEL_KEY) {
        E.cx = s.x;
        E.cy = s.y;
        ok = editorDelete();
    } else if (key == 13)
        ok = editorInsertNewline();
    else
        ok = editorInsertChar(key);
    if (!ok) {
        E.cx = u.cx;
        E.cy = u.cy;
        freeBlock(&u.removed);
        return 0;
    }
    E.marked = 0;
    E.dirty = 1;
    u.range = s;
    u.range.endx = E.cx;
    u.range.endy = E.cy;
    rememberEdit(&u);
    return 1;
}

static long nextColumn(long col, char c) { return c == '\t' ? (col | 7L) + 1 : col + 1; }

static void editorRefreshScreen(void)
{
    char line[81], status[100];
    long cursor = 0, col, next;
    int i, y, n, first, last;
    selection s;
    int start, end, ry;
    erow *r = &E.row[E.cy];
    s = selected();
    for (i = 0; i < E.cx; i++)
        cursor = nextColumn(cursor, r->chars[i]);
    if (cursor < E.left)
        E.left = cursor;
    if (cursor >= E.left + E.width)
        E.left = cursor - E.width + 1;
    if (E.cy < E.top)
        E.top = E.cy;
    if (E.cy >= E.top + E.height)
        E.top = E.cy - E.height + 1;
    for (y = 0; y < E.height; y++) {
        n = first = last = 0;
        if (y + E.top >= E.numrows)
            line[n++] = '~';
        else {
            ry = y + E.top;
            r = &E.row[ry];
            start = ry == s.y ? s.x : 0;
            end = ry == s.endy ? s.endx : r->size;
            if (ry < s.y || ry > s.endy)
                end = 0;
            if (ry == E.cy && E.matchlen) {
                start = E.cx;
                end = start + E.matchlen;
            }
            col = 0;
            for (i = 0; i < r->size && n < E.width; i++) {
                next = nextColumn(col, r->chars[i]);
                if (i == start)
                    first = n;
                if (next <= E.left) {
                    col = next;
                    continue;
                }
                while (col < next && n < E.width) {
                    if (col >= E.left)
                        line[n++] = (char)(r->chars[i] == '\t'               ? ' '
                                           : (unsigned char)r->chars[i] < 32 ? '?'
                                                                             : r->chars[i]);
                    col++;
                }
                if (i >= start && i < end)
                    last = n;
            }
            if (ry >= s.y && ry < s.endy && i == r->size && col >= E.left && n < E.width) {
                if (start == r->size)
                    first = n;
                last = E.width;
            }
        }
        screenLine(y, line, n, 7, first, last);
    }
    sprintf(status, "EDIT %.32s%s  Ln %d/%d Col %ld", *E.filename ? E.filename : "[Untitled]",
            E.dirty ? " *" : "", E.cy + 1, E.numrows, cursor + 1);
    screenLine(E.height, status, strlen(status), 0x70, 0, 0);
    screenLine(E.height + 1, E.message, strlen(E.message), 7, 0, 0);
    screenCursor(E.cy - E.top, (int)(cursor - E.left));
}

/* All lines fit the 40-column display. The caller redraws its own view. */
static void editorHelp(void)
{
    static const char *lines[] = {"EDIT Help",
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
                                  "In Find: arrows visit each match.",
                                  "Enter accepts. Esc restores position.",
                                  "Ctrl-R          Replace all",
                                  "Ctrl-Shift-R    Replace ignoring case",
                                  "Ctrl-Z          Undo (five edits)",
                                  "Ctrl-S Save   Ctrl-Shift-S Save As",
                                  "Ctrl-O Open   F3/Shift-F3 Next/Prev",
                                  "Ctrl-Q          Quit (twice if unsaved)"};
    int row, key;
    const char *line;
    for (row = 0; row < E.height + 1; ++row) {
        line =
            (unsigned)row < sizeof(lines) / sizeof(lines[0]) ? lines[row] : (const char *)"";
        screenLine(row, line, strlen(line), row == 0 ? 0x70 : 7, 0, 0);
    }
    line = "Esc or F1 to return";
    screenLine(row, line, strlen(line), 0x70, 0, 0);
    screenCursor(row, 0);
    do {
        key = editorReadKey();
    } while (key != 27 && key != HELP_KEY);
}

static char *findLiteral(char *text, const char *query, const unsigned char *fold)
{
    unsigned i;
    if (!fold)
        return strstr(text, query);
    for (; *text; ++text) {
        for (i = 0; query[i]; ++i)
            if (!text[i] || fold[(unsigned char)text[i]] != fold[(unsigned char)query[i]])
                break;
        if (!query[i])
            return text;
    }
    return NULL;
}

/* Consume the rest of an overlong field inside the prompt. A pasted
 * suffix must never be interpreted as editor commands or document text. */
static void rejectLongPrompt(int limit)
{
    int key;
    sprintf(E.message, "%d-byte limit. Enter or Esc to cancel.", limit);
    editorRefreshScreen();
    do {
        key = editorReadKey();
    } while (key != 13 && key != 27);
    sprintf(E.message, "Input exceeds %d bytes. Cancelled.", limit);
}

static char last_query[PROMPT_LIMIT + 1];
static int last_folded;

/* Search a complete circuit, including the other side of the starting
 * line after wrapping. Bounds apply to match starts, allowing overlaps. */
static int findOccurrence(const char *query, const unsigned char *fold, int row, int column,
                          int direction)
{
    int pass, first, last;
    char *line, *scan, *hit, *best;
    for (pass = 0; pass <= E.numrows; ++pass) {
        line = E.row[row].chars;
        first = 0;
        last = E.row[row].size;
        if (pass == 0 || pass == E.numrows) {
            if ((direction > 0) == (pass == 0))
                first = column;
            else
                last = column;
        }
        best = NULL;
        if (first < 0)
            first = 0;
        if (first <= last) {
            scan = line + first;
            while ((hit = findLiteral(scan, query, fold)) != NULL && hit - line <= last) {
                best = hit;
                if (direction > 0)
                    break;
                scan = hit + 1;
            }
        }
        if (best) {
            E.cy = row;
            E.cx = best - line;
            return 1;
        }
        row += direction;
        if (row < 0)
            row = E.numrows - 1;
        if (row == E.numrows)
            row = 0;
    }
    return 0;
}

static void repeatFind(int direction)
{
    unsigned char fold[256];
    if (!*last_query) {
        strcpy(E.message, "Use Ctrl-F to enter search text.");
        return;
    }
    if (last_folded)
        caseTable(fold);
    E.marked = 0;
    strcpy(E.message, findOccurrence(last_query, last_folded ? fold : NULL, E.cy,
                                     E.cx + direction, direction)
                          ? last_query
                          : "Text not found.");
}

static void editorFind(int folded)
{
    char query[PROMPT_LIMIT + 1];
    int len = 0, x = E.cx, y = E.cy, row, col, step, c;
    long left = E.left;
    int top = E.top;
    unsigned char fold[256];
    if (folded)
        caseTable(fold);
    query[0] = 0;
    for (;;) {
        sprintf(E.message, folded ? "Find (ignore case): %s" : "Find: %s", query);
        editorRefreshScreen();
        c = editorReadKey();
        if (c == HELP_KEY) {
            editorHelp();
            continue;
        }
        if (c == 27 || c == 13) {
            if (c == 13 && len) {
                strcpy(last_query, query);
                last_folded = folded;
            }
            strcpy(E.message, c == 13 && len && !E.matchlen ? "Text not found." : "");
            break;
        }
        row = y;
        col = x;
        step = 1;
        if (c == ARROW_UP || c == ARROW_LEFT || c == ARROW_DOWN || c == ARROW_RIGHT) {
            step = c == ARROW_UP || c == ARROW_LEFT ? -1 : 1;
            if (E.matchlen) {
                row = E.cy;
                col = E.cx + step;
            }
        } else {
            if (c == 8 && len)
                len--;
            else if (c >= 32 && c <= 255) {
                if (len == PROMPT_LIMIT) {
                    rejectLongPrompt(PROMPT_LIMIT);
                    break;
                }
                query[len++] = (char)c;
            } else
                continue;
            query[len] = 0;
        }
        E.matchlen =
            len && findOccurrence(query, folded ? fold : NULL, row, col, step) ? len : 0;
    }
    if (c != 13 || !E.matchlen) {
        E.cx = x;
        E.cy = y;
        E.left = left;
        E.top = top;
    }
    E.matchlen = 0;
}

/* Match non-overlapping occurrences in the original row. The sizing pass
 * skips byte-identical replacements and checks the 16-bit line limit. */
static int prepareRow(undo_entry *u, int y, char *from, char *to, unsigned char *fold,
                      long *total)
{
    erow *row = E.row + y;
    int n = strlen(from), m = strlen(to), changed = 0;
    long size = row->size;
    char *src = row->chars, *hit, *dst;
    row_change *p;
    while ((hit = findLiteral(src, from, fold)) != NULL) {
        if (m != n || memcmp(hit, to, n))
            ++changed;
        size += m - n;
        src = hit + n;
    }
    if (!changed)
        return 1;
    if (size > MAX_LINE)
        return 0;
    p = malloc(sizeof(*p));
    if (!p)
        return 0;
    dst = malloc((unsigned)size + 1U);
    if (!dst) {
        free(p);
        return 0;
    }
    p->next = u->changes;
    u->changes = p;
    p->index = y;
    p->size = (int)size;
    p->chars = dst;
    src = row->chars;
    while ((hit = findLiteral(src, from, fold)) != NULL) {
        unsigned prefix = (unsigned)(hit - src);
        memcpy(dst, src, prefix);
        dst += prefix;
        memcpy(dst, to, m);
        dst += m;
        src = hit + n;
    }
    strcpy(dst, src);
    *total += changed;
    return 1;
}

static int textPrompt(const char *label, char *text, int limit, int allow_tab)
{
    int key, len = 0, visible = E.width - strlen(label) - 1;
    for (;;) {
        text[len] = 0;
        sprintf(E.message, "%s%s", label, text + (len > visible ? len - visible : 0));
        editorRefreshScreen();
        key = editorReadKey();
        if (key == 27 || key == 13) {
            if (key == 13)
                return 1;
            strcpy(E.message, "Cancelled.");
            return 0;
        }
        if (key == HELP_KEY)
            editorHelp();
        else if (key == 8 && len)
            --len;
        else if ((allow_tab && key == 9) || (key >= 32 && key <= 255)) {
            if (len == limit) {
                rejectLongPrompt(limit);
                return 0;
            }
            text[len++] = (char)key;
        }
    }
}

/* Build all changed rows before touching the document. After the swap the
 * pending entry owns the originals, so undo needs no further allocation. */
static int replaceAll(char *from, char *to, unsigned char *fold)
{
    undo_entry u;
    long total = 0;
    int y;
    if (!*from)
        return 1;
    beginEdit(&u);
    for (y = 0; y < E.numrows; ++y) {
        if (!prepareRow(&u, y, from, to, fold, &total)) {
            freeChanges(u.changes);
            return 0;
        }
    }
    if (u.changes) {
        swapChanges(u.changes);
        rememberEdit(&u);
        E.marked = 0;
        E.dirty = 1;
        if (E.cx > E.row[E.cy].size)
            E.cx = E.row[E.cy].size;
    }
    sprintf(E.message, "%ld replacements.", total);
    return 1;
}

static int editorReplace(int folded)
{
    char from[PROMPT_LIMIT + 1], to[PROMPT_LIMIT + 1];
    unsigned char table[256];
    if (!textPrompt(folded ? "Replace all (ignore case): " : "Replace all: ", from,
                    PROMPT_LIMIT, 1))
        return 1;
    if (!*from) {
        strcpy(E.message, "Replace cancelled.");
        return 1;
    }
    if (!textPrompt("With: ", to, PROMPT_LIMIT, 1))
        return 1;
    if (folded)
        caseTable(table);
    return replaceAll(from, to, folded ? table : NULL);
}

static int validName(const char *name)
{
    return *name && !strpbrk(name, "/*?\"") && strlen(name) < FS_NAME;
}

static int promptName(const char *label, char *name)
{
    if (!textPrompt(label, name, FS_NAME - 1, 0))
        return 0;
    if (!validName(name)) {
        strcpy(E.message, "Invalid filename.");
        return 0;
    }
    return 1;
}

static void freeRows(editor_state *doc)
{
    while (doc->numrows)
        free(doc->row[--doc->numrows].chars);
    free(doc->row);
}

/* Keep the current document and its undo records until the new file has
 * loaded in full. The clipboard belongs to the editor across opens. */
static void openDocument(void)
{
    editor_state old;
    char name[FS_NAME];
    int key;
    if (!promptName("Open: ", name))
        return;
    if (E.dirty) {
        strcpy(E.message, "Discard changes and open? Y/N");
        editorRefreshScreen();
        key = editorReadKey();
        if (key != 'Y' && key != 'y') {
            strcpy(E.message, "Open cancelled.");
            return;
        }
    }
    old = E;
    memset(&E, 0, sizeof(E));
    if (!editorOpen(name, 0)) {
        freeRows(&E);
        E = old;
        strcpy(E.message, "Cannot load complete text file.");
        return;
    }
    E.height = old.height;
    E.width = old.width;
    freeRows(&old);
    while (history_count) {
        undo_entry *u = &history[--history_count];
        freeChanges(u->changes);
        freeBlock(&u->removed);
    }
}

static int saveAs(void)
{
    char name[FS_NAME], original[FS_NAME];
    file_stamp saved;
    saved = E.saved;
    if (!promptName("Save as: ", name))
        return 0;
    strcpy(original, E.filename);
    strcpy(E.filename, name);
    E.saved.size = -1;
    while (!editorSave()) {
        if (E.confirm_save) {
            strcpy(E.message, "File exists or changed. Ctrl-S replaces.");
            editorRefreshScreen();
            if (editorReadKey() == 19)
                continue;
            strcpy(E.message, "Save cancelled.");
        }
        E.confirm_save = 0;
        strcpy(E.filename, original);
        E.saved = saved;
        return 0;
    }
    return 1;
}

static void editorLoop(void)
{
    int c, confirm = 0, ok, i, was_dirty;
    selection s;
    strcpy(E.message, "F1 Help  Ctrl-S Save  Ctrl-F Find  Ctrl-Q Quit");
    for (;;) {
        editorRefreshScreen();
        c = editorReadKey();
        if (c != 19)
            E.confirm_save = 0;
        if (c == 17) {
            if (!E.dirty || confirm)
                return;
            strcpy(E.message, "Unsaved changes. Press Ctrl-Q again to discard.");
            confirm = 1;
            continue;
        }
        confirm = 0;
        ok = 1;
        s = selected();
        if (c & SELECT_KEY) {
            if (!E.marked) {
                E.ax = E.cx;
                E.ay = E.cy;
                E.marked = 1;
            }
            editorMoveCursor(c & ~SELECT_KEY);
            continue;
        }
        switch (c) {
        case 3:
            ok = copySelection(s, 0);
            break;
        case 18:
        case REPLACE_FOLDED:
            ok = editorReplace(c == REPLACE_FOLDED);
            break;
        case 26:
            ok = undoEdit();
            break;
        case 8:
        case 13:
        case 22:
        case 24:
        case DEL_KEY:
            ok = applyEdit(c, s);
            break;
        case 27:
            E.marked = 0;
            break;
        case HELP_KEY:
            editorHelp();
            break;
        case 15:
            openDocument();
            break;
        case FIND_NEXT:
        case FIND_PREV:
            repeatFind(c == FIND_NEXT ? 1 : -1);
            break;
        case SAVE_AS:
        case 19:
            was_dirty = E.dirty;
            if (((c == SAVE_AS || !*E.filename) ? saveAs() : editorSave()) && was_dirty) {
                /* Earlier undo positions now differ from the saved file. */
                for (i = 0; i < history_count; ++i)
                    history[i].dirty = 1;
            }
            break;
        case 6:
        case FIND_FOLDED:
            E.marked = 0;
            editorFind(c == FIND_FOLDED);
            break;
        default:
            if (c >= ARROW_LEFT) {
                E.marked = 0;
                editorMoveCursor(c);
            } else if (c == 9 || (c >= 32 && c <= 255))
                ok = applyEdit(c, s);
        }
        if (!ok)
            strcpy(E.message, "Edit refused. Line limit or insufficient memory.");
    }
}

int main(int argc, char **argv)
{
    int status;
    if (argc == 2 && !strcmp(argv[1], "/?")) {
        status = spawnlp(P_WAIT, "HELP.COM", "HELP", "EDIT", NULL);
        if (status >= 0)
            return status;
        fputs("No help available\n", stderr);
        return 1;
    }
    if (argc > 2 || (argc == 2 && !validName(argv[1]))) {
        fputs("EDIT: Invalid parameter.\n", stderr);
        return 1;
    }
    if (!editorOpen(argc == 2 ? argv[1] : "", 1)) {
        fputs("EDIT: Cannot load complete text file.\n", stderr);
        return 1;
    }
    if (!isatty(0) || !isatty(1) || !screenOpen(&E.height, &E.width)) {
        fputs("EDIT: PC text console required.\n", stderr);
        return 1;
    }
    editorLoop();
    screenClose();
    return 0;
}
