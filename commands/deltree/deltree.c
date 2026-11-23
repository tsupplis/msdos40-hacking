#include <dos.h>
#include <io.h>
#include <direct.h>
typedef unsigned char BYTE;
typedef unsigned short WORD;
#include <msgret.h>
#include <stdlib.h>
#include <string.h>

#include <stddef.h>
#define PATHLEN 128
#define ALLATTR (_A_SUBDIR | _A_HIDDEN | _A_SYSTEM | _A_RDONLY)

enum { usage = 1, bad = 2, failed = 3, confirm = 4, deleting = 6 };

void sysloadmsg(union REGS *, union REGS *);
void sysdispmsg(union REGS *, union REGS *);

static void load_messages(void)
{
    union REGS r;
    memset(&r, 0, sizeof(r));
    sysloadmsg(&r, &r);
    if (r.x.cflag & 1) {
        sysdispmsg(&r, &r);
        exit(1);
    }
}

static void message(int handle, int id, char *first, char *second)
{
    static struct m_sublist subs[2];
    union REGS r;
    struct SREGS seg;
    int i, count = second ? 2 : first ? 1 : 0;

    segread(&seg);
    for (i = 0; i < count; ++i) {
        subs[i].sub_size = sizeof(subs[i]);
        subs[i].sub_value = (unsigned)(i ? second : first);
        subs[i].sub_value_seg = seg.ds;
        subs[i].sub_id = i + 1;
        subs[i].sub_flags = sf_asciiz;
        subs[i].sub_min_width = 1;
        subs[i].sub_pad_char = ' ';
    }
    r.x.ax = id;
    r.x.bx = handle;
    r.x.cx = count;
    r.x.dx = utility_msg_class << 8;
    r.x.si = (unsigned)subs;
    sysdispmsg(&r, &r);
}

static int question(char *path)
{
    char c, choice = 0;
    unsigned count;
    message(stderr, confirm, path, NULL);
    while (!_dos_read(stdin, &c, 1, &count) && count) {
        if (c == 3 || c == 26) return 0;
        if (c == '\n') break;
        if (!choice) choice = c;
    }
    return choice == 'y' || choice == 'Y';
}

static char *leaf(char *path)
{
    char *p = strrchr(path, '\\');
    if (!p) p = strrchr(path, ':');
    return p ? p + 1 : path;
}

/* DOS TRUENAME also expands drive-relative paths and SUBST mappings. */
static int canonical(char *input, char *out)
{
    union REGS r;
    r.x.ax = 0x6000;
    r.x.si = (unsigned)input;
    r.x.di = (unsigned)out;
    intdos(&r, &r);
    return !r.x.cflag;
}

typedef int (*visitor)(char *, unsigned);
static int matches(char *spec, visitor visit, int allow_empty)
{
    struct find_t ent;
    unsigned err;
    int seen = 0, ok = 1;
    char path[PATHLEN], *name;
    if (strlen(spec) >= PATHLEN) return 0;
    strcpy(path, spec);
    name = leaf(path);
    if (!*name || !strcmp(name, ".") || !strcmp(name, "..")) return 0;
    err = _dos_findfirst(spec, ALLATTR, &ent);
    while (!err) {
        if (strcmp(ent.name, ".") && strcmp(ent.name, "..")) {
            if ((name-path) + strlen(ent.name) >= PATHLEN) return 0;
            strcpy(name, ent.name);
            seen = 1;
            if (!visit(path, ent.attrib)) ok = 0;
        }
        err = _dos_findnext(&ent);
    }
    return ok && (seen || allow_empty) && (err == 18 || err == 2);
}


static int quiet;

static int erase(char *path, unsigned attr)
{
    char search[PATHLEN];
    int dir = attr & _A_SUBDIR;
    if (dir) {
        if (strlen(path) + 4 >= PATHLEN) return 0;
        strcpy(search, path);
        strcat(search, "\\*.*");
        if (!matches(search, erase, 1)) return 0;
    }
    if (attr & (_A_HIDDEN | _A_SYSTEM | _A_RDONLY))
        if (_dos_setfileattr(path, attr & ~(_A_HIDDEN | _A_SYSTEM | _A_RDONLY)))
            return 0;
    if ((dir ? rmdir(path) : unlink(path)) == 0) return 1;
    _dos_setfileattr(path, attr);
    message(stderr, failed, path, NULL);
    return 0;
}

static int selected(char *path, unsigned attr)
{
    char full[PATHLEN], current[PATHLEN]; static char drivecwd[] = "A:.";
    unsigned len;
    if (!canonical(path, full) || !full[0] || !*leaf(full)) return 0;
    len = strlen(full);
    /* SUBST drives maintain independent current directories. Compare each
     * logical drive in the same expanded namespace before descending. */
    for (drivecwd[0] = 'A'; (attr & _A_SUBDIR) && drivecwd[0] <= 'Z';
         ++drivecwd[0]) {
        if (!canonical(drivecwd, current)) {
            if (drivecwd[0] == full[0]) return 0;
            continue;
        }
        if (!strnicmp(full,current,len) &&
            (!current[len] || current[len]=='\\')) return 0;
    }
    if (!quiet && !question(path))
        return 1;
    message(stdout, deleting, path, NULL);
    return erase(path,attr);
}

int main(int argc, char **argv)
{
    int i = 1, rc = 0;
    char pattern[PATHLEN], *name;
    load_messages();
    while (i < argc && argv[i][0] == '/') {
        if (stricmp(argv[i], "/Y")) { message(stderr, bad, NULL, NULL); return 1; }
        quiet = 1;
        ++i;
    }
    if (i == argc) { message(stderr, usage, NULL, NULL); return 1; }
    for (; i < argc; ++i) {
        if (strlen(argv[i]) + 5 > sizeof(pattern) || strchr(argv[i], '/')) {
            message(stderr, bad, NULL, NULL);
            rc = 1;
            continue;
        }
        strcpy(pattern, argv[i]);
        /* A directory operand must name its target explicitly. */
        while (*pattern && pattern[strlen(pattern)-1] == '\\')
            pattern[strlen(pattern)-1] = 0;
        name = leaf(pattern);
        if (!*name || !strcmp(name, ".") || !strcmp(name, "..")) {
            message(stderr, bad, NULL, NULL);
            rc = 1;
            continue;
        }
        if (!matches(pattern, selected, 1)) {
            message(stderr, failed, argv[i], NULL);
            rc = 1;
        }
    }
    return rc;
}
