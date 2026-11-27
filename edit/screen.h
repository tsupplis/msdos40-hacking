#ifndef SCREEN_H
#define SCREEN_H
enum editor_key {
    ARROW_LEFT = 256,
    ARROW_RIGHT,
    ARROW_UP,
    ARROW_DOWN,
    DEL_KEY,
    HOME_KEY,
    END_KEY,
    PAGE_UP,
    PAGE_DOWN,
    FIND_FOLDED,
    REPLACE_FOLDED,
    HELP_KEY
};
#define SELECT_KEY 512
void caseTable(unsigned char *table);
/* Return editable rows (excluding both status lines) and screen columns. */
int screenOpen(int *rows, int *cols);
/* Paint one row; [first,last) selects the display columns to highlight. */
void screenLine(int row, const char *text, int length, int attr, int first, int last);
void screenCursor(int row, int col);
void screenClose(void);
int editorReadKey(void);
#endif
