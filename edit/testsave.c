/* Exercise replacement failures using the target runtime's rename. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <io.h>
static int calls, failure;
static int faulty_rename(const char *from, const char *to)
{
    calls++;
    if (calls == failure || (failure == 3 && calls == 2))
        return -1;
    return rename(from, to);
}
#define rename faulty_rename
#include "fsave.c"
#undef rename

static void need(int ok, char *message)
{
    if (!ok) {
        printf("FAIL: %s\n", message);
        exit(1);
    }
}

int main(int argc, char **argv)
{
    FILE *f;
    char temp[FS_NAME], buf[16];
    int result;
    file_stamp original;
    save_result recovery;

    need(argc == 2, "mode argument");
    /* Standard CRC-32 check vector, split as it can be across DOS reads. */
    fs_reset(&original);
    fs_count(&original, "1234", 4);
    fs_count(&original, "56789", 5);
    need(original.size == 9 && ~original.crc == 0xcbf43926UL, "CRC-32 check vector");
    failure = atoi(argv[1]);
    f = fs_create(temp, sizeof(temp), "B:BASE.DAT");
    need(f != NULL && !strncmp(temp, "B:", 2), "same drive temporary");
    need(strcmp(temp, "B:FS0000.TMP"), "existing temporary preserved");
    need(fputs("NEW", f) != EOF && fclose(f) == 0, "finish temporary");
    fs_reset(&original);
    fs_count(&original, "OLD", 3);
    result = fs_commit(temp, "B:BASE.DAT", &original, &recovery);
    need((result == SAVE_OK) == (failure == 0), "commit result");
    need((recovery.backup[0] != 0) == (failure == 3), "original recovery name");
    if (failure != 3) {
        f = fopen("B:BASE.DAT", "r");
        need(f != NULL, "destination exists");
        memset(buf, 0, sizeof(buf));
        fread(buf, 1, 3, f);
        fclose(f);
        need(!strcmp(buf, result == SAVE_OK ? "NEW" : "OLD"), "destination contents");
    }
    puts("SAVE PASS");
    return 0;
}
