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

/* CRC-32 in blocks: a DOS timestamp has only two-second resolution. */
void fs_reset(file_stamp *stamp)
{
    stamp->size = 0;
    stamp->crc = ~0UL;
}

void fs_count(file_stamp *stamp, const char *data, unsigned count)
{
    static const unsigned long nibble[16] = {0,
                                             0x1db71064UL,
                                             0x3b6e20c8UL,
                                             0x26d930acUL,
                                             0x76dc4190UL,
                                             0x6b6b51f4UL,
                                             0x4db26158UL,
                                             0x5005713cUL,
                                             0xedb88320UL,
                                             0xf00f9344UL,
                                             0xd6d6a3e8UL,
                                             0xcb61b38cUL,
                                             0x9b64c2b0UL,
                                             0x86d3d2d4UL,
                                             0xa00ae278UL,
                                             0xbdbdf21cUL};
    unsigned long crc = stamp->crc;
    stamp->size += count;
    while (count--) {
        crc ^= (unsigned char)*data++;
        crc = (crc >> 4) ^ nibble[crc & 15];
        crc = (crc >> 4) ^ nibble[crc & 15];
    }
    stamp->crc = crc;
}

/* Distinguish a missing leaf from an invalid drive, path or access error. */
static int inspect(char *name, int *exists)
{
    unsigned attr, error = _dos_getfileattr(name, &attr);
    *exists = error == 0;
    if (error)
        return error == 2 ? SAVE_OK : SAVE_ERROR;
    return attr & (_A_RDONLY | _A_HIDDEN | _A_SYSTEM | _A_SUBDIR) ? SAVE_PROTECTED
                                                                  : SAVE_OK;
}

int fs_writable(char *name)
{
    int exists;
    return inspect(name, &exists);
}

static int fingerprint(char *name, file_stamp *stamp)
{
    char buf[1024];
    unsigned n;
    int ok;
    FILE *fp = fopen(name, "rb");
    if (!fp)
        return 0;
    fs_reset(stamp);
    while ((n = fread(buf, 1, sizeof(buf), fp)) != 0)
        fs_count(stamp, buf, n);
    ok = !ferror(fp);
    if (fclose(fp))
        ok = 0;
    return ok;
}

/* Verify the version actually moved aside before publishing the edited
 * copy. DOS rename refuses an occupied destination. A failed rollback
 * leaves both recovery files in the original directory. */
int fs_commit(const char *temporary, char *destination, const file_stamp *expected,
              save_result *result)
{
    char backup[FS_NAME];
    FILE *reserved;
    int exists, status = inspect(destination, &exists);
    result->backup[0] = 0;
    result->observed.size = -1;
    result->observed.crc = 0;
    if (status != SAVE_OK)
        return status;
    if (exists) {
        reserved = fs_create(backup, sizeof(backup), destination);
        if (!reserved)
            return SAVE_ERROR;
        status = fclose(reserved);
        if (unlink(backup) || status)
            return SAVE_ERROR;
        if (rename(destination, backup))
            return SAVE_ERROR;
        if (!fingerprint(backup, &result->observed))
            status = SAVE_ERROR;
    }
    if (status == SAVE_OK && (result->observed.size != expected->size ||
                              (exists && result->observed.crc != expected->crc)))
        status = SAVE_CHANGED;
    if (status == SAVE_OK && rename(temporary, destination))
        status = SAVE_ERROR;
    if (exists) {
        if (status == SAVE_OK) {
            if (unlink(backup))
                strcpy(result->backup, backup);
        } else if (rename(backup, destination)) {
            strcpy(result->backup, backup);
            status = SAVE_ERROR;
        }
    }
    return status;
}
