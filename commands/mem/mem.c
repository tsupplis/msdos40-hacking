
/*----------------------------------------------------------------------+
|                                                                       |
|                                                                       |
|       Title:          MEM                                             |
|                                                                       |
|       Syntax:                                                         |
|                                                                       |
|               From the DOS command line:                              |
|                                                                       |
|               MEM                                                     |
|                       - Used to display DOS memory map summary.       |
|                                                                       |
|               MEM /C[LASSIFY] [/P]                                            |
|                       - Group allocations by module.                  |
|                                                                       |
|               MEM /D[EBUG] [/P]                                              |
|                       - Used to display a detailed DOS memory map.    |
|                                                                       |
|       AN001 - PTM P2914 -> This PTM relates to MEM's ability to report|
|                            the accurate total byte count for EM       |
|                            memory.                                    |
|                                                                       |
|       AN002 - PTM P3477 -> MEM was displaying erroneous base memory   |
|                            information for "Total" and "Available"    |
|                            memory.  This was due to incorrect logic   |
|                            for RAM carving.                           |
|                                                                       |
|       AN003 - PTM P3912 -> MEM messages do not conform to spec.       |
|               PTM P3989                                               |
|                                                                       |
|               Date: 1/28/88                                           |
|                                                                       |
|       AN004 - PTM P4510 -> MEM does not give correct DOS size.        |
|                                                                       |
|               Date: 4/27/88                                           |
|                                                                       |
|       AN005 - PTM P4957 -> MEM does not give correct DOS size for     |
|                            programs loaded into high memory.          |
|                                                                       |
|               Date: 6/07/88                                           |
|                                                                       |
+----------------------------------------------------------------------*/

/*컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�*/

#include "ctype.h"                                                                                           /* ;an000; */
#include "conio.h"                      /* need for kbhit prototype */                                       /* ;an000; */
#include "stdio.h"                                                                                           /* ;an000; */
#include "dos.h"                                                                                             /* ;an000; */
#include "string.h"                                                                                          /* ;an000; */
#include "stdlib.h"                                                                                          /* ;an000; */
#include "msgdef.h"                                                                                          /* ;an000; */
#include "parse.h"                                                                                           /* ;an000; */

/* #include "copyrigh.h" */     /* Only need one copyright statement an004 */
                                /* It is included by the message ret an004 */

/*컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�*/

        char    *SingleDrive = "%c:" ;                                                                                           /* ;an000; */
        char    *MultipleDrives = "%c: - %c:" ;                                                                                  /* ;an000; */
        char    *UnOwned = "----------" ;                                                                                        /* ;an000; */
        char    *Ibmbio = "IO    " ;                                                                                             /* ;an000; */
        char    *Ibmdos = "MSDOS " ;
                                                                                                                                 /* ;an000; */
  struct sublistx                                                                                                                /* ;an000; */
   {                                                                                                                             /* ;an000; */
    unsigned char size;                                                         /* sublist size                         */       /* ;an000; */
    unsigned char reserved;                                                     /* reserved for future growth           */       /* ;an000; */
    unsigned far *value;                                                        /* pointer to replaceable parm          */       /* ;an000; */
    unsigned char id;                                                           /* type of replaceable parm             */       /* ;an000; */
    unsigned char flags;                                                        /* how parm is to be displayed          */       /* ;an000; */
    unsigned char max_width;                                                    /* max width of replaceable field       */       /* ;an000; */
    unsigned char min_width;                                                    /* min width of replaceable field       */       /* ;an000; */
    unsigned char pad_char;                                                     /* pad character for replaceable field  */       /* ;an000; */
  } sublist[4];                                                                                                                  /* ;an000; */
                                                                                                                                 /* ;an000; */
/*----------------------------------------------------------------------+
|       define structure used by parser                                 |
+----------------------------------------------------------------------*/

struct p_parms  p_p;                                                                                                             /* ;an000; */
                                                                                                                                 /* ;an000; */
struct p_parmsx p_px;                                                                                                            /* ;an000; */
                                                                                                                                 /* ;an000; */
static struct p_control_blk debug_switch, classify_switch, page_switch;
static struct p_result_blk debug_result, classify_result, page_result;

struct p_value_blk p_noval;                                                                                                      /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
        struct  DEVICEHEADER {                                                                                                   /* ;an000; */
                struct DEVICEHEADER far *NextDeviceHeader;                                                                       /* ;an000; */
                unsigned                Attributes;                                                                              /* ;an000; */
                unsigned                Strategy;                                                                                /* ;an000; */
                unsigned                Interrupt;                                                                               /* ;an000; */
                char                    Name[8];                                                                                 /* ;an000; */
                };                                                                                                               /* ;an000; */
                                                                                                                                 /* ;an000; */
#define DA_TYPE         0x8000;                                                                                                  /* ;an000; */
#define DA_IOCTL        0x4000;                                                                                                  /* ;an000; */
                                                                                                                                 /* ;an000; */
#define a(fp)   ((char) fp)                                                                                                      /* ;an000; */
                                                                                                                                 /* ;an000; */
/* defines used in EMS support */                                                                                                /* ;an000; */
                                                                                                                                 /* ;an000; */
#define GET_VECT        0x35            /* EMS interrupt  */                                                                     /* ;an000; */
#define EMS             0x67                                                                                                     /* ;an000; */
                                                                                                                                 /* ;an000; */
#define CASSETTE        0x15            /* interrupt to get extended memory */                                                   /* ;an000; */
                                                                                                                                 /* ;an000; */
#define DOSEMSVER       0x40            /* EMS version */                                                                        /* ;an000; */
                                                                                                                                 /* ;an000; */
#define EMSGetStat      0x4000          /* get stat */                                                                           /* ;an000; */
#define EMSGetVer       0x4600          /* get version */                                                                        /* ;an000; */
#define EMSGetFreePgs   0x4200          /* get free pages */                                                                     /* ;an000; */
                                                                                                                                 /* ;an000; */
#define GetExtended     0x8800          /* get extended memory size */                                                           /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
/* defines used by total memory determination */                                                                                 /* ;an000; */
#define GET_PSP         (unsigned char ) 0x62            /* get PSP function call */                                             /* ;an000; */

#define MEMORY_DET      0x12            /* BIOS interrupt used to get total memory size */                                       /* ;an000; */
                                                                                                                                 /* ;an000; */
        struct  SYSIVAR {                                                                                                        /* ;an000; */
                char far *DpbChain;                                                                                              /* ;an000; */
                char far *SftChain;                                                                                              /* ;an000; */
                char far *Clock;                                                                                                 /* ;an000; */
                char far *Con;                                                                                                   /* ;an000; */
                unsigned  MaxSectorSize;                                                                                         /* ;an000; */
                char far *BufferChain;                                                                                           /* ;an000; */
                char far *CdsList;                                                                                               /* ;an000; */
                char far *FcbChain;                                                                                              /* ;an000; */
                unsigned  FcbKeepCount;                                                                                          /* ;an000; */
                unsigned char BlockDeviceCount;                                                                                  /* ;an000; */
                char      CdsCount;                                                                                              /* ;an000; */
                struct DEVICEHEADER far *DeviceDriverChain;                                                                      /* ;an000; */
                unsigned  NullDeviceAttributes;                                                                                  /* ;an000; */
                unsigned  NullDeviceStrategyEntryPoint;                                                                          /* ;an000; */
                unsigned  NullDeviceInterruptEntryPoint;                                                                         /* ;an000; */
                char      NullDeviceName[8];                                                                                     /* ;an000; */
                char      SpliceIndicator;                                                                                       /* ;an000; */
                unsigned  DosParagraphs;                                                                                         /* ;an000; */
                char far *DosServiceRntryPoint;                                                                                  /* ;an000; */
                char far *IfsChain;                                                                                              /* ;an000; */
                unsigned  BufferValues;                                                                                          /* ;an000; */
                unsigned  LastDriveValue;                                                                                        /* ;an000; */
                char      BootDrive;                                                                                             /* ;an000; */
                char      MoveType;
                unsigned  ExtendedMemory;
                };                                                                                                               /* ;an000; */
                                                                                                                                 /* ;an000; */
/*컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�*/                                                  /* ;an000; */
                                                                                                                                 /* ;an000; */
        struct  ARENA    {                                                                                                       /* ;an000; */
                char     Signature;                                                                                              /* ;an000; */
                unsigned Owner;                                                                                                  /* ;an000; */
                unsigned Paragraphs;                                                                                             /* ;an000; */
                char     Dummy[3];                                                                                               /* ;an000; */
                char     OwnerName[8];                                                                                           /* ;an000; */
                };                                                                                                               /* ;an000; */
                                                                                                                                 /* ;an000; */
/*컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�*/                                                  /* ;an000; */
                                                                                                                                 /* ;an000; */
#define FALSE    (char)(1==0)                                                                                                    /* ;an000; */
#define TRUE     !(FALSE)                                                                                                        /* ;an000; */
#define CR       '\x0d'                                                                                                          /* ;an000; */
#define LF       '\x0a'                                                                                                          /* ;an000; */
#define NUL      (char) '\0'                                                                                                     /* ;an000; */
#define TAB      '\x09'                                                                                                          /* ;an000; */
#define BLANK   ' '                                                                                                              /* ;an000; */
                                                                                                                                 /* ;an000; */

/*컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�*/                                                  /* ;an000; */
                                                                                                                                 /* ;an000; */
        unsigned far         *ArenaHeadPtr;                                                                                      /* ;an000; */
        struct   SYSIVAR far *SysVarsPtr;                                                                                        /* ;an000; */
                                                                                                                                 /* ;an000; */
        char    OwnerName[128];                                                                                                  /* ;an000; */
        char    TypeText[128];                                                                                                   /* ;an000; */
        char    cmd_line[128];                                                                                                   /* ;an000; */
        char    far *cmdline;                                                                                                    /* ;an000; */
                                                                                                                                 /* ;an000; */
        char    UseArgvZero = TRUE;                                                                                              /* ;an000; */
        char    EMSInstalledFlag = (char) 2;                                                                                     /* ;an000; */
                                                                                                                                 /* ;an000; */
        union    REGS    InRegs;                                                                                                 /* ;an000; */
        union    REGS    OutRegs;                                                                                                /* ;an000; */
        struct   SREGS   SegRegs;                                                                                                /* ;an000; */
                                                                                                                                 /* ;an000; */
        int      DataLevel;                                                                                                      /* ;an000; */
        int      i;                                                                                                              /* ;an000; */
                                                                                                                                 /* ;an000; */
        int      BlockDeviceNumber;                                                                                              /* ;an000; */
        unsigned Parse_Ptr;                                                     /* ;an003; dms; pointer to command      */
                                                                                                                                 /* ;an000; */
/*컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�*/                                                  /* ;an000; */
                                                                                                                                 /* ;an000; */
void     main(int, char *[]);                                                                                                    /* ;an000; */
                                                                                                                                 /* ;an000; */
struct memory_pool { unsigned long total, available, largest; };
static struct memory_pool conventional, upper, extended, expanded;
static int hasXms;
static void DisplaySummary(int exact);
static void DisplayClassification(void);
static int Paging, PageLines, PageHeight;
static void NextReportLine(void);
static void ReportMessage(void);
static void StartPager(void);
int      printf();
int      sprintf();
int      strcmp(const char *, const char *);
int      sscanf();                                                                                                               /* ;an000; */
void     exit(int);                                                                                                              /* ;an000; */
int      kbhit();                                                                                                                /* ;an000; */
char     *OwnerOf(struct ARENA far *);                                                                                           /* ;an000; */
char     *TypeOf(struct ARENA far *);                                                                                            /* ;an000; */
unsigned long AddressOf(char far *);                                                                                             /* ;an000; */
                                                                                                                                 /* ;an000; */
char     EMSInstalled(void);                                                                                                     /* ;an000; */
void     ReadExpandedPool(void);                                                                                                /* ;an000; */
void     DisplayEMSDetail(void);                                                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
void     ReadConventionalPool(void);                                                                                               /* ;an000; */
void XmsPool(unsigned long *);
void     ReadMemoryPools(void);
void     ReadExtendedPool(void);                                                                                           /* ;an000; */
void     DisplayExpandedSummary(void);                                                                                           /* ;an000; */
                                                                                                                                 /* ;an000; */
void     DisplayBaseDetail(void);                                                                                                /* ;an000; */
                                                                                                                                 /* ;an000; */
void     GetFromArgvZero(unsigned,unsigned far *);                                                                               /* ;an000; */
                                                                                                                                 /* ;an000; */
void     DisplayDeviceDriver(struct   DEVICEHEADER far *,int);                                                                   /* ;an000; */
                                                                                                                                 /* ;an000; */
void     parse_init(void);                                                                                                       /* ;an000; */
                                                                                                                                 /* ;an000; */
void     Parse_Message(int,int,unsigned char);                                                                                    /* ;an000; */
void     Sub0_Message(int,int,unsigned char);                                                                                    /* ;an000; */
void     Sub2_Message(int,int,unsigned char,char *,int);                                                                         /* ;an000; */
void     Sub3_Message(int,int,unsigned char,                                                                                     /* ;an000; */
                      char *,                                                                                                    /* ;an000; */
                      unsigned long int *,                                                                                       /* ;an000; */
                      int);                                                                                                      /* ;an000; */
                                                                                                                                 /* ;an000; */
void     Sub4_Message(int,int,unsigned char,                                                                                     /* ;an000; */
                      unsigned long int *,                                                                                       /* ;an000; */
                      int,                                                                                                       /* ;an000; */
                      unsigned long int *,                                                                                       /* ;an000; */
                      int);                                                                                                      /* ;an000; */
                                                                                                                                 /* ;an000; */
void     Sub4a_Message(int,int,unsigned char,                                                                                    /* ;an000; */
                      unsigned long int *,                                                                                       /* ;an000; */
                      char *,                                                                                                    /* ;an000; */
                      unsigned long int *,                                                                                       /* ;an000; */
                      char *);                                                                                                   /* ;an000; */
                                                                                                                                 /* ;an000; */
void    EMSPrint(int,int,unsigned char,                                                                                          /* ;an000; */
                 int *,                                                                                                          /* ;an000; */
                 char *,                                                                                                         /* ;an000; */
                 unsigned long int *);                                                                                           /* ;an000; */
                                                                                                                                 /* ;an000; */
