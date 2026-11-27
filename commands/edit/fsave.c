#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <errno.h>
#include <io.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <dos.h>
#include <ctype.h>

#include "fsave.h"

/* DOS names are case insensitive, including drive letters. */
static int fs_same(const char *a, const char *b)
{
    while (*a && *b) {
        if (toupper((unsigned char)*a) != toupper((unsigned char)*b))
            return 0;
        ++a;
        ++b;
    }
    return *a == *b;
}

FILE *fs_create(char *name, size_t namesize, const char *destination)
{
    const char *p;
    size_t prefix;
    unsigned i;
    int fd;
    FILE *f;

    prefix = 0;
    for (p = destination; *p; ++p)
        if (*p == ':' || *p == '/' || *p == '\\')
            prefix = (size_t)(p - destination) + 1;
    name[0] = 0;
    if (prefix + 13 > namesize)
        return NULL;
    for (i = 0; i < 4096; ++i) {
        memcpy(name, destination, prefix);
        sprintf(name + prefix, "FS%04X.TMP", i);
        if (fs_same(name, destination))
            continue;
        fd = open(name, O_WRONLY | O_CREAT | O_EXCL | O_BINARY, S_IREAD | S_IWRITE);
        if (fd < 0) {
            if (errno == EEXIST)
                continue;
            name[0] = 0;
            return NULL;
        }
        f = fdopen(fd, "wb");
        if (f != NULL)
            return f;
        close(fd);
        unlink(name);
        name[0] = 0;
        return NULL;
    }
    name[0] = 0;
    return NULL;
}

/* Returns success once the replacement is installed. Cleanup failures keep
 * a recoverable backup and are reported without undoing the new output. */
int fs_commit(const char *temporary, const char *destination,
                     const char *keep)
{
    char backup[FS_NAME];
    FILE *old, *reserved;
    int exists;
    unsigned attr;

    old = fopen(destination, "r");
    exists = old != NULL;
    if (old != NULL) {
        if (fclose(old) != 0)
            goto failed;
    } else if (errno != ENOENT) {
        goto failed;
    }
    backup[0] = 0;
    if (exists) {
        if (_dos_getfileattr((char *)destination, &attr) ||
            (attr & (_A_RDONLY | _A_HIDDEN | _A_SYSTEM | _A_SUBDIR)))
            goto failed;
        reserved = fs_create(backup, sizeof(backup), destination);
        if (reserved == NULL)
            goto failed;
        if (fclose(reserved) != 0 || unlink(backup) != 0)
            goto failed;
        if (rename(destination, backup) != 0)
            goto failed;
    }
    if (rename(temporary, destination) != 0) {
        if (exists && rename(backup, destination) != 0)
            fprintf(stderr, "Previous file retained at %s\n", backup);
        goto failed;
    }
    if (exists) {
        if (keep != (const char *)0) {
            if (fs_same(keep, destination)) {
                fprintf(stderr, "Backup retained at %s\n", backup);
                return 1;
            }
            old = fopen(keep, "r");
            if (old != NULL) {
                fclose(old);
                if (unlink(keep) != 0) {
                    fprintf(stderr, "Backup retained at %s\n", backup);
                    return 1;
                }
            }
            if (rename(backup, keep) != 0)
                fprintf(stderr, "Backup retained at %s\n", backup);
        } else if (unlink(backup) != 0) {
            fprintf(stderr, "Backup retained at %s\n", backup);
        }
    }
    return 1;
failed:
    fprintf(stderr, "Replacement retained at %s\n", temporary);
    return 0;
}
