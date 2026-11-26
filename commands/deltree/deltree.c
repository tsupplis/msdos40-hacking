#include <showhelp.h>
#include <dos.h>
#include <cds.h>
#include <sysvar.h>
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
        if (c == '\r') continue;
        if (c == '\n') return choice == 'Y' || choice == 'y';
        if (!choice) choice = c;
    }
    return 0;
}

/* DOS returns pairs of inclusive lead-byte ranges, terminated by 0,0. */
static unsigned char far *lead_ranges;

static void load_lead_ranges(void)
{
    union REGS r;
    struct SREGS seg;
    segread(&seg);
    r.x.ax = 0x6300;
    r.x.si = 0;
    intdosx(&r,&r,&seg);
    if (!r.x.cflag && !r.h.al) {
        FP_SEG(lead_ranges) = seg.ds;
        FP_OFF(lead_ranges) = r.x.si;
    }
}

static char *next_char(char *p)
{
    unsigned char far *r;
    if ((unsigned char)*p >= 0x80 && p[1] && lead_ranges)
        for (r = lead_ranges; *r; r += 2)
            if ((unsigned char)*p >= r[0] && (unsigned char)*p <= r[1])
                return p + 2;
    return p + 1;
}

static char *leaf(char *path)
{
    char *p, *name = path;
    for (p = path; *p; p = next_char(p))
        if (*p == '\\' || *p == ':') name = p + 1;
    return name;
}

/* A UNC operand must name something below both server and share. */
static int share_root(char *path)
{
    char *p;
    int components = 0;
    if (path[0] != '\\' || path[1] != '\\') return 0;
    p = path + 2;
    while (*p) {
        if (*p == '\\') { ++p; continue; }
        if (++components == 3) return 0;
        do { p = next_char(p); } while (*p && *p != '\\');
    }
    return 1;
}

/* DOS TRUENAME also expands drive-relative paths and SUBST mappings. */
static int canonical(char *input, char *out)
{
    union REGS r;
    struct SREGS seg;
    segread(&seg);
    seg.es = seg.ds;              /* TRUENAME writes to ES:DI. */
    r.x.ax = 0x6000;
    r.x.si = (unsigned)input;
    r.x.di = (unsigned)out;
    intdosx(&r, &r, &seg);
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
    struct find_t ent;
    unsigned err, len = strlen(path);
    int dir = attr & _A_SUBDIR, ok = 1;
    if (dir) {
        /* Reuse the caller's path buffer. Each level owns its search state. */
        if (len + 4 >= PATHLEN) return 0;
        strcpy(path + len, "\\*.*");
        err = _dos_findfirst(path, ALLATTR, &ent);
        while (!err) {
            if (strcmp(ent.name,".") && strcmp(ent.name,"..")) {
                if (len + 1 + strlen(ent.name) >= PATHLEN) { ok = 0; break; }
                strcpy(path + len + 1,ent.name);
                if (!erase(path,ent.attrib)) ok = 0;
            }
            err = _dos_findnext(&ent);
        }
        path[len] = 0;
        if (!ok || (err != 18 && err != 2)) return 0;
    }
    if (attr & (_A_HIDDEN | _A_SYSTEM | _A_RDONLY))
        if (_dos_setfileattr(path, attr & ~(_A_HIDDEN | _A_SYSTEM | _A_RDONLY)))
            return 0;
    if ((dir ? rmdir(path) : unlink(path)) == 0) return 1;
    _dos_setfileattr(path, attr);
    message(stderr, failed, path, NULL);
    return 0;
}

/* Match a whole directory component (WIN must not match WINDOWS). */
static int contains_path(char *parent, char *path)
{
    unsigned len = strlen(parent);
    return !strnicmp(parent, path, len) &&
           (!path[len] || path[len] == '\\');
}

/* Some redirectors return X:\path for TRUENAME on two mappings of the
 * same volume. Compare paths below the share when either name is opaque. */
static char *volume_path(char *p)
{
    int parts = 0;
    if (p[0] && p[1] == ':' && p[2] == '\\') return p + 2;
    if (p[0] != '\\' || p[1] != '\\') return NULL;
    p += 2;
    while (*p && parts < 2) {
        while (*p == '\\') ++p;
        if (!*p) break;
        do { p = next_char(p); } while (*p && *p != '\\');
        ++parts;
    }
    return parts == 2 ? p : NULL;
}

static int selected(char *path, unsigned attr)
{
    char full[PATHLEN], current[PATHLEN];
    static char drivecwd[] = "A:.";
    struct sysVarsType far *vars;
    struct CDSType far *cds;
    struct SREGS seg;
    union REGS r;
    unsigned i, n;
    int remote;
    if (!canonical(path, full) || !full[0] || share_root(full) || !*leaf(full)) return 0;
    if (attr & _A_SUBDIR) {
        /* Read the DOS 4 current-directory table in memory. TRUENAME on
         * an unrelated floppy can ask the user to insert its disk. */
        segread(&seg);
        r.h.ah = 0x52;
        intdosx(&r, &r, &seg);
        FP_SEG(vars) = seg.es;
        FP_OFF(vars) = r.x.bx;
        cds = (struct CDSType far *)vars->pCDS;
        remote = full[0] == '\\' ||
                 (full[0] >= 'A' && full[0] < 'A' + vars->cCDS &&
                  full[1] == ':' && (cds[full[0]-'A'].flags & CDSNET));
        for (i = 0; i < vars->cCDS; ++i) {
            if (!(cds[i].flags & (CDSINUSE | CDSNET))) continue;
            drivecwd[0] = (char)('A' + i);
            /* SUBST stores its backing drive in the CDS path. Network
             * aliases may resolve to a UNC name through the redirector. */
            if (drivecwd[0] != full[0] && cds[i].text[0] != full[0] &&
                !(remote && (cds[i].flags & CDSNET))) continue;
            /* A SUBST drive's root is protected even when DOS returns
             * the logical drive spelling for TRUENAME on that root. */
            if (cds[i].flags & CDSLOCAL) {
                n = cds[i].cbEnd;
                if (n >= sizeof(cds[i].text)) return 0;
                for (n = 0; n < cds[i].cbEnd; ++n)
                    current[n] = cds[i].text[n];
                current[cds[i].cbEnd] = 0;
                if (contains_path(full, current)) return 0;
            }
            if (!canonical(drivecwd, current) || contains_path(full, current))
                return 0;
            if (remote && (cds[i].flags & CDSNET) &&
                (full[0] != '\\' || current[0] != '\\')) {
                char *target = volume_path(full), *cwd = volume_path(current);
                if (!target || !cwd || contains_path(target,cwd)) return 0;
            }
        }
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
    check_help();
    load_messages();
    load_lead_ranges();
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
        {
            char *p, *trailing = NULL;
            for (p = pattern; *p; p = next_char(p)) {
                if (*p != '\\') trailing = NULL;
                else if (!trailing) trailing = p;
            }
            if (trailing) *trailing = 0;
        }
        name = leaf(pattern);
        if (share_root(pattern) || !*name || !strcmp(name, ".") || !strcmp(name, "..")) {
            message(stderr, bad, NULL, NULL);
            rc = 1;
            continue;
        }
        if (!matches(pattern, selected, 0)) {
            message(stderr, failed, argv[i], NULL);
            rc = 1;
        }
    }
    return rc;
}