extern void sysloadmsg(union REGS *, union REGS *);                                                                              /* ;an000; */
extern void sysdispmsg(union REGS *, union REGS *);                                                                              /* ;an000; */
extern void sysgetmsg(union REGS *, struct SREGS *, union REGS *);                                                               /* ;an000; */
extern void parse(union REGS *, union REGS *);                                                                                   /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                /* ;an000; */
/*컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�*/                                                  /* ;an000; */
                                                                                                                                 /* ;an000; */
void     main(argc,argv)                                                                                                         /* ;an000; */
int      argc;                                                                                                                   /* ;an000; */
char     *argv[];                                                                                                                /* ;an000; */
{                                                                                                                                /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
        sysloadmsg(&InRegs,&OutRegs);                                                                                            /* ;an000; */
        if ((OutRegs.x.cflag & CarryFlag) == CarryFlag)                                                                          /* ;an000; */
                {                                                                                                                /* ;an000; */
                sysdispmsg(&OutRegs,&OutRegs);                                                                                   /* ;an000; */
                exit(1);                                                                                                         /* ;an000; */
                }                                                                                                                /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
        InRegs.h.ah = (unsigned char) 0x62;                                     /* an000; dms; get the PSP              */       /* ;an000; */
        intdosx(&InRegs, &InRegs, &SegRegs);                                    /* an000; dms; invoke the INT 21        */       /* ;an000; */
                                                                                                                                 /* ;an000; */
        FP_OFF(cmdline) = 0x81;                                                 /* an000; dms; offset of command line   */       /* ;an000; */
        FP_SEG(cmdline) = InRegs.x.bx;                                          /* an000; dms; segment of command line  */       /* ;an000; */
                                                                                                                                 /* ;an000; */
        i = 0;                                                                  /* an000; dms; init index               */       /* ;an000; */
        while ( *cmdline != (char) '\x0d' ) cmd_line[i++] = *cmdline++;         /* an000; dms; while no CR              */       /* ;an000; */
        cmd_line[i++] = (char) '\x0d';                                          /* an000; dms; CR terminate string      */       /* ;an000; */
        cmd_line[i++] = (char) '\0';                                            /* an000; dms; null terminate string    */       /* ;an000; */
                                                                                                                                 /* ;an000; */
        DataLevel = 0;                                                                                                           /* ;an000; */
                                                                                                                                 /* ;an000; */
        parse_init();                                                           /* an000; dms; init for parser          */       /* ;an000; */
        InRegs.x.si = (unsigned)cmd_line;                                       /* an000; dms; initialize to command ln.*/       /* ;an000; */
        InRegs.x.cx = (unsigned)0;                                              /* an000; dms; ordinal of 0             */       /* ;an000; */
        InRegs.x.dx = (unsigned)0;                                              /* an000; dms; init pointer             */       /* ;an000; */
        InRegs.x.di = (unsigned)&p_p;                                           /* an000; dms; point to ctrl blocks     */       /* ;an000; */
        Parse_Ptr   = (unsigned)cmd_line;                                       /*;an003; dms; point to command         */
                                                                                                                                 /* ;an000; */
        parse(&InRegs,&OutRegs);                                                /* an000; dms; parse command line       */       /* ;an000; */
        while (OutRegs.x.ax == p_no_error)                                      /* an000; dms; good parse loop          */       /* ;an000; */
                {                                                                                                                /* ;an000; */
                if (OutRegs.x.dx == (unsigned)&page_result && !Paging) {
                        Paging = 1;
                } else if (DataLevel || OutRegs.x.dx == (unsigned)&page_result) {
                        OutRegs.x.ax = p_too_many;
                        break;
                } else if (OutRegs.x.dx == (unsigned)&classify_result) DataLevel = 3;
                else DataLevel = 2;
                Parse_Ptr = OutRegs.x.si;
                parse(&OutRegs,&OutRegs);
                }                                                                                                                /* ;an000; */
                                                                                                                                 /* ;an000; */
        if (OutRegs.x.ax != p_rc_eol)                                           /* an000; dms; parse error?             */       /* ;an000; */
                {                                                                                                                /* ;an000; */
                Parse_Message(OutRegs.x.ax,STDERR,Parse_Err_Class);             /* an000; dms; display parse error      */       /* ;an000; */
                exit(1);                                                        /* an000; dms; exit the program         */       /* ;an000; */
                }                                                                                                                /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
        if (Paging) StartPager();
        if (DataLevel == 3) DisplayClassification();
        else if (DataLevel > 0)                                                                                                       /* ;an000; */
              {                                                                                                                  /* ;an000; */
                DisplayBaseDetail();                                                                                             /* ;an000; */
                Sub0_Message(NewLineMsg,STDOUT,Utility_Msg_Class);                                                                       /* ;an000; */
                }                                                                                                                /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
        ReadConventionalPool();           /* display low memory totals */                                                          /* ;an000; */
                                                                                                                                 /* ;an000; */
        if (EMSInstalled() && (DataLevel == 2))                                                                                   /* ;an000; */
          DisplayEMSDetail();           /* display EMS memory totals */                                                          /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
        if (EMSInstalled())                                                                                                      /* ;an000; */
          ReadExpandedPool();          /* display EMS memory totals */                                                          /* ;an000; */
                                                                                                                                 /* ;an000; */
        ReadMemoryPools();
        DisplaySummary(DataLevel == 3);
                                                                                                                                 /* ;an000; */
        return;                         /* end of MEM main routine */                                                            /* ;an000; */
                                                                                                                                 /* ;an000; */
        }                                                                                                                        /* ;an000; */
                                                                                                                                 /* ;an000; */
/*컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�*/                                                  /* ;an000; */
                                                                                                                                 /* ;an000; */
