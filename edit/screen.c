/* IBM PC text modes. BIOS writes honour the active display page and avoid
 * CGA snow. Cache displayed cells to skip unchanged text and attributes. */
#include <bios.h>
#include <dos.h>
#include <string.h>
#include "screen.h"

static int page, rows, cols;
static unsigned short painted[50][80];

void screenCursor(int row, int col)
{
    union REGS r;
    r.h.ah = 2;
    r.h.bh = (unsigned char)page;
    r.h.dh = (unsigned char)row;
    r.h.dl = (unsigned char)col;
    int86(0x10, &r, &r);
}

int screenOpen(int *height, int *width)
{
    union REGS r;
    r.h.ah = 15;
    int86(0x10, &r, &r);
    if ((r.h.al & 127) > 3 && (r.h.al & 127) != 7)
        return 0;
    page = r.h.bh;
    cols = r.h.ah;
    rows = 1 + *(unsigned char far *)0x00400084L;
    if (rows < 25 || rows > 50)
        rows = 25;
    if (cols != 40 && cols != 80)
        return 0;
    *height = rows - 2;
    *width = cols;
    memset(painted, 0, sizeof(painted));
    return 1;
}

void screenLine(int row, const char *text, int length, int attr, int first, int last)
{
    int x = 0, n;
    unsigned short cell;
    unsigned char ch;
    union REGS r;
    while (x < cols) {
        ch = x < length ? (unsigned char)text[x] : ' ';
        cell = ((unsigned)(x >= first && x < last ? 0x70 : attr) << 8) | ch;
        if (painted[row][x] == cell) {
            x++;
            continue;
        }
        n = 0;
        do {
            painted[row][x + n++] = cell;
        } while (x + n < cols && x + n != first && x + n != last &&
                 (x + n < length ? (unsigned char)text[x + n] : ' ') == ch);
        screenCursor(row, x);
        r.h.ah = 9;
        r.h.al = ch;
        r.h.bh = (unsigned char)page;
        r.h.bl = (unsigned char)(cell >> 8);
        r.x.cx = n;
        int86(0x10, &r, &r);
        x += n;
    }
}

void screenClose(void)
{
    int y;
    for (y = 0; y < rows; ++y)
        screenLine(y, "", 0, 7, 0, 0);
    screenCursor(0, 0);
}

int editorReadKey(void)
{
    unsigned key = _bios_keybrd(_KEYBRD_READ);
    unsigned flags = _bios_keybrd(_KEYBRD_SHIFTSTATUS);
    int shifted = flags & 3;
    int ascii = key & 255, navigation;

    if (shifted && ascii == 19)
        return SAVE_AS;
    if (shifted && ascii == 18)
        return REPLACE_FOLDED;
    if (shifted && ascii == 6)
        return FIND_FOLDED;
    /* On an XT, Shift with a keypad arrow can deliver its numeric ASCII. */
    if (ascii >= '0' && ascii <= '9' && (key >> 8) >= 71 && (key >> 8) <= 81)
        shifted = !(flags & 0x20); /* numeric keypad with Num Lock off */
    if (ascii && !(shifted && ascii >= '0' && ascii <= '9'))
        return ascii;
    switch (key >> 8) {
    case 61:
        return FIND_NEXT; /* F3 */
    case 86:
        return FIND_PREV; /* Shift-F3 */
    case 59:
        return HELP_KEY; /* F1 */
    case 75:
        navigation = ARROW_LEFT;
        break;
    case 77:
        navigation = ARROW_RIGHT;
        break;
    case 72:
        navigation = ARROW_UP;
        break;
    case 80:
        navigation = ARROW_DOWN;
        break;
    case 83:
        return DEL_KEY;
    case 71:
        navigation = HOME_KEY;
        break;
    case 79:
        navigation = END_KEY;
        break;
    case 73:
        navigation = PAGE_UP;
        break;
    case 81:
        navigation = PAGE_DOWN;
        break;
    default:
        return ascii;
    }
    return shifted ? navigation | SELECT_KEY : navigation;
}

/* DOS returns a length-prefixed uppercase table for bytes 80h..FFh. */
void caseTable(unsigned char *table)
{
    union REGS r;
    struct SREGS segments;
    unsigned char info[5], *buffer = info, far * mapping;
    unsigned i, count;
    for (i = 0; i < 256; ++i)
        table[i] = (unsigned char)(i >= 'a' && i <= 'z' ? i - 'a' + 'A' : i);
    segread(&segments);
    segments.es = FP_SEG(buffer);
    r.x.di = FP_OFF(buffer);
    r.x.ax = 0x6502;
    r.x.bx = r.x.dx = 0xffff;
    r.x.cx = sizeof(info);
    intdosx(&r, &r, &segments);
    if (r.x.cflag || r.x.cx < 5 || info[0] != 2)
        return;
    memcpy(&mapping, info + 1, sizeof(mapping));
    memcpy(&count, mapping, sizeof(count));
    if (count == 128)
        memcpy(table + 128, mapping + 2, count);
}
