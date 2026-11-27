#ifndef FSAVE_H
#define FSAVE_H
#include <stdio.h>
#define FS_NAME 128
/* A negative size denotes an absent file; an empty file has size zero. */
typedef struct {
    long size;
    unsigned long crc;
} file_stamp;

enum save_status { SAVE_OK, SAVE_CHANGED, SAVE_PROTECTED, SAVE_ERROR };
typedef struct {
    char backup[FS_NAME];      /* Original retained when rollback/cleanup fails */
    file_stamp observed;      /* Version requiring explicit overwrite */
} save_result;

void fs_reset(file_stamp *stamp);
void fs_count(file_stamp *stamp, const char *data, unsigned count);
int fs_writable(char *name);
FILE *fs_create(char *name, size_t namesize, const char *destination);
int fs_commit(const char *temporary, char *destination,
              const file_stamp *expected, save_result *result);
#endif