void    DisplayBaseDetail()                                                                                                      /* ;an000; */
{                                                                                                                                /* ;an000; */
                                                                                                                                 /* ;an000; */
        struct   ARENA far *ThisArenaPtr;                                                                                        /* ;an000; */
        struct   ARENA far *NextArenaPtr;                                                                                        /* ;an000; */
        struct   ARENA far *ThisConfigArenaPtr;                                                                                  /* ;an000; */
        struct   ARENA far *NextConfigArenaPtr;                                                                                  /* ;an000; */
                                                                                                                                 /* ;an000; */
        struct   DEVICEHEADER far *ThisDeviceDriver;                                                                             /* ;an000; */
                                                                                                                                 /* ;an000; */
        int      SystemDataType;                                                                                                 /* ;an000; */
        char     SystemDataOwner[64];                                                                                            /* ;an000; */
                                                                                                                                 /* ;an000; */
        int     i;                                                                                                               /* ;an000; */
        unsigned int long       Out_Var1;                                                                                        /* ;an000; */
        unsigned int long       Out_Var2;                                                                                        /* ;an000; */
        char                    Out_Str1[64];                                                                                    /* ;an000; */
        char                    Out_Str2[64];                                                                                    /* ;an000; */
                                                                                                                                 /* ;an000; */
        Sub0_Message(NewLineMsg,STDOUT,Utility_Msg_Class);                                                                       /* ;an000; */
        if (DataLevel > 0)                                                                                                       /* ;an000; */
              {                                                                                                                  /* ;an000; */
                Sub0_Message(Title1Msg,STDOUT,Utility_Msg_Class);                                                                /* ;an000; */
                Sub0_Message(Title2Msg,STDOUT,Utility_Msg_Class);                                                                /* ;an000; */
                }                                                                                                                /* ;an000; */
                                                                                                                                 /* ;an000; */
        InRegs.h.ah = (unsigned char) 0x30;                                                                                      /* ;an000; */
        intdos(&InRegs, &OutRegs);                                                                                               /* ;an000; */
                                                                                                                                 /* ;an000; */
        if ( (OutRegs.h.al != (unsigned char) 3) || (OutRegs.h.ah < (unsigned char) 40) )                                        /* ;an000; */
                UseArgvZero = TRUE;                                                                                              /* ;an000; */
           else UseArgvZero = FALSE;                                                                                             /* ;an000; */
                                                                                                                                 /* ;an000; */
        /* Display stuff below DOS  */                                                                                           /* ;an000; */
                                                                                                                                 /* ;an000; */
        Out_Var1 = 0l;                                                                                                           /* ;an000; */
        Out_Var2 = 0x400l;                                                                                                       /* ;an000; */
        Sub4_Message(MainLineMsg,                                                                                                /* ;an000; */
                     STDOUT,                                                                                                     /* ;an000; */
                     Utility_Msg_Class,                                                                                          /* ;an000; */
                     &Out_Var1,                                                                                                  /* ;an000; */
                     BlankMsg,                                                                                                   /* ;an000; */
                     &Out_Var2,                                                                                                  /* ;an000; */
                     InterruptVectorMsg);                                                                                        /* ;an000; */
                                                                                                                                 /* ;an000; */
        Out_Var1 = 0x400l;                                                                                                       /* ;an000; */
        Out_Var2 = 0x100l;                                                                                                       /* ;an000; */
        Sub4_Message(MainLineMsg,                                                                                                /* ;an000; */
                     STDOUT,                                                                                                     /* ;an000; */
                     Utility_Msg_Class,                                                                                          /* ;an000; */
                     &Out_Var1,                                                                                                  /* ;an000; */
                     BlankMsg,                                                                                                   /* ;an000; */
                     &Out_Var2,                                                                                                  /* ;an000; */
                     ROMCommunicationAreaMsg);                                                                                   /* ;an000; */
                                                                                                                                 /* ;an000; */
        Out_Var1 = 0x500l;                                                                                                       /* ;an000; */
        Out_Var2 = 0x200l;                                                                                                       /* ;an000; */
        Sub4_Message(MainLineMsg,                                                                                                /* ;an000; */
                     STDOUT,                                                                                                     /* ;an000; */
                     Utility_Msg_Class,                                                                                          /* ;an000; */
                     &Out_Var1,                                                                                                  /* ;an000; */
                     BlankMsg,                                                                                                   /* ;an000; */
                     &Out_Var2,                                                                                                  /* ;an000; */
                     DOSCommunicationAreaMsg);                                                                                   /* ;an000; */
                                                                                                                                 /* ;an000; */
        /* Display the DOS data */                                                                                               /* ;an000; */
                                                                                                                                 /* ;an000; */
        InRegs.h.ah = (unsigned char) 0x52;                                                                                      /* ;an000; */
        intdosx(&InRegs,&OutRegs,&SegRegs);                                                                                      /* ;an000; */
                                                                                                                                 /* ;an000; */
        FP_SEG(SysVarsPtr) = SegRegs.es;                                                                                         /* ;an000; */
        FP_OFF(SysVarsPtr) = OutRegs.x.bx;                                                                                       /* ;an000; */
                                                                                                                                 /* ;an000; */
        /* Display the BIO location and size */                                                                                  /* ;an000; */
                                                                                                                                 /* ;an000; */
        Sub0_Message(NewLineMsg,STDOUT,Utility_Msg_Class);                                                                       /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
        Out_Var1 = 0x700l;                                                                                                       /* ;an000; */
        Out_Var2 = (long) (FP_SEG(SysVarsPtr) - 0x70)*16l;                                                                       /* ;an000; */
        Sub4_Message(MainLineMsg,                                                                                                /* ;an000; */
                     STDOUT,                                                                                                     /* ;an000; */
                     Utility_Msg_Class,                                                                                          /* ;an000; */
                     &Out_Var1,                                                                                                  /* ;an000; */
                     IbmbioMsg,                                                                                                  /* ;an000; */
                     &Out_Var2,                                                                                                  /* ;an000; */
                     SystemProgramMsg);                                                                                          /* ;an000; */
                                                                                                                                 /* ;an000; */
        /* Display the Base Device Driver Locations and Sizes */                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
        BlockDeviceNumber = 0;                                                                                                   /* ;an000; */
                                                                                                                                 /* ;an000; */
        for (ThisDeviceDriver = SysVarsPtr -> DeviceDriverChain;                                                                 /* ;an000; */
              (FP_OFF(ThisDeviceDriver) != 0xFFFF);                                                                              /* ;an000; */
               ThisDeviceDriver = ThisDeviceDriver -> NextDeviceHeader)                                                          /* ;an000; */
              { if ( FP_SEG(ThisDeviceDriver) < FP_SEG(SysVarsPtr) )                                                             /* ;an000; */
                        DisplayDeviceDriver(ThisDeviceDriver,SystemDeviceDriverMsg);                                             /* ;an000; */
                kbhit();                                                                                                         /* ;an000; */
                }                                                                                                                /* ;an000; */
                                                                                                                                 /* ;an000; */
        /* Display the DOS location and size */                                                                                  /* ;an000; */

        FP_SEG(ArenaHeadPtr) = FP_SEG(SysVarsPtr);                                                                               /* ;an004; */
        FP_OFF(ArenaHeadPtr) = FP_OFF(SysVarsPtr) - 2;                                                                           /* ;an004; */
                                                                                                                                 /* ;an004; */
        FP_SEG(ThisArenaPtr) = *ArenaHeadPtr;                                                                                    /* ;an004; */
        FP_OFF(ThisArenaPtr) = 0;                                                                                                /* ;an004; */
                                                                                                                                 /* ;an000; */
        Sub0_Message(NewLineMsg,STDOUT,Utility_Msg_Class);                                                                       /* ;an000; */
                                                                                                                                 /* ;an000; */
        Out_Var1 = (long) FP_SEG(SysVarsPtr) * 16l;                                                                              /* ;an000; */
        Out_Var2 = (long) ((AddressOf((char far *)ThisArenaPtr)) - Out_Var1);                                                    /* ;ac004; */
        Sub4_Message(MainLineMsg,                                                                                                /* ;an000; */
                     STDOUT,                                                                                                     /* ;an000; */
                     Utility_Msg_Class,                                                                                          /* ;an000; */
                     &Out_Var1,                                                                                                  /* ;an000; */
                     IbmdosMsg,                                                                                                  /* ;an000; */
                     &Out_Var2,                                                                                                  /* ;an000; */
                     SystemProgramMsg);                                                                                          /* ;an000; */
                                                                                                                                 /* ;an000; */
        Sub0_Message(NewLineMsg,STDOUT,Utility_Msg_Class);                                                                       /* ;an000; */
                                                                                                                                 /* ;an000; */
        /* Display the memory data */                                                                                            /* ;an000; */
                                                                                                                                 /* ;an000; */
        while (ThisArenaPtr -> Signature != (char) 'Z')                                                                          /* ;an000; */
              {                                                                                                                  /* ;an000; */
                                                                                                                                 /* ;an000; */
                if (ThisArenaPtr -> Owner == 8)                                                                                  /* ;an000; */
                      {                                                                                                          /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
                        Out_Var1 = AddressOf((char far *)ThisArenaPtr);                                                          /* ;an000; */
                        Out_Var2 = (long) (ThisArenaPtr -> Paragraphs) * 16l;                                                    /* ;an000; */
                        Sub4_Message(MainLineMsg,                                                                                /* ;an000; */
                                     STDOUT,                                                                                     /* ;an000; */
                                     Utility_Msg_Class,                                                                          /* ;an000; */
                                     &Out_Var1,                                                                                  /* ;an000; */
                                     IbmbioMsg,                                                                                  /* ;an000; */
                                     &Out_Var2,                                                                                  /* ;an000; */
                                     SystemDataMsg);                                                                             /* ;an000; */
                                                                                                                                 /* ;an000; */
                        FP_SEG(NextArenaPtr) = FP_SEG(ThisArenaPtr) + ThisArenaPtr -> Paragraphs + 1;                            /* ;an000; */
                        FP_OFF(NextArenaPtr) = 0;                                                                                /* ;an000; */
                                                                                                                                 /* ;an000; */
                        FP_SEG(ThisConfigArenaPtr) = FP_SEG(ThisArenaPtr) + 1;                                                   /* ;an000; */
                        FP_OFF(ThisConfigArenaPtr) = 0;                                                                          /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
                        while ( (FP_SEG(ThisConfigArenaPtr) > FP_SEG(ThisArenaPtr)) &&                                           /* ;an000; */
                                (FP_SEG(ThisConfigArenaPtr) < FP_SEG(NextArenaPtr))    )                                         /* ;an000; */
                              {                                                                                                  /* ;an000; */
                                strcpy(SystemDataOwner," ");                                                                     /* ;an000; */
                                switch(ThisConfigArenaPtr -> Signature)                                                          /* ;an000; */
                                      {                                                                                          /* ;an000; */
                                        case 'B':                                                                                /* ;an000; */
                                                SystemDataType = ConfigBuffersMsg;                                               /* ;an000; */
                                                break;                                                                           /* ;an000; */
                                        case 'D':                                                                                /* ;an000; */
                                                SystemDataType = ConfigDeviceMsg;                                                /* ;an000; */
                                                strcpy(SystemDataOwner,OwnerOf(ThisConfigArenaPtr));                             /* ;an000; */
                                                break;                                                                           /* ;an000; */
                                        case 'F':                                                                                /* ;an000; */
                                                SystemDataType = ConfigFilesMsg;                                                 /* ;an000; */
                                                break;                                                                           /* ;an000; */
                                        case 'I':                                                                                /* ;an000; */
                                                SystemDataType = ConfigIFSMsg;                                                   /* ;an000; */
                                                strcpy(SystemDataOwner,OwnerOf(ThisConfigArenaPtr));                             /* ;an000; */
                                                break;                                                                           /* ;an000; */
                                        case 'L':                                                                                /* ;an000; */
                                                SystemDataType = ConfigLastDriveMsg;                                             /* ;an000; */
                                                break;                                                                           /* ;an000; */
                                        case 'S':                                                                                /* ;an000; */
                                                SystemDataType = ConfigStacksMsg;                                                /* ;an000; */
                                                break;                                                                           /* ;an000; */
                                        case 'T':                                        /* gga */                               /* ;an000; */
                                                SystemDataType = ConfigInstallMsg;       /* gga */                               /* ;an000; */
                                                break;                                   /* gga */                               /* ;an000; */
                                        case 'X':                                                                                /* ;an000; */
                                                SystemDataType = ConfigFcbsMsg;                                                  /* ;an000; */
                                                break;                                                                           /* ;an000; */
                                        default:                                                                                 /* ;an000; */
                                                SystemDataType = BlankMsg;                                                       /* ;an000; */
                                                break;                                                                           /* ;an000; */
                                        }                                                                                        /* ;an000; */
                                Out_Var1 = ((long) ThisConfigArenaPtr -> Paragraphs) * 16l;                                      /* ;an000; */
                                Sub3_Message(DriverLineMsg,                                                                      /* ;an000; */
                                             STDOUT,                                                                             /* ;an000; */
                                             Utility_Msg_Class,                                                                  /* ;an000; */
                                             SystemDataOwner,                                                                    /* ;an000; */
                                             &Out_Var1,                                                                          /* ;an000; */
                                             SystemDataType );                                                                   /* ;an000; */
                                                                                                                                 /* ;an000; */
                                NextConfigArenaPtr = ThisConfigArenaPtr;                                                         /* ;an000; */
                                FP_SEG(NextConfigArenaPtr) += NextConfigArenaPtr -> Paragraphs + 1;                              /* ;an000; */
                                if (ThisConfigArenaPtr -> Signature == (char) 'D')                                               /* ;an000; */
                                      {                                                                                          /* ;an000; */
                                                                                                                                 /* ;an000; */
                                        FP_SEG(ThisDeviceDriver) = FP_SEG(ThisConfigArenaPtr) + 1;                               /* ;an000; */
                                        FP_OFF(ThisDeviceDriver) = 0;                                                            /* ;an000; */
                                        while ( (a(ThisDeviceDriver) > a(ThisConfigArenaPtr)) &&                                 /* ;an000; */
                                                (a(ThisDeviceDriver) < a(NextConfigArenaPtr))    )                               /* ;an000; */
                                                DisplayDeviceDriver(ThisDeviceDriver,InstalledDeviceDriverMsg);                  /* ;an000; */
                                        }                                                                                        /* ;an000; */
                                                                                                                                 /* ;an000; */
                                FP_SEG(ThisConfigArenaPtr) += ThisConfigArenaPtr -> Paragraphs + 1;                              /* ;an000; */
                                                                                                                                 /* ;an000; */
                                }                                                                                                /* ;an000; */
                                                                                                                                 /* ;an000; */
                        }                                                                                                        /* ;an000; */
                 else {                                                                                                          /* ;an000; */
                                                                                                                                 /* ;an000; */
                      Out_Var1 = AddressOf((char far *)ThisArenaPtr);                                                            /* ;an000; */
                      Out_Var2 = ((long) (ThisArenaPtr -> Paragraphs)) * 16l;                                                    /* ;an000; */
                      strcpy(Out_Str1,OwnerOf(ThisArenaPtr));                                                                    /* ;an000; */
                      strcpy(Out_Str2,TypeOf(ThisArenaPtr));                                                                     /* ;an000; */
                      Sub4a_Message(MainLineMsg,                                                                                 /* ;an000; */
                                   STDOUT,                                                                                       /* ;an000; */
                                   Utility_Msg_Class,                                                                            /* ;an000; */
                                   &Out_Var1,                                                                                    /* ;an000; */
                                   Out_Str1,                                                                                     /* ;an000; */
                                   &Out_Var2,                                                                                    /* ;an000; */
                                   Out_Str2);                                                                                    /* ;an000; */
                        }                                                                                                        /* ;an000; */
                                                                                                                                 /* ;an000; */
                FP_SEG(ThisArenaPtr) += ThisArenaPtr -> Paragraphs + 1;                                                          /* ;an000; */
                                                                                                                                 /* ;an000; */
                }                                                                                                                /* ;an000; */
        Out_Var1 = AddressOf((char far *)ThisArenaPtr);                                                                          /* ;an000; */
        Out_Var2 = ((long) (ThisArenaPtr -> Paragraphs)) * 16l;                                                                  /* ;an000; */
        strcpy(Out_Str1,OwnerOf(ThisArenaPtr));                                                                                  /* ;an000; */
        strcpy(Out_Str2,TypeOf(ThisArenaPtr));                                                                                   /* ;an000; */
        Sub4a_Message(MainLineMsg,                                                                                               /* ;an000; */
                     STDOUT,                                                                                                     /* ;an000; */
                     Utility_Msg_Class,                                                                                          /* ;an000; */
                     &Out_Var1,                                                                                                  /* ;an000; */
                     Out_Str1,                                                                                                   /* ;an000; */
                     &Out_Var2,                                                                                                  /* ;an000; */
                     Out_Str2);                                                                                                  /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
        return;                         /* end of MEM main routine */                                                            /* ;an000; */
                                                                                                                                 /* ;an000; */
        }                                                                                                                        /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                /* ;an000; */
/*컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�*/                                                  /* ;an000; */
                                                                                                                                 /* ;an000; */
void     DisplayDeviceDriver(ThisDeviceDriver,DeviceDriverType)                                                                  /* ;an000; */
struct   DEVICEHEADER far *ThisDeviceDriver;                                                                                     /* ;an000; */
int      DeviceDriverType;                                                                                                       /* ;an000; */
{                                                                                                                                /* ;an000; */
        char     LocalDeviceName[16];                                                                                            /* ;an000; */
        int      i;                                                                                                              /* ;an000; */
                                                                                                                                 /* ;an000; */
        if (DataLevel < 2) return;                                                                                               /* ;an000; */
                                                                                                                                 /* ;an000; */
        if ( ((ThisDeviceDriver -> Attributes) & 0x8000 ) != 0 )                                                                 /* ;an000; */
              { for (i = 0; i < 8; i++) LocalDeviceName[i] = ThisDeviceDriver -> Name[i];                                        /* ;an000; */
                LocalDeviceName[8] = NUL;                                                                                        /* ;an000; */
                                                                                                                                 /* ;an000; */
                Sub2_Message(DeviceLineMsg,                                                                                      /* ;an000; */
                             STDOUT,                                                                                             /* ;an000; */
                             Utility_Msg_Class,                                                                                  /* ;an000; */
                             LocalDeviceName,                                                                                    /* ;an000; */
                             DeviceDriverType);                                                                                  /* ;an000; */
                                                                                                                                 /* ;an000; */
                }                                                                                                                /* ;an000; */
                                                                                                                                 /* ;an000; */
         else {                                                                                                                  /* ;an000; */
                if ((int) ThisDeviceDriver -> Name[0] == 1)                                                                      /* ;an000; */
                        sprintf(&LocalDeviceName[0],SingleDrive,'A'+BlockDeviceNumber);                                          /* ;an000; */
                   else sprintf(&LocalDeviceName[0],MultipleDrives,                                                              /* ;an000; */
                                'A'+BlockDeviceNumber,                                                                           /* ;an000; */
                                'A'+BlockDeviceNumber + ((int) ThisDeviceDriver -> Name[0]) - 1);                                /* ;an000; */
                                                                                                                                 /* ;an000; */
                Sub2_Message(DeviceLineMsg,                                                                                      /* ;an000; */
                             STDOUT,                                                                                             /* ;an000; */
                             Utility_Msg_Class,                                                                                  /* ;an000; */
                             LocalDeviceName,                                                                                    /* ;an000; */
                             DeviceDriverType);                                                                                  /* ;an000; */
                                                                                                                                 /* ;an000; */
                BlockDeviceNumber += (int) (ThisDeviceDriver -> Name[0]);                                                        /* ;an000; */
                                                                                                                                 /* ;an000; */
                }                                                                                                                /* ;an000; */
                                                                                                                                 /* ;an000; */
        return;                                                                                                                  /* ;an000; */
                                                                                                                                 /* ;an000; */
        }                                                                                                                        /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                /* ;an000; */
/*컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�*/                                                  /* ;an000; */
                                                                                                                                 /* ;an000; */
void ReadConventionalPool()                                                                                                        /* ;an000; */
        {                                                                                                                        /* ;an000; */
                                                                                                                                 /* ;an000; */
        struct ARENA far *arena;
        unsigned far *head;
        unsigned psp, segment, next, first, limit;
        /* Conventional capacity comes from the BIOS base-memory count. */                                                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
        unsigned long int total_mem;              /* total memory in system */                                                   /* ;an000; */
        unsigned long int avail_mem;              /* avail memory in system */                                                   /* ;an000; */
        unsigned long int free_mem;               /* free memory */                                                              /* ;an000; */
                                                                                                                                 /* ;an000; */
/*  get PSP info */                                                                                                              /* ;an000; */
        InRegs.h.ah = GET_PSP;                  /* get PSP function call */                                                      /* ;an000; */
        intdos(&InRegs,&OutRegs);                                                                                                /* ;an000; */
                                                                                                                                 /* ;an000; */
        psp = OutRegs.x.bx;

/* Get total memory in system */                                                                                                 /* ;an000; */
        int86(MEMORY_DET,&InRegs,&OutRegs);                                                                                      /* ;an000; */
                                                                                                                                 /* ;an000; */
/* Convert to bytes */                                                                                                           /* ;an000; */
        total_mem = (unsigned long int) OutRegs.x.ax * 1024l;                                                                    /* ;an000; */
        avail_mem = total_mem;
        conventional.total = avail_mem;

/* Adjacent free blocks and this process's blocks coalesce when MEM exits. */
        limit = (unsigned)(avail_mem / 16UL);
        InRegs.x.ax = 0x5200;
        intdosx(&InRegs,&OutRegs,&SegRegs);
        FP_SEG(head) = SegRegs.es;
        FP_OFF(head) = OutRegs.x.bx - 2;
        FP_OFF(arena) = 0;
        first = 0;
        free_mem = 0;
        for (segment = *head; segment < limit; segment = next) {
            FP_SEG(arena) = segment;
            if (arena->Signature != 'M' && arena->Signature != 'Z') break;
            next = segment + arena->Paragraphs + 1;
            if (next <= segment || next > limit) break;
            if (arena->Owner == 0 || arena->Owner == psp) {
                conventional.available += (next - segment) * 16UL;
                if (!first) first = segment;
                if ((next - first - 1) * 16UL > free_mem)
                    free_mem = (next - first - 1) * 16UL;
            } else first = 0;
            if (arena->Signature == 'Z') break;
        }
        conventional.largest = free_mem;
                                                                                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
        return;                                                                                                                  /* ;an000; */
                                                                                                                                 /* ;an000; */
        }                       /* end of display_low_total */                                                                   /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                /* ;an000; */
