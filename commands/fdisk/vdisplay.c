
#include "dos.h"                                                        /* AN000 */
#include "fdisk.h"                                                      /* AN000 */
#include "extern.h"                                                     /* AN000 */
#include "subtype.h"                                                    /* AN000 */
#include "fdiskmsg.h"                                                   /* AN000 */
#include "string.h"
#include "stdio.h"
#include "memory.h"

/*  */
#include "msgret.h"

static void status_volume(struct entry *entry)
{
    char letter = entry->drive_letter;
    if (letter >= 'C' && letter <= 'Z')
        printf("      %c: %7u\n",letter,entry->mbytes_used);
}

void display_disk_status(void)
{
    unsigned disk, i, used, percent;
    struct entry *entry;
    display_msg(11,1,0,0,0,Utility_Msg_Class);
    for (disk = 0; disk < number_of_drives; ++disk) {
        used = percent = 0;
        for (i = 0; i < 4; ++i) {
            entry = &part_table[disk][i];
            if (entry->sys_id) {
                used += entry->mbytes_used;
                percent += entry->percent_used;
            }
        }
        printf("%4u     %7u %7u %5u%%\n",disk+1,total_mbytes[disk],
               used < total_mbytes[disk] ? total_mbytes[disk]-used : 0,
               percent > 100 ? 100 : percent);
        for (i = 0; i < 4; ++i) status_volume(&part_table[disk][i]);
        for (i = 0; i < 23; ++i) status_volume(&ext_table[disk][i]);
    }
}

char volume_display()

BEGIN

unsigned    i;
unsigned    x;
char        drive_found;
char        drive_letter;
char        drive_num;
char        temp;
char        first_display;
char        second_display;
char        third_display;
char        fourth_display;
unsigned    insert_offset;

        first_display = FALSE;
        second_display = FALSE;
        third_display = FALSE;
        fourth_display = FALSE;

        drive_letter = assign_drive_letters();

        /* loop thru the partitions, only print stuff if it is there */

        /* Get the drives in order by location on disk */
        sort_ext_table(c(23));                                          /* AC000 */

        /* initialize all the inserts to blanks */
        memset(insert,c(' '),(24*29));

        drive_num = c(0);                                               /* AC000 */
        drive_found = FALSE;
        first_display = TRUE;
        insert_offset = 0;

        for (i=u(0); i < u(23); i++)                                    /* AC000 */
           BEGIN

            /* See if entry exists */
            if ( (ext_table[cur_disk][sort[i]].sys_id == uc(DOS12)) ||
                 (ext_table[cur_disk][sort[i]].sys_id == uc(DOS16)) ||
                 (ext_table[cur_disk][sort[i]].sys_id == uc(DOSNEW)) )  /* AC000  */
               BEGIN

                /* We found one, now get the info */
                drive_found = TRUE;

                insert_offset += sprintf(&insert[insert_offset],"%c%c%-11.11s%4.0d%-8.8s%3.0d%%",
                        ext_table[cur_disk][sort[i]].drive_letter,
                        ( ext_table[cur_disk][sort[i]].drive_letter == c(' ') ) ? ' ' : ':',
                        ext_table[cur_disk][sort[i]].vol_label,
                        ext_table[cur_disk][sort[i]].mbytes_used,
                        ext_table[cur_disk][sort[i]].system,
                        ext_table[cur_disk][sort[i]].percent_used );


                drive_num++;

               END
           END

        /* Display the column of drives */
        if (drive_found)
           BEGIN

            clear_screen(u(2),u(0),u(15),u(79));                    /* AC000 */

            if ( drive_num > 0 )
                BEGIN
                pinsert = &insert[0];
                display(menu_19);
                END

            if ( drive_num > 6 )
                BEGIN
                pinsert = &insert[6*29];
                display(menu_43);
                END

            if ( drive_num > 12 )
                BEGIN
                pinsert = &insert[12*29];
                display(menu_20);
                END

            if ( drive_num > 18 )
                BEGIN
                pinsert = &insert[18*29];
                display(menu_44);
                END
            pinsert = &insert[0];
            END
        else
           BEGIN
            /* Didn't find any */
            if (first_display)
               BEGIN
                /* Wipe out display and put up message */
                clear_screen(u(2),u(0),u(15),u(79));                    /* AC000 */
                display(status_9);
               END
           END
        /* Return the highest drive letter found */
        return(drive_letter);

END

