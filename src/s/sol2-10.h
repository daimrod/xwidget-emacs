/* Handle Solaris 2.10.  */

#include "sol2-6.h"

#define SYSTEM_MALLOC

/* This is used in list_system_processes.  */
#define HAVE_PROCFS 1

/* This is needed for the system_process_attributes implementation.  */
#define _STRUCTURED_PROC 1

/* arch-tag: 7c51a134-5469-4d16-aa00-d69224640eeb
   (do not change this comment) */