/*컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�*/                                                  /* ;an000; */
                                                                                                                                 /* ;an000; */
void DisplayEMSDetail()                                                                                                          /* ;an000; */
  {                                                                                                                              /* ;an000; */
                                                                                                                                 /* ;an000; */
#define EMSGetHandleName 0x5300         /* get handle name function */                                                           /* ;an000; */
#define EMSGetHandlePages 0x4c00        /* get handle name function */                                                           /* ;an000; */
#define EMSCODE_83      0x83            /* handle not found error */                                                             /* ;an000; */
#define EMSMaxHandles   256             /* max number handles */                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
  int   HandleIndex;                    /* used to step through handles */                                                       /* ;an000; */
  char  HandleName[9];                  /* save area for handle name */                                                          /* ;an000; */
  unsigned long int HandleMem;          /* memory associated w/handle */                                                         /* ;an000; */
  char  TitlesPrinted = FALSE;          /* flag for printing titles */                                                           /* ;an000; */
                                                                                                                                 /* ;an000; */
  HandleName[0] = NUL;                  /* initialize the array         */                                                       /* ;an000; */
                                                                                                                                 /* ;an000; */
  Sub0_Message(NewLineMsg,STDOUT,Utility_Msg_Class);                                                                             /* ;an000; */
                                                                                                                                 /* ;an000; */
  segread(&SegRegs);                                                                                                             /* ;an000; */
                                                                                                                                 /* ;an000; */
  SegRegs.es = SegRegs.ds;                                                                                                       /* ;an000; */
                                                                                                                                 /* ;an000; */
  for (HandleIndex = 0; HandleIndex < EMSMaxHandles; HandleIndex++)                                                              /* ;an000; */
    {                                                                                                                            /* ;an000; */
                                                                                                                                 /* ;an000; */
    InRegs.x.ax = EMSGetHandleName;     /* get handle name */                                                                    /* ;an000; */
    InRegs.x.dx = HandleIndex;          /* handle in question */                                                                 /* ;an000; */
    InRegs.x.di = (unsigned int) HandleName;    /* point to handle name */                                                       /* ;an000; */
    int86x(EMS, &InRegs, &OutRegs, &SegRegs);                                                                                    /* ;an000; */
                                                                                                                                 /* ;an000; */
    HandleName[8] = NUL;                /* make sure terminated w/nul */                                                         /* ;an000; */
                                                                                                                                 /* ;an000; */
    if (OutRegs.h.ah != EMSCODE_83)                                                                                              /* ;an000; */
      {                                                                                                                          /* ;an000; */
      InRegs.x.ax = EMSGetHandlePages;  /* get pages assoc w/this handle */                                                      /* ;an000; */
      InRegs.x.dx = HandleIndex;                                                                                                 /* ;an000; */
      int86x(EMS, &InRegs, &OutRegs, &SegRegs);                                                                                  /* ;an000; */
      HandleMem = OutRegs.x.bx;                                                                                                  /* ;an000; */
      HandleMem *= (long) (16l*1024l);                                                                                           /* ;an000; */
                                                                                                                                 /* ;an000; */
      if (!TitlesPrinted)                                                                                                        /* ;an000; */
        {                                                                                                                        /* ;an000; */
        Sub0_Message(Title3Msg,STDOUT,Utility_Msg_Class);                                                                        /* ;an000; */
        Sub0_Message(Title4Msg,STDOUT,Utility_Msg_Class);                                                                        /* ;an000; */
        TitlesPrinted = TRUE;                                                                                                    /* ;an000; */
        }                                                                                                                        /* ;an000; */
                                                                                                                                 /* ;an000; */
      if (HandleName[0] == NUL) strcpy(HandleName,"        ");                                                                   /* ;an000; */
      EMSPrint(HandleMsg,                                                                                                        /* ;an000; */
               STDOUT,                                                                                                           /* ;an000; */
               Utility_Msg_Class,                                                                                                /* ;an000; */
               &HandleIndex,                                                                                                     /* ;an000; */
               HandleName,                                                                                                       /* ;an000; */
               &HandleMem);                                                                                                      /* ;an000; */
      }                                                                                                                          /* ;an000; */
                                                                                                                                 /* ;an000; */
    }                                   /* end   for (HandleIndex = 0; HandleIndex < EMSMaxHandles;HandleIndex++) */             /* ;an000; */
                                                                                                                                 /* ;an000; */
  return;                                                                                                                        /* ;an000; */
                                                                                                                                 /* ;an000; */
  }                                     /* end of DisplayEMSDetail */                                                            /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                /* ;an000; */
/*컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�*/                                                  /* ;an000; */
                                                                                                                                 /* ;an000; */
/* One line is reserved for the prompt. DOS messages used by the reports
 * each occupy one line; errors and redirected reports are never paged. */
static char far *UtilityText(unsigned number)
{
    union REGS in, out;
    struct SREGS segments;
    char far *text;
    in.x.ax = number;
    in.h.dh = Utility_Msg_Class;
    sysgetmsg(&in, &segments, &out);
    FP_SEG(text) = segments.ds;
    FP_OFF(text) = out.x.si;
    return text;
}

static void StartPager(void)
{
    union REGS r;
    unsigned char far *lastRow;
    r.x.ax = 0x4400;
    r.x.bx = STDOUT;
    intdos(&r,&r);
    /* Character device, console output (including CTTY), and not NUL. */
    Paging = !r.x.cflag && (r.x.dx & 0x86) == 0x82;
    FP_SEG(lastRow) = 0x40;
    FP_OFF(lastRow) = 0x84;
    PageHeight = (*lastRow >= 24 && *lastRow <= 99) ? *lastRow : 24;
}

static void NextReportLine(void)
{
    union REGS r;
    char key;
    if (!Paging) return;
    if (PageLines == PageHeight) {
        printf("%Fs", UtilityText(PagerMsg));
        fflush(stdout);
        r.x.ax = 0x4400;
        r.x.bx = 0;
        intdos(&r,&r);
        if (!r.x.cflag && (r.x.dx & 0x80) && !(r.x.dx & 4)) {
            r.h.ah = 8;
            intdos(&r,&r);
            if (!r.h.al) { r.h.ah = 8; intdos(&r,&r); }
        } else {
            r.h.ah = 0x3f;
            r.x.bx = 0;
            r.x.cx = 1;
            r.x.dx = (unsigned)&key;
            intdos(&r,&r);
            if (r.x.cflag || !r.x.ax) Paging = 0;
        }
        printf("\n");
        PageLines = 0;
    }
    ++PageLines;
}

static void ReportMessage(void)
{
    if (InRegs.x.bx == STDOUT) NextReportLine();
    sysdispmsg(&InRegs,&OutRegs);
}

static void ReportLine(char far *line)
{
    NextReportLine();
    printf("%Fs\n", line);
}

/* Emit numeric fields ourselves so both summary modes fit an 80-column screen. */
static char *Number(char *field, unsigned long bytes, int exact)
{
    char digits[12];
    unsigned i, n = 0, length;
    if (!exact) bytes = bytes / 1024 + (bytes % 1024 >= 512);
    sprintf(digits, "%lu", bytes);
    length = strlen(digits);
    for (i = 0; i < length; ++i) {
        if (i && (length-i) % 3 == 0) field[n++] = ',';
        field[n++] = digits[i];
    }
    if (!exact) field[n++] = 'K';
    field[n] = 0;
    return field;
}

/* The title, rules and numeric cells share the same column boundaries. */
static void SummaryLine(char far *name, char far *total, char far *used, char far *avail)
{
    NextReportLine();
    printf("%-18Fs %13Fs %13Fs %13Fs\n", name, total, used, avail);
}

static void ModuleLine(char far *name, char far *total, char far *low, char far *high)
{
    NextReportLine();
    printf("%-8Fs   %17Fs   %17Fs   %17Fs\n", name, total, low, high);
}

static char *ModuleSize(char *field, unsigned long bytes)
{
    char count[16], kbytes[16];
    sprintf(field, "%9s (%4s)", Number(count,bytes,1), Number(kbytes,bytes,0));
    return field;
}

static void PoolRow(char far *name, unsigned long total, unsigned long avail, int exact)
{
    char a[16], b[16], c[16];
    SummaryLine(name, Number(a,total,exact), Number(b,total-avail,exact),
                Number(c,avail,exact));
}

static void SizeLine(char far *name, unsigned long bytes)
{
    char k[16], b[16];
    NextReportLine();
    printf("%-34Fs %10s (%s %Fs)\n", name, Number(k,bytes,0),
            Number(b,bytes,1), UtilityText(BytesUnitMsg));
}

static void DisplaySummary(int exact)
{
    unsigned long below = conventional.total + upper.total;
    unsigned long freeBelow = conventional.available + upper.available;
    unsigned long reserved = 1048576UL - below;
    char *rule = "-------------";
    ReportLine("");
    SummaryLine(UtilityText(MemoryTypeMsg), UtilityText(TotalMsg), UtilityText(UsedMsg), UtilityText(FreeLabelMsg));
    SummaryLine("------------------", rule, rule, rule);
    PoolRow(UtilityText(ConventionalMsg), conventional.total, conventional.available, exact);
    PoolRow(UtilityText(UpperMsg), upper.total, upper.available, exact);
    PoolRow(UtilityText(ReservedMsg), reserved, 0UL, exact);
    PoolRow(hasXms ? UtilityText(ExtendedXmsMsg) : UtilityText(ExtendedMsg), extended.total,
            extended.available, exact);
    SummaryLine("------------------", rule, rule, rule);
    PoolRow(UtilityText(TotalMemoryLabelMsg), 1048576UL + extended.total,
            freeBelow + extended.available, exact);
    ReportLine("");
    PoolRow(UtilityText(Below1MBMsg), below, freeBelow, exact);
    if (expanded.total) {
        ReportLine("");
        SizeLine(UtilityText(TotalEmsMsg), expanded.total);
        SizeLine(UtilityText(FreeEmsMsg), expanded.available);
    }
    if (hasXms) {
        ReportLine("");
        SizeLine(UtilityText(TotalXmsMsg), extended.total);
        SizeLine(UtilityText(FreeXmsMsg), extended.available);
        SizeLine(UtilityText(LargestXmsMsg), extended.largest);
    }
    ReportLine("");
    SizeLine(UtilityText(LargestProgramMsg), conventional.largest);
    SizeLine(UtilityText(LargestUpperMsg), upper.largest);
}

/* Classify MCBs by resident module. Charge the paragraph containing each
 * header to its block. MEM's own allocations become free when it exits. */
/* ModuleName accepts printable names, so these two keys cannot collide. */
#define SYSTEM_ROW_KEY "\001"
#define FREE_ROW_KEY   "\002"
struct module_usage {
    struct module_usage *next;
    char name[9];
    unsigned long conventional, upper;
};

static int AddUsage(struct module_usage **rows, char *name, unsigned long bytes,
                    int upper)
{
    struct module_usage *row;
    while ((row = *rows) != NULL && strcmp(row->name, name) != 0)
        rows = &row->next;
    if (!row) {
        row = calloc(1, sizeof(*row));
        if (!row) return 0;
        strcpy(row->name, name);
        *rows = row;
    }
    if (upper) row->upper += bytes;
    else row->conventional += bytes;
    return 1;
}

static void ModuleName(char *name, struct ARENA far *arena)
{
    int i;
    for (i = 0; i < 8 && (unsigned char)arena->OwnerName[i] > ' '; ++i)
        name[i] = arena->OwnerName[i];
    name[i] = 0;
}

/* The DOS-owned conventional arena contains SYSINIT's device markers.
 * Attribute named drivers to their own rows; leave the rest under SYSTEM. */
static int ClassifySystem(struct module_usage **rows, unsigned segment,
                          unsigned end, unsigned long bytes)
{
    struct ARENA far *mark;
    char name[9];
    unsigned next;
    FP_OFF(mark) = 0;
    for (++segment; segment < end; segment = next) {
        FP_SEG(mark) = segment;
        next = segment + mark->Paragraphs + 1;
        if (next <= segment || next > end) break;
        if (mark->Signature == 'D' || mark->Signature == 'I') {
            unsigned long size = (next - segment) * 16UL;
            ModuleName(name, mark);
            if (name[0]) {
                if (!AddUsage(rows, name, size, 0)) return 0;
                bytes -= size;
            }
        }
    }
    return AddUsage(rows, SYSTEM_ROW_KEY, bytes, 0);
}

