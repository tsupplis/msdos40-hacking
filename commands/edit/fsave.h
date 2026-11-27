#ifndef FSAVE_H
#define FSAVE_H
#include <stdio.h>
#define FS_NAME 128
FILE *fs_create(char *name, size_t namesize, const char *destination);
int fs_commit(const char *temporary, const char *destination, const char *keep);
#endif
