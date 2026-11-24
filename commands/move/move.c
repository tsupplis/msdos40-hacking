/* File moves use DOS rename whenever possible. Only cross-device moves
 * stream data, and publish the new file after the final checked close. */
#include <dos.h>
#include <io.h>
#include <direct.h>
typedef unsigned char BYTE;
typedef unsigned short WORD;
#include <msgret.h>
#include <stdlib.h>
#include <string.h>
#include <showhelp.h>

#include <stddef.h>
#define PATHLEN 128
#define ALLATTR (_A_SUBDIR | _A_HIDDEN | _A_SYSTEM | _A_RDONLY)

enum { usage = 1, bad = 2, failed = 3, make_dir = 4, replace_q = 5, saved = 6, arrow = 7, collision = 8 };

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

static int question(int id, char *path)
{
    char c, first = 0;
    unsigned count;
    message(stderr, id, path, NULL);
    while (!_dos_read(stdin, &c, 1, &count) && count) {
        if (c == '\n') break;
        if (!first) first = c;
    }
    return first == 'y' || first == 'Y';
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

#include <fcntl.h>


struct source {
    struct source *next;
    unsigned attr;
    char path[1];
};
static struct source *first, **tail = &first;
static int quiet, warn_replace;
static char buffer[4096];

static int collect(char *path, unsigned attr)
{
    struct source *s = malloc(sizeof(*s) + strlen(path));
    if (!s) return 0;
    s->next = NULL;
    s->attr = attr;
    strcpy(s->path,path);
    *tail = s;
    tail = &s->next;
    return 1;
}

static unsigned dosrename(char *from, char *to)
{
    union REGS r;
    r.h.ah = 0x56;
    r.x.dx = (unsigned)from;
    r.x.di = (unsigned)to;
    intdos(&r,&r);
    return r.x.cflag ? r.x.ax : 0;
}

/* DOS creates the name exclusively and returns an open handle. */
static int temporary(char *dest, char *name)
{
    union REGS r;
    unsigned prefix = leaf(dest) - dest;
    if (prefix+13 >= PATHLEN) return -1;
    memcpy(name,dest,prefix);
    name[prefix] = 0;
    r.x.ax = 0x5a00;
    r.x.cx = 0;
    r.x.dx = (unsigned)name;
    intdos(&r,&r);
    return r.x.cflag ? -1 : r.x.ax;
}

static int stage_copy(char *src, char *dest, unsigned attr, char *tmp)
{
    unsigned count, written, date, time;
    int in, out, ok;
    if (_dos_open(src,O_RDONLY,&in)) return 0;
    out = temporary(dest,tmp);
    if (out < 0) { _dos_close(in); return 0; }
    ok = !_dos_getftime(in,&date,&time);
    while (ok) {
        if (_dos_read(in,buffer,sizeof(buffer),&count)) ok = 0;
        else if (!count) break;
        else if (_dos_write(out,buffer,count,&written) || written != count) ok = 0;
    }
    if (ok && _dos_setftime(out,date,time)) ok = 0;
    if (_dos_close(out)) ok = 0;
    if (_dos_close(in)) ok = 0;
    if (ok && !_dos_setfileattr(tmp,attr)) return 1;
    _dos_setfileattr(tmp,0);
    unlink(tmp);
    return 0;
}

static int moveone(struct source *s, char *dest)
{
    char src[PATHLEN], backup[PATHLEN];
    unsigned attr, err;
    char staged[PATHLEN];
    int old, h, copied = 0;
    if (s->attr & (_A_HIDDEN | _A_SYSTEM)) return 0;
    if (!canonical(s->path,src) || !stricmp(src,dest)) return 0;
    err = _dos_getfileattr(dest,&attr);
    if (err && err != 2 && err != 3) return 0;
    old = !err;
    if (old) {
        if ((attr & (_A_RDONLY|_A_HIDDEN|_A_SYSTEM|_A_SUBDIR)) ||
            (s->attr & _A_SUBDIR)) return 0;
        if (warn_replace && !question(replace_q,dest)) return 1;
    }

    /* For a replacement, stage across drives (or network paths whose
     * volume is unknown) while the original destination is accessible. */
    if (old && (src[1] != ':' || dest[1] != ':' || src[0] != dest[0])) {
        if (!stage_copy(src,dest,s->attr,staged)) return 0;
        copied = 1;
    }
    if (old) {
        h = temporary(dest,backup);
        if (h < 0 || _dos_close(h) || unlink(backup) || dosrename(dest,backup))
            goto discard_stage;
    }
    err = dosrename(copied ? staged : src,dest);
    if (err == 17 && !old && !(s->attr & _A_SUBDIR)) {
        if (!stage_copy(src,dest,s->attr,staged)) return 0;
        copied = 1;
        err = dosrename(staged,dest);
    }
    if (err) {
        if (old && dosrename(backup,dest)) message(stderr, saved, backup, NULL);
        goto discard_stage;
    }
    if (copied && (((s->attr & _A_RDONLY) &&
        _dos_setfileattr(src,s->attr & ~_A_RDONLY)) || unlink(src))) {
        _dos_setfileattr(src,s->attr);
        if (old) message(stderr, saved, backup, NULL);
        return 0;
    }
    if (old && unlink(backup)) { message(stderr, saved, backup, NULL); return 0; }
    message(stdout, arrow, s->path, dest);
    return 1;
discard_stage:
    if (copied) {
        _dos_setfileattr(staged,0);
        unlink(staged);
    }
    return 0;
}

static int make_path(char *dir)
{
    char *p;
    unsigned attr;
    if (dir[1] != ':' || dir[2] != '\\') return mkdir(dir) == 0;
    for (p = dir + 3; ; ++p) {
        char end = *p;
        if (end && end != '\\') continue;
        *p = 0;
        if (_dos_getfileattr(dir, &attr) ? mkdir(dir) != 0 : !(attr & _A_SUBDIR)) {
            *p = end;
            return 0;
        }
        *p = end;
        if (!end) return 1;
    }
}

int main(int argc, char **argv)
{
    char list[PATHLEN], dest[PATHLEN], target[PATHLEN];
    char *token, *next;
    int i = 1, dir, multiple, ok = 1;
    unsigned attr, length = 0;
    struct source *s;

    for (i = 1; i < argc; ++i)
        if (!strcmp(argv[i], "/?")) show_help("MOVE");
    i = 1;
    load_messages();
    while (i < argc && argv[i][0] == '/') {
        if (!stricmp(argv[i], "/Y")) {
            quiet = 1;
            warn_replace = 0;
        } else if (!stricmp(argv[i], "/-Y")) {
            quiet = 0;
            warn_replace = 1;
        } else goto invalid;
        ++i;
    }
    if (argc - i < 2 || strpbrk(argv[argc-1], "*,?/") ||
        !canonical(argv[argc-1],dest)) goto invalid;
    for (; i < argc-1; ++i) {
        unsigned size = strlen(argv[i]);
        if (!size || length + size >= sizeof(list) || strchr(argv[i], '/')) goto invalid;
        if (length && list[length-1] != ',' && argv[i][0] != ',') goto invalid;
        strcpy(list + length, argv[i]);
        length += size;
    }
    if (*list == ',' || list[length-1] == ',' || strstr(list,",,")) goto invalid;
    multiple = strchr(list, ',') != NULL;
    dir = !*leaf(dest) || (!_dos_getfileattr(dest,&attr) && (attr & _A_SUBDIR));
    for (token = list; token; token = next) {
        next = strchr(token, ',');
        if (next) *next++ = 0;
        if (!matches(token,collect,0)) {
            message(stderr, failed, token, NULL);
            return 1;
        }
    }
    /* Every operand shares one destination directory. Equal leaf names
     * therefore collide, including matches from different wildcards. */
    for (s = first; s; s = s->next) {
        struct source *other;
        for (other = first; other != s; other = other->next)
            if (!stricmp(leaf(other->path),leaf(s->path))) {
                message(stderr,collision,s->path,other->path);
                return 1;
            }
    }
    if (!dir && (multiple || first->next)) {
        if (!_dos_getfileattr(dest,&attr)) goto invalid;
        if (!quiet && !question(make_dir,dest)) return 1;
        if (!make_path(dest)) { message(stderr,failed,dest,NULL); return 1; }
        dir = 1;
    }
    for (s = first; s; s = s->next) {
        strcpy(target,dest);
        if (dir) {
            if (strlen(target)+strlen(leaf(s->path))+2 > PATHLEN) goto invalid;
            if (target[strlen(target)-1] != '\\') strcat(target,"\\");
            strcat(target,leaf(s->path));
        }
        if (!moveone(s,target)) {
            message(stderr, failed, s->path, NULL);
            ok = 0;
        }
    }
    return !ok;
invalid:
    message(stderr, bad, NULL, NULL);
    message(stderr, usage, NULL, NULL);
    return 1;
}