static void DisplayClassification(void)
{
    struct ARENA far *arena, far *owner;
    struct module_usage *rows = NULL, *row;
    unsigned far *head;
    unsigned segment, next, limit, psp;
    int restore = 0, ok = 1;
    unsigned long upperTotal = 0, accounted = 0, bytes;
    char name[9];

    int86(MEMORY_DET, &InRegs, &OutRegs);
    limit = OutRegs.x.ax * 64;
    InRegs.h.ah = GET_PSP;
    intdos(&InRegs, &OutRegs);
    psp = OutRegs.x.bx;
    InRegs.x.ax = 0x58ff;
    intdos(&InRegs, &OutRegs);
    if (!OutRegs.x.cflag) upperTotal = OutRegs.x.ax * 16UL;
    InRegs.x.ax = 0x5802;
    intdos(&InRegs, &OutRegs);
    if (!OutRegs.x.cflag && !OutRegs.h.al) {
        InRegs.x.ax = 0x5803;
        InRegs.x.bx = 1;
        intdos(&InRegs, &OutRegs);
        restore = !OutRegs.x.cflag;
    }
    InRegs.x.ax = 0x5200;
    intdosx(&InRegs, &OutRegs, &SegRegs);
    FP_SEG(head) = SegRegs.es;
    FP_OFF(head) = OutRegs.x.bx - 2;
    segment = *head;
    ok = AddUsage(&rows, SYSTEM_ROW_KEY, segment * 16UL, 0);
    FP_OFF(arena) = FP_OFF(owner) = 0;
    while (ok) {
        FP_SEG(arena) = segment;
        if (arena->Signature != 'M' && arena->Signature != 'Z') break;
        next = segment + arena->Paragraphs + 1;
        if (next <= segment) break;
        bytes = (next - segment) * 16UL;
        if (arena->Owner == 8 && next > limit) {
            /* SYSINIT links disjoint UMBs with inaccessible gap MCBs. */
            if (segment < limit)
                ok = AddUsage(&rows, SYSTEM_ROW_KEY, (limit - segment) * 16UL, 0);
        } else if (arena->Owner == 8) {
            ok = ClassifySystem(&rows, segment, next, bytes);
        } else {
            if (!arena->Owner || arena->Owner == psp) strcpy(name, FREE_ROW_KEY);
            else {
                FP_SEG(owner) = arena->Owner - 1;
                ModuleName(name, owner);
                if (!name[0]) sprintf(name, "%04X", arena->Owner);
            }
            ok = AddUsage(&rows, name, bytes, segment >= limit);
            if (segment >= limit) accounted += bytes;
        }
        if (arena->Signature == 'Z') break;
        segment = next;
    }
    if (restore) {
        InRegs.x.ax = 0x5803;
        InRegs.x.bx = 0;
        intdos(&InRegs, &OutRegs);
    }
    /* Boot-time upper allocations are removed from the allocatable chain. */
    if (ok && upperTotal > accounted)
        ok = AddUsage(&rows, SYSTEM_ROW_KEY, upperTotal - accounted, 1);
    if (ok) {
        ReportLine(UtilityText(ModuleTitleMsg));
        ReportLine("");
        ModuleLine(UtilityText(NameMsg), UtilityText(TotalMsg),
                   UtilityText(ConventionalMsg), UtilityText(UpperMemoryMsg));
        ModuleLine("--------", "-----------------", "-----------------", "-----------------");
    } else ReportLine(UtilityText(ClassMemoryErrorMsg));
    while (rows) {
        char all[24], low[24], high[24];
        row = rows;
        if (ok) {
            unsigned long total = row->conventional + row->upper;
            char far *label = row->name;
            if (row->name[0] == 1 /* SYSTEM_ROW_KEY */) label = UtilityText(SystemLabelMsg);
            if (row->name[0] == 2 /* FREE_ROW_KEY */) label = UtilityText(FreeLabelMsg);
            ModuleLine(label, ModuleSize(all,total), ModuleSize(low,row->conventional),
                       ModuleSize(high,row->upper));
        }
        rows = row->next;
        free(row);
    }
}

void ReadMemoryPools(void)
{
    struct ARENA far *arena;
    unsigned far *head;
    unsigned segment, next;
    unsigned long xms[3];
    unsigned long umbTotal = 0;
    unsigned long block, freeBytes = 0, largestBytes = 0;
    unsigned linked, psp, firstFree = 0;
    InRegs.h.ah = GET_PSP;
    intdos(&InRegs,&OutRegs);
    psp = OutRegs.x.bx;

    InRegs.x.ax = 0x58ff;            /* paragraphs granted by the UMB provider */
    intdos(&InRegs,&OutRegs);
    if (!OutRegs.x.cflag) umbTotal = OutRegs.x.ax * 16UL;
    InRegs.x.ax = 0x5802;
    intdos(&InRegs,&OutRegs);
    if (!OutRegs.x.cflag) {
        linked = OutRegs.h.al;
        InRegs.x.ax = 0x5803;
        InRegs.x.bx = 1;
        intdos(&InRegs,&OutRegs);
        if (!OutRegs.x.cflag) {
            InRegs.x.ax = 0x5200;
            intdosx(&InRegs,&OutRegs,&SegRegs);
            FP_SEG(head) = SegRegs.es;
            FP_OFF(head) = OutRegs.x.bx - 2;
            segment = *head;
            FP_OFF(arena) = 0;
            for (;;) {
                FP_SEG(arena) = segment;
                if (arena->Signature != 'M' && arena->Signature != 'Z') break;
                if (segment >= 0xa000 && (!arena->Owner || arena->Owner == psp)) {
                    block = arena->Paragraphs * 16UL;
                    freeBytes += block + 16;
                    if (!firstFree) firstFree = segment;
                    block += (segment - firstFree) * 16UL;
                    if (block > largestBytes) largestBytes = block;
                } else firstFree = 0;
                next = segment + arena->Paragraphs + 1;
                if (arena->Signature == 'Z' || next <= segment) break;
                segment = next;
            }
            InRegs.x.ax = 0x5803;
            InRegs.x.bx = linked;
            intdos(&InRegs,&OutRegs);
        }
    }
    upper.total = umbTotal;
    upper.available = freeBytes;
    upper.largest = largestBytes;
    xms[0] = xms[1] = xms[2] = 0;
    XmsPool(xms);
    if (xms[0]) {
        hasXms = 1;
        extended.total = xms[0] * 1024UL;
        extended.available = xms[1] * 1024UL;
        extended.largest = xms[2] * 1024UL;
    } else {
        ReadExtendedPool();
    }
}

void ReadExtendedPool()                                                                                                    /* ;an000; */
  {                                                                                                                              /* ;an000; */
                                                                                                                                 /* ;an000; */
  unsigned long int       EXTMemoryTot;                                                                                          /* ;an000; */
                                                                                                                                 /* ;an000; */
  InRegs.h.ah = (unsigned char) 0x52;                                           /* Get SysVar Pointer   ;an001; dms;*/
  intdosx(&InRegs,&OutRegs,&SegRegs);                                           /* Invoke interrupt     ;an001; dms;*/
                                                                                                                                                         /* ;an000; */
  FP_SEG(SysVarsPtr) = SegRegs.es;                                              /* put pointer in var   ;an001; dms;*/
  FP_OFF(SysVarsPtr) = OutRegs.x.bx;                                            /*                      ;an001; dms;*/
  if ((SysVarsPtr) -> ExtendedMemory != 0)                                      /* extended memory?     ;an001; dms;*/
  {                                                                             /* yes                  ;an001; dms;*/
      EXTMemoryTot = (long) (SysVarsPtr) -> ExtendedMemory;                     /* get total EM size    ;an001; dms;*/
      EXTMemoryTot *= (long) 1024l;                                             /*  at boot time        ;an001; dms;*/
      /* Values are displayed together in the summary table. */                        /* print blank line     ;an001; dms;*/
      extended.total = EXTMemoryTot;
                                                                                                                                 /* ;an000; */
      OutRegs.x.cflag = 0;                                                      /* clear carry flag     ;an001; dms;*/
      InRegs.x.ax = GetExtended;                                                /* get extended mem     ;an001; dms;*/
                                                                                /*   available                      */
      int86(CASSETTE, &InRegs, &OutRegs);                                       /* INT 15h call         ;an001; dms;*/

      EXTMemoryTot = (long) OutRegs.x.ax;                                       /* returns 1K mem blocks;an001; dms;*/
      EXTMemoryTot *= (long) 1024l;                                             /* convert to bytes     ;an001; dms;*/

      if (!OutRegs.x.cflag) extended.available = EXTMemoryTot;
  }

                                                                                                                                 /* ;an000; */
  return;                                                                                                                        /* ;an000; */
                                                                                                                                 /* ;an000; */
  }                                     /* end of ReadExtendedPool */                                                      /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                /* ;an000; */
/*컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�*/                                                  /* ;an000; */
                                                                                                                                 /* ;an000; */
void ReadExpandedPool()                                                                                                         /* ;an000; */
  {                                                                                                                              /* ;an000; */
                                                                                                                                 /* ;an000; */
  unsigned long int       EMSFreeMemoryTot;                                                                                      /* ;an000; */
  unsigned long int       EMSAvailMemoryTot;                                                                                     /* ;an000; */
                                                                                                                                 /* ;an000; */

                                                                                                                                 /* ;an000; */
  InRegs.x.ax = EMSGetFreePgs;              /* get total number unallocated pages */                                             /* ;an000; */
  int86x(EMS, &InRegs, &OutRegs, &SegRegs);                                                                                      /* ;an000; */
                                                                                                                                 /* ;an000; */
  EMSFreeMemoryTot = OutRegs.x.bx;          /* total unallocated pages in  BX */                                                 /* ;an000; */
  EMSFreeMemoryTot *= (long) (16l*1024l);                                                                                        /* ;an000; */
                                                                                                                                 /* ;an000; */
  EMSAvailMemoryTot = OutRegs.x.dx;         /* total pages */                                                                    /* ;an000; */
  EMSAvailMemoryTot *= (long) (16l*1024l);                                                                                       /* ;an000; */
                                                                                                                                 /* ;an000; */
  expanded.total = EMSAvailMemoryTot;
  expanded.available = EMSFreeMemoryTot;
                                                                                                                                 /* ;an000; */
  return;                                                                                                                        /* ;an000; */
                                                                                                                                 /* ;an000; */
  }                                     /* end of ReadExpandedPool */                                                           /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                /* ;an000; */
/*컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�*/                                                  /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
char EMSInstalled()                                                                                                              /* ;an000; */
  {                                                                                                                              /* ;an000; */
                                                                                                                                 /* ;an000; */
  unsigned int  EMSStatus;                                                                                                       /* ;an000; */
  unsigned int  EMSVersion;                                                                                                      /* ;an000; */
  char          ReturnFlag;                                                                                                      /* ;an000; */
                                                                                                                                 /* ;an000; */
  if (EMSInstalledFlag == 2)                                                                                                     /* ;an000; */
    {                                                                                                                            /* ;an000; */
    EMSInstalledFlag = FALSE;                                                                                                    /* ;an000; */
    InRegs.h.ah = GET_VECT;               /* get int 67 vector */                                                                /* ;an000; */
    InRegs.h.al = EMS;                                                                                                           /* ;an000; */
    intdosx(&InRegs,&OutRegs,&SegRegs);                                                                                          /* ;an000; */
                                                                                                                                 /* ;an000; */
    /* only want to try this if vector is non-zero */                                                                            /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
    if ((SegRegs.es != 0) && (OutRegs.x.bx != 0))                                                                                /* ;an000; */
      {                                                                                                                          /* ;an000; */
      InRegs.x.ax = EMSGetStat;           /* get EMS status */                                                                   /* ;an000; */
      int86x(EMS, &InRegs, &OutRegs, &SegRegs);                                                                                  /* ;an000; */
      EMSStatus = OutRegs.h.ah;           /* EMS status returned in AH */                                                        /* ;an000; */
                                                                                                                                 /* ;an000; */
      InRegs.x.ax = EMSGetVer;            /* get EMS version */                                                                  /* ;an000; */
      int86x(EMS, &InRegs, &OutRegs, &SegRegs);                                                                                  /* ;an000; */
      EMSVersion = OutRegs.h.al;          /* EMS version returned in AL */                                                       /* ;an000; */
                                                                                                                                 /* ;an000; */
      if ((EMSStatus == 0) && (EMSVersion >= DOSEMSVER))                                                                         /* ;an000; */
        EMSInstalledFlag = TRUE;                                                                                                 /* ;an000; */
      else                                                                                                                       /* ;an000; */
        EMSInstalledFlag = FALSE;                                                                                                /* ;an000; */
                                                                                                                                 /* ;an000; */
      }                                   /* end ((SegRegs.es != 0) && (OutRegs.x.bx != 0)) */                                   /* ;an000; */
                                                                                                                                 /* ;an000; */
    }                                   /* end if (EMSInstalledFlag == 2) */                                                     /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
  return(EMSInstalledFlag);                                                                                                      /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
  }                                                                                                                              /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                /* ;an000; */
/*컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�*/                                                  /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
char *OwnerOf(ArenaPtr)                                                                                                          /* ;an000; */
struct ARENA far *ArenaPtr;                                                                                                      /* ;an000; */
{                                                                                                                                /* ;an000; */
                                                                                                                                 /* ;an000; */
        char     far *StringPtr;                                                                                                 /* ;an000; */
        unsigned far *WordPtr;                                                                                                   /* ;an000; */
        char         *o;                                                                                                         /* ;an000; */
        unsigned far *EnvironmentSegmentPtr;                                                                                     /* ;an000; */
        unsigned     PspSegment;                                                                                                 /* ;an000; */
        int          i;                                                                                                          /* ;an000; */
                                                                                                                                 /* ;an000; */
        o = &OwnerName[0];                                                                                                       /* ;an000; */
        *o = NUL;                                                                                                                /* ;an000; */
        sprintf(o,UnOwned);                                                                                                      /* ;an000; */
                                                                                                                                 /* ;an000; */
        PspSegment = ArenaPtr -> Owner;                                                                                          /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
        if (PspSegment == 0) sprintf(o,Ibmdos);                                                                                  /* ;an000; */
         else if (PspSegment == 8) sprintf(o,Ibmbio);                                                                            /* ;an000; */
          else {                                                                                                                 /* ;an000; */
                FP_SEG(ArenaPtr) = PspSegment-1;        /* -1 'cause Arena is 16 bytes before PSP */                             /* ;an000; */
                StringPtr = (char far *) &(ArenaPtr -> OwnerName[0]);                                                            /* ;an000; */
                for (i = 0; i < 8; i++) *o++ = *StringPtr++;                                                                     /* ;an000; */
                *o = (char) '\0';                                                                                                /* ;an000; */
                }                                                                                                                /* ;an000; */
                                                                                                                                 /* ;an000; */
        if (UseArgvZero) GetFromArgvZero(PspSegment,EnvironmentSegmentPtr);                                                      /* ;an000; */
                                                                                                                                 /* ;an000; */
        return(&OwnerName[0]);                                                                                                   /* ;an000; */
                                                                                                                                 /* ;an000; */
        }                                                                                                                        /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                /* ;an000; */
/*컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�*/                                                  /* ;an000; */
                                                                                                                                 /* ;an000; */
void         GetFromArgvZero(PspSegment,EnvironmentSegmentPtr)                                                                   /* ;an000; */
unsigned     PspSegment;                                                                                                         /* ;an000; */
unsigned far *EnvironmentSegmentPtr;                                                                                             /* ;an000; */
{                                                                                                                                /* ;an000; */
                                                                                                                                 /* ;an000; */
        char    far *StringPtr;                                                                                                  /* ;an000; */
        char    *OutputPtr;                                                                                                      /* ;an000; */
        unsigned far *WordPtr;                                                                                                   /* ;an000; */
                                                                                                                                 /* ;an000; */
        OutputPtr = &OwnerName[0];                                                                                               /* ;an000; */
                                                                                                                                 /* ;an000; */
        if (UseArgvZero)                                                                                                         /* ;an000; */
              {                                                                                                                  /* ;an000; */
                if (PspSegment < FP_SEG(ArenaHeadPtr))                                                                           /* ;an000; */
                      {                                                                                                          /* ;an000; */
                        if (*OutputPtr == NUL) sprintf(OutputPtr,Ibmdos);                                                        /* ;an000; */
                        }                                                                                                        /* ;an000; */
                 else {                                                                                                          /* ;an000; */
                        FP_SEG(EnvironmentSegmentPtr) = PspSegment;                                                              /* ;an000; */
                        FP_OFF(EnvironmentSegmentPtr) = 44;                                                                      /* ;an000; */
                                                                                                                                 /* ;an000; */
/*                         FP_SEG(StringPtr) = *EnvironmentSegmentPtr;  */                                                          /* ;an000; */
                        FP_SEG(StringPtr) = FP_SEG(EnvironmentSegmentPtr);                                                              /* ;an000; */
                        FP_OFF(StringPtr) = 0;                                                                                   /* ;an000; */
                                                                                                                                 /* ;an000; */
                        while ( (*StringPtr != NUL) || (*(StringPtr+1) != NUL) ) StringPtr++;                                    /* ;an000; */
                                                                                                                                 /* ;an000; */
                        StringPtr += 2;                                                                                          /* ;an000; */
                        WordPtr = (unsigned far *) StringPtr;                                                                    /* ;an000; */
                                                                                                                                 /* ;an000; */
                        if (*WordPtr == 1)                                                                                       /* ;an000; */
                              {                                                                                                  /* ;an000; */
                                StringPtr += 2;                                                                                  /* ;an000; */
                                while (*StringPtr != NUL)                                                                        /* ;an000; */
                                        *OutputPtr++ = *StringPtr++;                                                             /* ;an000; */
                                *OutputPtr++ = NUL;                                                                              /* ;an000; */
                                                                                                                                 /* ;an000; */
                                while ( OutputPtr > &OwnerName[0] )                                                              /* ;an000; */
                                      { if (*OutputPtr == (char) '.') *OutputPtr = NUL;                                          /* ;an000; */
                                        if ( (*OutputPtr == (char) '\\') || (*OutputPtr == (char) ':') )                         /* ;an000; */
                                              { OutputPtr++;                                                                     /* ;an000; */
                                                break;                                                                           /* ;an000; */
                                                }                                                                                /* ;an000; */
                                        OutputPtr--;                                                                             /* ;an000; */
                                        }                                                                                        /* ;an000; */
                                                                                                                                 /* ;an000; */
                                }                                                                                                /* ;an000; */
                                                                                                                                 /* ;an000; */
                        }                                                                                                        /* ;an000; */
                }                                                                                                                /* ;an000; */
                                                                                                                                 /* ;an000; */
        strcpy(&OwnerName[0],OutputPtr);                                                                                         /* ;an000; */
                                                                                                                                 /* ;an000; */
        return;                                                                                                                  /* ;an000; */
                                                                                                                                 /* ;an000; */
        }                                                                                                                        /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                /* ;an000; */
/*컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�*/                                                  /* ;an000; */
                                                                                                                                 /* ;an000; */

char *TypeOf(Header)                                                                                                             /* ;an000; */
struct ARENA far *Header;                                                                                                        /* ;an000; */
{                                                                                                                                /* ;an000; */
                                                                                                                                 /* ;an000; */
        char         *t;                                                                                                         /* ;an000; */
        unsigned     PspSegment;                                                                                                 /* ;an000; */
        unsigned far *EnvironmentSegmentPtr;                                                                                     /* ;an000; */
        unsigned int Message_Number;
        char far     *Message_Buf;
        unsigned int i;
                                                                                                                                 /* ;an000; */
        t = &TypeText[0];                                                                                                        /* ;an000; */
        *t = NUL;                                                                                                                /* ;an000; */
                                                                                                                                 /* ;an000; */
        Message_Number = 0xff;                                                  /* ;an000; initialize number value      */
        if (Header -> Owner == 8) Message_Number = StackMsg;                                 /* ;an000; */
        if (Header -> Owner == 0) Message_Number = FreeMsg;                                  /* ;an000; */
                                                                                             /* ;an000; */
        PspSegment = Header -> Owner;                                                        /* ;an000; */
        if (PspSegment < FP_SEG(ArenaHeadPtr))                                               /* ;an000; */
                {                                                                              /* ;an000; */
                if (Message_Number == 0xff) Message_Number = BlankMsg;
                }                                                                            /* ;an000; */
        else {                                                                              /* ;an000; */
                FP_SEG(EnvironmentSegmentPtr) = PspSegment;                                  /* ;an000; */
                FP_OFF(EnvironmentSegmentPtr) = 44;                                          /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
                if (PspSegment == FP_SEG(Header)+1)
                        Message_Number = ProgramMsg;
                else if ( *EnvironmentSegmentPtr == FP_SEG(Header)+1 )
                        Message_Number = EnvironMsg;
                else
                        Message_Number = DataMsg;

                }

        Message_Buf = UtilityText(Message_Number);
        i = 0;
        while ( *Message_Buf != (char) '\x0' )
                TypeText[i++] = *Message_Buf++;
        TypeText[i++] = '\x0';

                                                                                                                                 /* ;an000; */
        return(t);                                                                                                               /* ;an000; */
                                                                                                                                 /* ;an000; */
        }                                                                                                                        /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
/*컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�*/                                                  /* ;an000; */
                                                                                                                                 /* ;an000; */
unsigned long AddressOf(Pointer)                                                                                                 /* ;an000; */
char far *Pointer;                                                                                                               /* ;an000; */
{                                                                                                                                /* ;an000; */
                                                                                                                                 /* ;an000; */
        unsigned long SegmentAddress,OffsetAddress;                                                                              /* ;an000; */
                                                                                                                                 /* ;an000; */
        SegmentAddress = (unsigned long) (FP_SEG(Pointer)) * 16l;                                                                /* ;an000; */
        OffsetAddress = (unsigned long) (FP_OFF(Pointer));                                                                       /* ;an000; */
                                                                                                                                 /* ;an000; */
        return( SegmentAddress + OffsetAddress);                                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
        }                                                                                                                        /* ;an000; */
                                                                                                                                 /* ;an000; */
/*컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴컴�*/                                                  /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
/************************************************************************/                                                       /* ;an000; */
/* SUB0_MESSAGE                 - This routine will print only those    */                                                       /* ;an000; */
/*                                messages that do not require a        */                                                       /* ;an000; */
/*                                a sublist.                            */                                                       /* ;an000; */
/*                                                                      */                                                       /* ;an000; */
/*      Inputs  : Msg_Num       - number of applicable message          */                                                       /* ;an000; */
/*                Handle        - display type                          */                                                       /* ;an000; */
/*                Message_Type  - type of message to display            */                                                       /* ;an000; */
/*                                                                      */                                                       /* ;an000; */
/*      Outputs : message                                               */                                                       /* ;an000; */
/*                                                                      */                                                       /* ;an000; */
/************************************************************************/                                                       /* ;an000; */
                                                                                                                                 /* ;an000; */
void Sub0_Message(Msg_Num,Handle,Message_Type)                                       /* print messages with no subs          */  /* ;an000; */
                                                                                                                                 /* ;an000; */
int             Msg_Num;                                                                                                         /* ;an000; */
int             Handle;                                                                                                          /* ;an000; */
unsigned char   Message_Type;                                                                                                    /* ;an000; */
                                                                                /*     extended, parse, or utility      */       /* ;an000; */
        {                                                                                                                        /* ;an000; */
        InRegs.x.ax = Msg_Num;                                                  /* put message number in AX             */       /* ;an000; */
        InRegs.x.bx = Handle;                                                   /* put handle in BX                     */       /* ;an000; */
        InRegs.x.cx = No_Replace;                                               /* no replaceable subparms              */       /* ;an000; */
        InRegs.h.dl = No_Input;                                                 /* no keyboard input                    */       /* ;an000; */
        InRegs.h.dh = Message_Type;                                             /* type of message to display           */       /* ;an000; */
        ReportMessage();                                          /* display the message                  */        /* ;an000; */
                                                                                                                                 /* ;an000; */
        return;                                                                                                                  /* ;an000; */
        }                                                                                                                        /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
/************************************************************************/                                                       /* ;an000; */
void Sub2_Message(Msg_Num,Handle,Message_Type,                                                                                   /* ;an000; */
             Replace_Parm1,                                                                                                      /* ;an000; */
             Replace_Message1)                                                                                                   /* ;an000; */
                                                                                                                                 /* ;an000; */
int             Msg_Num;                                                                                                         /* ;an000; */
int             Handle;                                                                                                          /* ;an000; */
unsigned char   Message_Type;                                                                                                    /* ;an000; */
int             Replace_Message1;                                                                                                /* ;an000; */
                                                                                /*     extended, parse, or utility      */       /* ;an000; */
char    *Replace_Parm1;                                                         /* pointer to message to print          */       /* ;an000; */
{                                                                                                                                /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
        {                                                                                                                        /* ;an000; */
                switch(Msg_Num)                                                                                                  /* ;an000; */
                        {                                                                                                        /* ;an000; */
                        case    DeviceLineMsg:                                                                                   /* ;an000; */
                                                                                                                                 /* ;an000; */
                                sublist[1].value     = (unsigned far *)Replace_Parm1;                                            /* ;an000; */
                                sublist[1].size      = Sublist_Length;                                                           /* ;an000; */
                                sublist[1].reserved  = Reserved;                                                                 /* ;an000; */
                                sublist[1].id        = 1;                                                                        /* ;an000; */
                                sublist[1].flags     = Char_Field_ASCIIZ+Left_Align;                                             /* ;an000; */
                                sublist[1].max_width = 0x0008;                                                                   /* ;an000; */
                                sublist[1].min_width = 0x0008;                                                                   /* ;an000; */
                                sublist[1].pad_char  = Blank;                                                                    /* ;an000; */
                                                                                                                                 /* ;an000; */
                                InRegs.x.ax = Replace_Message1;                                                                  /* ;an000; */
                                InRegs.h.dh = Message_Type;                                                                      /* ;an000; */
                                sysgetmsg(&InRegs,&SegRegs,&OutRegs);                                                            /* ;an000; */
                                                                                                                                 /* ;an000; */
                                FP_OFF(sublist[2].value)    = OutRegs.x.si;                                                      /* ;an000; */
                                FP_SEG(sublist[2].value)    = SegRegs.ds;                                                        /* ;an000; */
                                sublist[2].size      = Sublist_Length;                                                           /* ;an000; */
                                sublist[2].reserved  = Reserved;                                                                 /* ;an000; */
                                sublist[2].id        = 2;                                                                        /* ;an000; */
                                sublist[2].flags     = Char_Field_ASCIIZ+Right_Align;                                            /* ;an000; */
                                sublist[2].max_width = 00;                                                                       /* ;an000; */
                                sublist[2].min_width = 10;                                                                       /* ;an000; */
                                sublist[2].pad_char  = Blank;                                                                    /* ;an000; */
                                break;                                                                                           /* ;an000; */
                        }                                                                                                        /* ;an000; */
                                                                                                                                 /* ;an000; */
        InRegs.x.ax = Msg_Num;                                                                                                   /* ;an000; */
        InRegs.x.bx = Handle;                                                                                                    /* ;an000; */
        InRegs.x.cx = SubCnt2;                                                                                                   /* ;an000; */
        InRegs.h.dl = No_Input;                                                                                                  /* ;an000; */
        InRegs.h.dh = Message_Type;                                                                                              /* ;an000; */
        InRegs.x.si = (unsigned int)&sublist[1];                                                                                 /* ;an000; */
        ReportMessage();                                                                                            /* ;an000; */
        }                                                                                                                        /* ;an000; */
        return;                                                                                                                  /* ;an000; */
}                                                                                                                                /* ;an000; */
                                                                                                                                 /* ;an000; */
/************************************************************************/                                                       /* ;an000; */
/* SUB3_MESSAGE                 - This routine will print only those    */                                                       /* ;an000; */
/*                                messages that require 3 replaceable   */                                                       /* ;an000; */
/*                                parms.                                */                                                       /* ;an000; */
/*                                                                      */                                                       /* ;an000; */
/*      Inputs  : Msg_Num       - number of applicable message          */                                                       /* ;an000; */
/*                Handle        - display type                          */                                                       /* ;an000; */
/*                Message_Type  - type of message to display            */                                                       /* ;an000; */
/*                Replace_Parm1 - pointer to parm to replace            */                                                       /* ;an000; */
/*                Replace_Parm2 - pointer to parm to replace            */                                                       /* ;an000; */
/*                Replace_Parm3 - pointer to parm to replace            */                                                       /* ;an000; */
/*                                                                      */                                                       /* ;an000; */
/*      Outputs : message                                               */                                                       /* ;an000; */
/*                                                                      */                                                       /* ;an000; */
/************************************************************************/                                                       /* ;an000; */
                                                                                                                                 /* ;an000; */
void Sub3_Message(Msg_Num,Handle,Message_Type,                                                                                   /* ;an000; */
             Replace_Parm1,                                                                                                      /* ;an000; */
             Replace_Parm2,                                                                                                      /* ;an000; */
             Replace_Message1)                                                                                                   /* ;an000; */
                                                                                                                                 /* ;an000; */
int               Msg_Num;                                                                                                       /* ;an000; */
int               Handle;                                                                                                        /* ;an000; */
unsigned char     Message_Type;                                                                                                  /* ;an000; */
char              *Replace_Parm1;                                                                                                /* ;an000; */
unsigned long int *Replace_Parm2;                                                                                                /* ;an000; */
int               Replace_Message1;                                                                                              /* ;an000; */
                                                                                /*     extended, parse, or utility      */       /* ;an000; */
{                                                                                                                                /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
        {                                                                                                                        /* ;an000; */
                switch(Msg_Num)                                                                                                  /* ;an000; */
                        {                                                                                                        /* ;an000; */
                        case    DriverLineMsg:                                                                                   /* ;an000; */
                                                                                                                                 /* ;an000; */
                                sublist[1].value     = (unsigned far *)Replace_Parm1;                                            /* ;an000; */
                                sublist[1].size      = Sublist_Length;                                                           /* ;an000; */
                                sublist[1].reserved  = Reserved;                                                                 /* ;an000; */
                                sublist[1].id        = 1;                                                                        /* ;an000; */
                                sublist[1].flags     = Char_Field_ASCIIZ+Left_Align;                                             /* ;an000; */
                                sublist[1].max_width = 0x0008;                                                                   /* ;an000; */
                                sublist[1].min_width = 0x0008;                                                                   /* ;an000; */
                                sublist[1].pad_char  = Blank;                                                                    /* ;an000; */
                                                                                                                                 /* ;an000; */
                                sublist[2].value     = (unsigned far *)Replace_Parm2;                                            /* ;an000; */
                                sublist[2].size      = Sublist_Length;                                                           /* ;an000; */
                                sublist[2].reserved  = Reserved;                                                                 /* ;an000; */
                                sublist[2].id        = 2;                                                                        /* ;an000; */
                                sublist[2].flags     = Bin_Hex_DWord+Right_Align;                                                /* ;an000; */
                                sublist[2].max_width = 0x0006;                                                                   /* ;an000; */
                                sublist[2].min_width = 0x0006;                                                                   /* ;an000; */
                                sublist[2].pad_char  = 0x0030;                                                                   /* ;an000; */
                                                                                                                                 /* ;an000; */
                                InRegs.x.ax = Replace_Message1;                                                                  /* ;an000; */
                                InRegs.h.dh = Message_Type;                                                                      /* ;an000; */
                                sysgetmsg(&InRegs,&SegRegs,&OutRegs);                                                            /* ;an000; */
                                                                                                                                 /* ;an000; */
                                FP_OFF(sublist[3].value)    = OutRegs.x.si;                                                      /* ;an000; */
                                FP_SEG(sublist[3].value)    = SegRegs.ds;                                                        /* ;an000; */
                                sublist[3].size      = Sublist_Length;                                                           /* ;an000; */
                                sublist[3].reserved  = Reserved;                                                                 /* ;an000; */
                                sublist[3].id        = 3;                                                                        /* ;an000; */
                                sublist[3].flags     = Char_Field_ASCIIZ+Left_Align;                                             /* ;an000; */
                                sublist[3].max_width = 00;                                                                       /* ;an000; */
                                sublist[3].min_width = 10;                                                                       /* ;an000; */
                                sublist[3].pad_char  = Blank;                                                                    /* ;an000; */
                                break;                                                                                           /* ;an000; */
                                                                                                                                 /* ;an000; */
                        case    HandleMsg:                                                                                       /* ;an000; */
                                sublist[1].value     = (unsigned far *)Replace_Parm1;                                            /* ;an000; */
                                sublist[1].size      = Sublist_Length;                                                           /* ;an000; */
                                sublist[1].reserved  = Reserved;                                                                 /* ;an000; */
                                sublist[1].id        = 1;                                                                        /* ;an000; */
                                sublist[1].flags     = Unsgn_Bin_Byte+Right_Align;                                               /* ;an000; */
                                sublist[1].max_width = 0x0009;                                                                   /* ;an000; */
                                sublist[1].min_width = 0x0009;                                                                   /* ;an000; */
                                sublist[1].pad_char  = Blank;                                                                    /* ;an000; */
                                                                                                                                 /* ;an000; */
                                sublist[2].value     = (unsigned far *)Replace_Parm2;                                            /* ;an000; */
                                sublist[2].size      = Sublist_Length;                                                           /* ;an000; */
                                sublist[2].reserved  = Reserved;                                                                 /* ;an000; */
                                sublist[2].id        = 2;                                                                        /* ;an000; */
                                sublist[2].flags     = Char_Field_ASCIIZ+Left_Align;                                             /* ;an000; */
                                sublist[2].max_width = 0x0008;                                                                   /* ;an000; */
                                sublist[2].min_width = 0x0008;                                                                   /* ;an000; */
                                sublist[2].pad_char  = Blank;                                                                    /* ;an000; */
                                                                                                                                 /* ;an000; */
                                InRegs.x.ax = Replace_Message1;                                                                  /* ;an000; */
                                InRegs.h.dh = Message_Type;                                                                      /* ;an000; */
                                sysgetmsg(&InRegs,&SegRegs,&OutRegs);                                                            /* ;an000; */
                                                                                                                                 /* ;an000; */
                                FP_OFF(sublist[3].value)    = OutRegs.x.si;                                                      /* ;an000; */
                                FP_SEG(sublist[3].value)    = SegRegs.ds;                                                        /* ;an000; */
                                sublist[3].size      = Sublist_Length;                                                           /* ;an000; */
                                sublist[3].reserved  = Reserved;                                                                 /* ;an000; */
                                sublist[3].id        = 3;                                                                        /* ;an000; */
                                sublist[3].flags     = Bin_Hex_DWord+Right_Align;                                                /* ;an000; */
                                sublist[3].max_width = 00;                                                                       /* ;an000; */
                                sublist[3].min_width = 10;                                                                       /* ;an000; */
                                sublist[3].pad_char  = Blank;                                                                    /* ;an000; */
                                break;                                                                                           /* ;an000; */
                                                                                                                                 /* ;an000; */
                        }                                                                                                        /* ;an000; */
                                                                                                                                 /* ;an000; */
        InRegs.x.ax = Msg_Num;                                                                                                   /* ;an000; */
        InRegs.x.bx = Handle;                                                                                                    /* ;an000; */
        InRegs.x.cx = SubCnt3;                                                                                                   /* ;an000; */
        InRegs.h.dl = No_Input;                                                                                                  /* ;an000; */
        InRegs.h.dh = Message_Type;                                                                                              /* ;an000; */
        InRegs.x.si = (unsigned int)&sublist[1];                                                                                 /* ;an000; */
        ReportMessage();                                                                                            /* ;an000; */
        }                                                                                                                        /* ;an000; */
        return;                                                                                                                  /* ;an000; */
}                                                                                                                                /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
/************************************************************************/                                                       /* ;an000; */
/* SUB4_MESSAGE                 - This routine will print only those    */                                                       /* ;an000; */
/*                                messages that require 4 replaceable   */                                                       /* ;an000; */
/*                                parms.                                */                                                       /* ;an000; */
/*                                                                      */                                                       /* ;an000; */
/*      Inputs  : Msg_Num       - number of applicable message          */                                                       /* ;an000; */
/*                Handle        - display type                          */                                                       /* ;an000; */
/*                Message_Type  - type of message to display            */                                                       /* ;an000; */
/*                Replace_Parm1 - pointer to parm to replace            */                                                       /* ;an000; */
/*                Replace_Parm2 - pointer to parm to replace            */                                                       /* ;an000; */
/*                Replace_Parm3 - pointer to parm to replace            */                                                       /* ;an000; */
/*                Dynamic_Parm  - parm number to use as replaceable     */                                                       /* ;an000; */
/*                                                                      */                                                       /* ;an000; */
/*      Outputs : message                                               */                                                       /* ;an000; */
/*                                                                      */                                                       /* ;an000; */
/************************************************************************/                                                       /* ;an000; */
                                                                                                                                 /* ;an000; */
void Sub4_Message(Msg_Num,Handle,Message_Type,                                                                                   /* ;an000; */
             Replace_Value1,                                                                                                     /* ;an000; */
             Replace_Message1,                                                                                                   /* ;an000; */
             Replace_Value2,                                                                                                     /* ;an000; */
             Replace_Message2)                                                                                                   /* ;an000; */
                                                                                                                                 /* ;an000; */
int                     Msg_Num;                                                                                                 /* ;an000; */
int                     Handle;                                                                                                  /* ;an000; */
unsigned char           Message_Type;                                                                                            /* ;an000; */
unsigned long int       *Replace_Value1;                                                                                         /* ;an000; */
int                     Replace_Message1;                                                                                        /* ;an000; */
unsigned long int       *Replace_Value2;                                                                                         /* ;an000; */
int                     Replace_Message2;                                                                                        /* ;an000; */
                                                                                /*     extended, parse, or utility      */       /* ;an000; */
{                                                                                                                                /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
        {                                                                                                                        /* ;an000; */
                switch(Msg_Num)                                                                                                  /* ;an000; */
                        {                                                                                                        /* ;an000; */
                        case    MainLineMsg:                                                                                     /* ;an000; */
                                                                                                                                 /* ;an000; */
                                sublist[1].value     = (unsigned far *)Replace_Value1;                                           /* ;an000; */
                                sublist[1].size      = Sublist_Length;                                                           /* ;an000; */
                                sublist[1].reserved  = Reserved;                                                                 /* ;an000; */
                                sublist[1].id        = 1;                                                                        /* ;an000; */
                                sublist[1].flags     = Bin_Hex_DWord+Right_Align;                                                /* ;an000; */
                                sublist[1].max_width = 06;                                                                       /* ;an000; */
                                sublist[1].min_width = 06;                                                                       /* ;an000; */
                                sublist[1].pad_char  = 0x0030;                                                                   /* ;an000; */
                                                                                                                                 /* ;an000; */
                                InRegs.x.ax        = Replace_Message1;                                                           /* ;an000; */
                                InRegs.h.dh        = Message_Type;                                                               /* ;an000; */
                                sysgetmsg(&InRegs,&SegRegs,&OutRegs);                                                            /* ;an000; */
                                                                                                                                 /* ;an000; */
                                FP_OFF(sublist[2].value)    = OutRegs.x.si;                                                      /* ;an000; */
                                FP_SEG(sublist[2].value)    = SegRegs.ds;                                                        /* ;an000; */
                                sublist[2].size      = Sublist_Length;                                                           /* ;an000; */
                                sublist[2].reserved  = Reserved;                                                                 /* ;an000; */
                                sublist[2].id        = 2;                                                                        /* ;an000; */
                                sublist[2].flags     = Char_Field_ASCIIZ+Left_Align;                                             /* ;an000; */
                                sublist[2].max_width = 0x0008;                                                                   /* ;an000; */
                                sublist[2].min_width = 0x0008;                                                                   /* ;an000; */
                                sublist[2].pad_char  = Blank;                                                                    /* ;an000; */
                                                                                                                                 /* ;an000; */
                                sublist[3].value     = (unsigned far *)Replace_Value2;                                           /* ;an000; */
                                sublist[3].size      = Sublist_Length;                                                           /* ;an000; */
                                sublist[3].reserved  = Reserved;                                                                 /* ;an000; */
                                sublist[3].id        = 3;                                                                        /* ;an000; */
                                sublist[3].flags     = Bin_Hex_DWord+Right_Align;                                                /* ;an000; */
                                sublist[3].max_width = 06;                                                                       /* ;an000; */
                                sublist[3].min_width = 06;                                                                       /* ;an000; */
                                sublist[3].pad_char  = 0x0030;                                                                   /* ;an000; */
                                                                                                                                 /* ;an000; */
                                InRegs.x.ax = Replace_Message2;                                                                  /* ;an000; */
                                InRegs.h.dh = Message_Type;                                                                      /* ;an000; */
                                sysgetmsg(&InRegs,&SegRegs,&OutRegs);                                                            /* ;an000; */
                                                                                                                                 /* ;an000; */
                                FP_OFF(sublist[4].value)    = OutRegs.x.si;                                                      /* ;an000; */
                                FP_SEG(sublist[4].value)    = SegRegs.ds;                                                        /* ;an000; */
                                sublist[4].size      = Sublist_Length;                                                           /* ;an000; */
                                sublist[4].reserved  = Reserved;                                                                 /* ;an000; */
                                sublist[4].id        = 4;                                                                        /* ;an000; */
                                sublist[4].flags     = Char_Field_ASCIIZ+Left_Align;                                             /* ;an000; */
                                sublist[4].max_width = 0;                                                                        /* ;an000; */
                                sublist[4].min_width = 10;                                                                       /* ;an000; */
                                sublist[4].pad_char  = Blank;                                                                    /* ;an000; */
                                break;                                                                                           /* ;an000; */
                        }                                                                                                        /* ;an000; */
                                                                                                                                 /* ;an000; */
        InRegs.x.ax = Msg_Num;                                                                                                   /* ;an000; */
        InRegs.x.bx = Handle;                                                                                                    /* ;an000; */
        InRegs.x.cx = SubCnt4;                                                                                                   /* ;an000; */
        InRegs.h.dl = No_Input;                                                                                                  /* ;an000; */
        InRegs.h.dh = Message_Type;                                                                                              /* ;an000; */
        InRegs.x.si = (unsigned int)&sublist[1];                                                                                 /* ;an000; */
        ReportMessage();                                                                                            /* ;an000; */
        }                                                                                                                        /* ;an000; */
        return;                                                                                                                  /* ;an000; */
}                                                                                                                                /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
/************************************************************************/                                                       /* ;an000; */
/* SUB4a_MESSAGE                - This routine will print only those    */                                                       /* ;an000; */
/*                                messages that require 4 replaceable   */                                                       /* ;an000; */
/*                                parms.                                */                                                       /* ;an000; */
/*                                                                      */                                                       /* ;an000; */
/*      Inputs  : Msg_Num       - number of applicable message          */                                                       /* ;an000; */
/*                Handle        - display type                          */                                                       /* ;an000; */
/*                Message_Type  - type of message to display            */                                                       /* ;an000; */
/*                Replace_Parm1 - pointer to parm to replace            */                                                       /* ;an000; */
/*                Replace_Parm2 - pointer to parm to replace            */                                                       /* ;an000; */
/*                Replace_Parm3 - pointer to parm to replace            */                                                       /* ;an000; */
/*                Dynamic_Parm  - parm number to use as replaceable     */                                                       /* ;an000; */
/*                                                                      */                                                       /* ;an000; */
/*      Outputs : message                                               */                                                       /* ;an000; */
/*                                                                      */                                                       /* ;an000; */
/************************************************************************/                                                       /* ;an000; */
                                                                                                                                 /* ;an000; */
void Sub4a_Message(Msg_Num,Handle,Message_Type,                                                                                  /* ;an000; */
             Replace_Value1,                                                                                                     /* ;an000; */
             Replace_Message1,                                                                                                   /* ;an000; */
             Replace_Value2,                                                                                                     /* ;an000; */
             Replace_Message2)                                                                                                   /* ;an000; */
                                                                                                                                 /* ;an000; */
int                     Msg_Num;                                                                                                 /* ;an000; */
int                     Handle;                                                                                                  /* ;an000; */
unsigned char           Message_Type;                                                                                            /* ;an000; */
unsigned long int       *Replace_Value1;                                                                                         /* ;an000; */
char                    *Replace_Message1;                                                                                       /* ;an000; */
unsigned long int       *Replace_Value2;                                                                                         /* ;an000; */
char                    *Replace_Message2;                                                                                       /* ;an000; */
                                                                                                                                 /* ;an000; */
{                                                                                                                                /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
        {                                                                                                                        /* ;an000; */
                switch(Msg_Num)                                                                                                  /* ;an000; */
                        {                                                                                                        /* ;an000; */
                        case    MainLineMsg:                                                                                     /* ;an000; */
                                                                                                                                 /* ;an000; */
                                sublist[1].value     = (unsigned far *)Replace_Value1;                                           /* ;an000; */
                                sublist[1].size      = Sublist_Length;                                                           /* ;an000; */
                                sublist[1].reserved  = Reserved;                                                                 /* ;an000; */
                                sublist[1].id        = 1;                                                                        /* ;an000; */
                                sublist[1].flags     = Bin_Hex_DWord+Right_Align;                                                /* ;an000; */
                                sublist[1].max_width = 06;                                                                       /* ;an000; */
                                sublist[1].min_width = 06;                                                                       /* ;an000; */
                                sublist[1].pad_char  = 0x0030;                                                                   /* ;an000; */
                                                                                                                                 /* ;an000; */
                                sublist[2].value     = (unsigned far *)Replace_Message1;                                         /* ;an000; */
                                sublist[2].size      = Sublist_Length;                                                           /* ;an000; */
                                sublist[2].reserved  = Reserved;                                                                 /* ;an000; */
                                sublist[2].id        = 2;                                                                        /* ;an000; */
                                sublist[2].flags     = Char_Field_ASCIIZ+Left_Align;                                             /* ;an000; */
                                sublist[2].max_width = 0x0008;                                                                   /* ;an000; */
                                sublist[2].min_width = 0x0008;                                                                   /* ;an000; */
                                sublist[2].pad_char  = Blank;                                                                    /* ;an000; */
                                                                                                                                 /* ;an000; */
                                sublist[3].value     = (unsigned far *)Replace_Value2;                                           /* ;an000; */
                                sublist[3].size      = Sublist_Length;                                                           /* ;an000; */
                                sublist[3].reserved  = Reserved;                                                                 /* ;an000; */
                                sublist[3].id        = 3;                                                                        /* ;an000; */
                                sublist[3].flags     = Bin_Hex_DWord+Right_Align;                                                /* ;an000; */
                                sublist[3].max_width = 06;                                                                       /* ;an000; */
                                sublist[3].min_width = 06;                                                                       /* ;an000; */
                                sublist[3].pad_char  = 0x0030;                                                                   /* ;an000; */
                                                                                                                                 /* ;an000; */
                                sublist[4].value     = (unsigned far *)Replace_Message2;                                         /* ;an000; */
                                sublist[4].size      = Sublist_Length;                                                           /* ;an000; */
                                sublist[4].reserved  = Reserved;                                                                 /* ;an000; */
                                sublist[4].id        = 4;                                                                        /* ;an000; */
                                sublist[4].flags     = Char_Field_ASCIIZ+Left_Align;                                             /* ;an000; */
                                sublist[4].max_width = 0;                                                                        /* ;an000; */
                                sublist[4].min_width = 10;                                                                       /* ;an000; */
                                sublist[4].pad_char  = Blank;                                                                    /* ;an000; */
                                break;                                                                                           /* ;an000; */
                        }                                                                                                        /* ;an000; */
                                                                                                                                 /* ;an000; */
        InRegs.x.ax = Msg_Num;                                                                                                   /* ;an000; */
        InRegs.x.bx = Handle;                                                                                                    /* ;an000; */
        InRegs.x.cx = SubCnt4;                                                                                                   /* ;an000; */
        InRegs.h.dl = No_Input;                                                                                                  /* ;an000; */
        InRegs.h.dh = Message_Type;                                                                                              /* ;an000; */
        InRegs.x.si = (unsigned int)&sublist[1];                                                                                 /* ;an000; */
        ReportMessage();                                                                                            /* ;an000; */
        }                                                                                                                        /* ;an000; */
        return;                                                                                                                  /* ;an000; */
}                                                                                                                                /* ;an000; */
                                                                                                                                 /* ;an000; */
                                                                                                                                 /* ;an000; */
/************************************************************************/                                                       /* ;an000; */
/* EMSPrint                     - This routine will print the message   */                                                       /* ;an000; */
/*                                necessary for EMS reporting.          */                                                       /* ;an000; */
/*                                                                      */                                                       /* ;an000; */
/*      Outputs : message                                               */                                                       /* ;an000; */
/*                                                                      */                                                       /* ;an000; */
/************************************************************************/                                                       /* ;an000; */
                                                                                                                                 /* ;an000; */
void EMSPrint(Msg_Num,Handle,Message_Type,                                                                                       /* ;an000; */
             Replace_Value1,                                                                                                     /* ;an000; */
             Replace_Message1,                                                                                                   /* ;an000; */
             Replace_Value2)                                                                                                     /* ;an000; */
                                                                                                                                 /* ;an000; */
int                     Msg_Num;                                                                                                 /* ;an000; */
int                     Handle;                                                                                                  /* ;an000; */
unsigned char           Message_Type;                                                                                            /* ;an000; */
int                     *Replace_Value1;                                                                                         /* ;an000; */
char                    *Replace_Message1;                                                                                       /* ;an000; */
unsigned long int       *Replace_Value2;                                                                                         /* ;an000; */
                                                                                /*     extended, parse, or utility      */       /* ;an000; */
{                                                                                                                                /* ;an000; */
                                                                                                                                 /* ;an000; */
        {                                                                                                                        /* ;an000; */
        sublist[1].value     = (unsigned far *)Replace_Value1;                                                                   /* ;an000; */
        sublist[1].size      = Sublist_Length;                                                                                   /* ;an000; */
        sublist[1].reserved  = Reserved;                                                                                         /* ;an000; */
        sublist[1].id        = 1;                                                                                                /* ;an000; */
        sublist[1].flags     = Unsgn_Bin_Word+Right_Align;                                                                       /* ;an000; */
        sublist[1].max_width = 03;                                                                                               /* ;an000; */
        sublist[1].min_width = 03;                                                                                               /* ;an000; */
        sublist[1].pad_char  = Blank;                                                                                            /* ;an000; */
                                                                                                                                 /* ;an000; */
        sublist[2].value     = (unsigned far *)Replace_Message1;                                                                 /* ;an000; */
        sublist[2].size      = Sublist_Length;                                                                                   /* ;an000; */
        sublist[2].reserved  = Reserved;                                                                                         /* ;an000; */
        sublist[2].id        = 2;                                                                                                /* ;an000; */
        sublist[2].flags     = Char_Field_ASCIIZ+Left_Align;                                                                     /* ;an000; */
        sublist[2].max_width = 0x0008;                                                                                           /* ;an000; */
        sublist[2].min_width = 0x0008;                                                                                           /* ;an000; */
        sublist[2].pad_char  = Blank;                                                                                            /* ;an000; */
                                                                                                                                 /* ;an000; */
        sublist[3].value     = (unsigned far *)Replace_Value2;                                                                   /* ;an000; */
        sublist[3].size      = Sublist_Length;                                                                                   /* ;an000; */
        sublist[3].reserved  = Reserved;                                                                                         /* ;an000; */
        sublist[3].id        = 3;                                                                                                /* ;an000; */
        sublist[3].flags     = Bin_Hex_DWord+Right_Align;                                                                        /* ;an000; */
        sublist[3].max_width = 06;                                                                                               /* ;an000; */
        sublist[3].min_width = 06;                                                                                               /* ;an000; */
        sublist[3].pad_char  = 0x0030;                                                                                           /* ;an000; */
                                                                                                                                 /* ;an000; */
        InRegs.x.ax = Msg_Num;                                                                                                   /* ;an000; */
        InRegs.x.bx = Handle;                                                                                                    /* ;an000; */
        InRegs.x.cx = SubCnt3;                                                                                                   /* ;an000; */
        InRegs.h.dl = No_Input;                                                                                                  /* ;an000; */
        InRegs.h.dh = Message_Type;                                                                                              /* ;an000; */
        InRegs.x.si = (unsigned int)&sublist[1];                                                                                 /* ;an000; */
        ReportMessage();                                                                                            /* ;an000; */
        }                                                                                                                        /* ;an000; */
        return;                                                                                                                  /* ;an000; */
}                                                                                                                                /* ;an000; */
                                                                                                                                 /* ;an000; */
/*----------------------------------------------------------------------+
|                                                                       |
|  SUBROUTINE NAME:     PARSE_INIT                                      |
|                                                                       |
|  SUBROUTINE FUNCTION:                                                 |
|                                                                       |
|       This routine is called by the FILESYS MAIN routine to initialize|
|       the parser data structures.                                     |
|                                                                       |
|  INPUT:                                                               |
|       none                                                            |
|                                                                       |
|  OUTPUT:                                                              |
|       properly initialized parser control blocks                      |
|                                                                       |
+----------------------------------------------------------------------*/
/* The DOS parser stores each accepted spelling as a NUL-terminated synonym.
 * The longest list (/C through /CLASSIFY) uses 52 of the 64 available bytes. */
static void SetSwitch(struct p_control_blk *control, struct p_result_blk *result,
                      char *name)
{
    unsigned length;
    char *out = control->p_keyorsw;
    control->p_match_flag = p_none;
    control->p_function_flag = p_cap_file;
    control->p_result_buf = (unsigned)result;
    control->p_value_list = (unsigned)&p_noval;
    control->p_nid = strlen(name) - 1;
    for (length = 2; length <= strlen(name); ++length) {
        memcpy(out, name, length);
        out[length] = 0;
        out += length + 1;
    }
}

void parse_init()
{
    p_p.p_parmsx_address = &p_px;
    p_px.p_maxswitch = 3;
    p_px.p_control[0] = &debug_switch;
    p_px.p_control[1] = &classify_switch;
    p_px.p_control[2] = &page_switch;
    SetSwitch(&debug_switch, &debug_result, "/DEBUG");
    SetSwitch(&classify_switch, &classify_result, "/CLASSIFY");
    SetSwitch(&page_switch, &page_result, "/P");
} /* end parse_init */                                                                     /* ;an000; */


/************************************************************************/                                                       /* ;an000; */
/* Parse_Message                - This routine will print only those    */
/*                                messages that require 1 replaceable   */
/*                                parm.                                 */
/*                                                                      */
/*      Inputs  : Msg_Num       - number of applicable message          */
/*                Handle        - display type                          */
/*                Message_Type  - type of message to display            */
/*                Replace_Parm  - pointer to parm to replace            */
/*                                                                      */
/*      Outputs : message                                               */
/*                                                                      */
/************************************************************************/

void Parse_Message(Msg_Num,Handle,Message_Type)                                 /*;an003; dms;                          */
                                                                                /*;an003; dms;                          */
int             Msg_Num;                                                        /*;an003; dms;                          */
int             Handle;                                                         /*;an003; dms;                          */
unsigned char   Message_Type;                                                   /*;an003; dms;                          */
                                                                                /*;an003; dms;                          */
{                                                                               /*;an003; dms;                          */
char    far *Cmd_Ptr;                                                           /*;an003; dms;                          */
                                                                                /*;an003; dms;                          */
                                                                                /*;an003; dms;                          */
        {                                                                       /*;an003; dms;                          */
        segread(&SegRegs);                                                      /*;an003; dms;                          */
        FP_SEG(Cmd_Ptr) = SegRegs.ds;                                           /*;an003; dms;                          */
        FP_OFF(Cmd_Ptr) = OutRegs.x.si;                                         /*;an003; dms;                          */
        *Cmd_Ptr        = '\0';                                                 /*;an003; dms;                          */
                                                                                /*;an003; dms;                          */
        FP_SEG(sublist[1].value) = SegRegs.ds;                                  /*;an003; dms;                          */
        FP_OFF(sublist[1].value) = Parse_Ptr;                                   /*;an003; dms;                          */
        sublist[1].size      = Sublist_Length;                                  /*;an003; dms;                          */
        sublist[1].reserved  = Reserved;                                        /*;an003; dms;                          */
        sublist[1].id        = 0;                                               /*;an003; dms;                          */
        sublist[1].flags     = Char_Field_ASCIIZ+Left_Align;                    /*;an003; dms;                          */
        sublist[1].max_width = 40;                                              /*;an003; dms;                          */
        sublist[1].min_width = 01;                                              /*;an003; dms;                          */
        sublist[1].pad_char  = Blank;                                           /*;an003; dms;                          */
                                                                                /*;an003; dms;                          */
        InRegs.x.ax = Msg_Num;                                                  /*;an003; dms;                          */
        InRegs.x.bx = Handle;                                                   /*;an003; dms;                          */
        InRegs.x.cx = SubCnt1;                                                  /*;an003; dms;                          */
        InRegs.h.dl = No_Input;                                                 /*;an003; dms;                          */
        InRegs.h.dh = Message_Type;                                             /*;an003; dms;                          */
        InRegs.x.si = (unsigned int)&sublist[1];                                /*;an003; dms;                          */
        ReportMessage();                                           /*;an003; dms;                          */
        }                                                                       /*;an003; dms;                          */
        return;                                                                 /*;an003; dms;                          */
}                                                                               /*;an003; dms;                          */


