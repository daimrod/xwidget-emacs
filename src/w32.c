/* Utility and Unix shadow routines for GNU Emacs on Windows NT.
   Copyright (C) 1994, 1995 Free Software Foundation, Inc.

This file is part of GNU Emacs.

GNU Emacs is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2, or (at your option)
any later version.

GNU Emacs is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with GNU Emacs; see the file COPYING.  If not, write to
the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
Boston, MA 02111-1307, USA.

   Geoff Voelker (voelker@cs.washington.edu)                         7-29-94
*/


/* Define stat before including config.h.  */
#include <string.h>
#include <sys/stat.h>
#include <malloc.h>

static int is_toplevel_share_name (char *);
static int stat_toplevel_share (char *, void *);

int
nt_stat (char *filename, struct stat *statbuf)
{
  int l = strlen (filename);
  char *str = NULL;

  /* stat has a bug when passed a name of a directory with a trailing
     backslash (but a trailing forward slash works fine).  */
  if (filename[l - 1] == '\\') 
    {
      str = (char *) alloca (l + 1);
      strcpy (str, filename);
      str[l - 1] = '/';
      return stat (str, statbuf);
    }

  if (stat (filename, statbuf) == 0)
    return 0;
  else if (is_toplevel_share_name (filename))
    return stat_toplevel_share (filename, statbuf);
  else
    return -1;
}

/* Place a wrapper around the NT version of ctime.  It returns NULL
   on network directories, so we handle that case here.  
   Define it before including config.h.  (Ulrich Leodolter, 1/11/95).  */
char *
nt_ctime (const time_t *t)
{
  char *str = (char *) ctime (t);
  return (str ? str : "Sun Jan 01 00:00:00 1970");
}

#include <config.h>
#include <windows.h>
#include <stdlib.h>
#include <stdio.h>
#include <io.h>
#include <fcntl.h>
#include <ctype.h>

#define getwd _getwd
#include "lisp.h"
#undef getwd

#include <pwd.h>

#include "ndir.h"
#include "ntheap.h"

extern int report_file_error (char *, Lisp_Object);

/* Routines for extending stat above.  */
static int
get_unassigned_drive_letter ()
{
  int i;
  unsigned int mask;
 
  mask = GetLogicalDrives ();
  for (i = 0; i < 26; i++)
    {
      if (mask & (1 << i))
	continue;
      break;
    }
  return (i == 26 ? -1 : 'A' + i);
}

void dostounix_filename (char *);

/* Return nonzero if NAME is of the form \\host\share (forward slashes
   also valid), otherwise return 0.  */
static int
is_toplevel_share_name (char *filename)
{
  int len;
  char *name;
  char *host;
  char *share;
  char *suffix;

  len = strlen (filename);
  name = alloca (len + 1);
  strcpy (name, filename);

  dostounix_filename (name);
  if (name[0] != '/' || name[1] != '/')
    return 0;

  host = strtok (&name[2], "/");
  share = strtok (NULL, "/");
  suffix = strtok (NULL, "/");
  if (!host || !share || suffix)
    return 0;

  return 1;
}


/* FILENAME is of the form \\host\share, and stat can't handle names
   of this form.  But stat can handle \\host\share if it's been
   assigned a drive letter.  So we create a network connection to this
   share, assign it a drive letter, stat the drive letter, and
   disconnect from the share.  Hassle... */
static int
stat_toplevel_share (char *filename, void *statbuf)
{
  NETRESOURCE net;
  int drive_letter;
  char drive[4];
  int result;

  drive_letter = get_unassigned_drive_letter ();
  if (drive_letter < 0)
    return -1;
  
  drive[0] = drive_letter;
  drive[1] = ':';
  drive[2] = '\0';
  net.dwType = RESOURCETYPE_DISK;
  net.lpLocalName = drive;
  net.lpRemoteName = filename;
  net.lpProvider = NULL;
  
  switch (WNetAddConnection2 (&net, NULL, NULL, 0))
    {
    case NO_ERROR:
      break;
    case ERROR_ALREADY_ASSIGNED:
    default:
      return -1;
    }
  
  /* Name the toplevel directory on the drive letter. */
  drive[2] = '/';
  drive[3] = '\0';
  result = stat (drive, (void *) statbuf);
  
  /* Strip the slash so we can disconnect. */
  drive[2] = '\0';
  if (WNetCancelConnection2 (drive, 0, TRUE) != NO_ERROR)
    result = -1;

  return result;
}


/* Get the current working directory.  */
int
getwd (char *dir)
{
  return GetCurrentDirectory (MAXPATHLEN, dir);
}

/* Emulate gethostname.  */
int
gethostname (char *buffer, int size)
{
  /* NT only allows small host names, so the buffer is 
     certainly large enough.  */
  return !GetComputerName (buffer, &size);
}

/* Emulate getloadavg.  */
int
getloadavg (double loadavg[], int nelem)
{
  int i;

  /* A faithful emulation is going to have to be saved for a rainy day.  */
  for (i = 0; i < nelem; i++) 
    {
      loadavg[i] = 0.0;
    }
  return i;
}

/* Emulate sleep...we could have done this with a define, but that
   would necessitate including windows.h in the files that used it.
   This is much easier.  */
void
nt_sleep (int seconds)
{
  Sleep (seconds * 1000);
}

/* Emulate rename. */

#ifndef ENOENT
#define ENOENT 2
#endif
#ifndef EXDEV
#define EXDEV 18
#endif
#ifndef EINVAL
#define EINVAL 22
#endif

int
rename (const char *oldname, const char *newname)
{
#ifdef WINDOWS95
  int i, len, len0, len1;
  char *dirs[2], *names[2], *ptr;

  /* A bug in MoveFile under Windows 95 incorrectly renames files in
     some cases.  If the old name is of the form FILENAME or
     FILENAME.SUF, and the new name is of the form FILENAME~ or
     FILENAME.SUF~, and both the source and target are in the same
     directory, then MoveFile renames the long form of the filename to
     FILENAME~ (FILENAME.SUF~) but leaves the DOS short form as
     FILENAME (FILENAME.SUF).  The result is that the two different
     filenames refer to the same file.  In this case, rename the
     source to a temporary name that can then successfully be renamed
     to the target.  */

  dirs[0] = names[0] = oldname;
  dirs[1] = names[1] = newname;
  for (i = 0; i < 2; i++)
    {
      /* Canonicalize and remove prefix.  */
      len = strlen (names[i]);
      for (ptr = names[i] + len - 1; ptr > names[i]; ptr--)
	{
	  if (IS_ANY_SEP (ptr[0]) && ptr[1] != '\0')
	    {
	      names[i] = ptr + 1;
	      break;
	    }
	}
    }

  len0 = strlen (names[0]);
  len1 = strlen (names[1]);

  /* The predicate is whether the file is being renamed to a filename
     with ~ appended.  This is conservative, but should be correct.  */
  if ((len0 == len1 - 1)
      && (names[1][len0] == '~')
      && (!strnicmp (names[0], names[1], len0)))
    {
      /* Rename the source to a temporary name that can succesfully be
	 renamed to the target.  The temporary name is in the directory
	 of the target.  */
      char *tmp, *fulltmp;

      tmp = "eXXXXXX";
      fulltmp = alloca (strlen (dirs[1]) + strlen (tmp) + 1);
      fulltmp[0] = '\0';
      if (dirs[1] != names[1])
	{
	  len = names[1] - dirs[1];
	  strncpy (fulltmp, dirs[1], len);
	  fulltmp[len] = '\0';
	}
      strcat (fulltmp, tmp);
      mktemp (fulltmp);

      if (rename (oldname, fulltmp) < 0)
	return -1;
      
      oldname = fulltmp;
    }
#endif

  if (!MoveFile (oldname, newname))
    {
      switch (GetLastError ())
	{
	case ERROR_FILE_NOT_FOUND:
	  errno = ENOENT;
	  break;
	case ERROR_ACCESS_DENIED:
	  /* This gets returned when going across devices.  */
	  errno = EXDEV;
	  break;
	case ERROR_FILE_EXISTS:
	case ERROR_ALREADY_EXISTS:
	default:
	  errno = EINVAL;
	  break;
	}
      return -1;
    }
  errno = 0;
  return 0;
}

/* Emulate the Unix directory procedures opendir, closedir, 
   and readdir.  We can't use the procedures supplied in sysdep.c,
   so we provide them here.  */

struct direct dir_static;       /* simulated directory contents */
static int    dir_finding;
static HANDLE dir_find_handle;

DIR *
opendir (char *filename)
{
  DIR *dirp;

  /* Opening is done by FindFirstFile.  However, a read is inherent to
     this operation, so we have a flag to handle the open at read
     time.  This flag essentially means "there is a find-handle open and
     it needs to be closed."  */

  if (!(dirp = (DIR *) malloc (sizeof (DIR)))) 
    {
      return 0;
    }

  dirp->dd_fd = 0;
  dirp->dd_loc = 0;
  dirp->dd_size = 0;

  /* This is tacky, but we need the directory name for our
     implementation of readdir.  */
  strncpy (dirp->dd_buf, filename, DIRBLKSIZ);
  return dirp;
}

void
closedir (DIR *dirp)
{
  /* If we have a find-handle open, close it.  */
  if (dir_finding) 
    {
      FindClose (dir_find_handle);
      dir_finding = 0;
    }
  xfree ((char *) dirp);
}

struct direct *
readdir (DIR *dirp)
{
  WIN32_FIND_DATA find_data;
  
  /* If we aren't dir_finding, do a find-first, otherwise do a find-next. */
  if (!dir_finding) 
    {
      char filename[MAXNAMLEN + 3];
      int ln;

      strncpy (filename, dirp->dd_buf, MAXNAMLEN);
      ln = strlen (filename)-1;
      if (!IS_ANY_SEP (filename[ln]))
	strcat (filename, "\\");
      strcat (filename, "*.*");

      dir_find_handle = FindFirstFile (filename, &find_data);

      if (dir_find_handle == INVALID_HANDLE_VALUE) 
	return NULL;

      dir_finding = 1;
    } 
  else 
    {
      if (!FindNextFile (dir_find_handle, &find_data))
	return NULL;
    }
  
  /* NT's unique ID for a file is 64 bits, so we have to fake it here.  
     This should work as long as we never use 0.  */
  dir_static.d_ino = 1;
  
  dir_static.d_reclen = sizeof (struct direct) - MAXNAMLEN + 3 +
    dir_static.d_namlen - dir_static.d_namlen % 4;
  
  dir_static.d_namlen = strlen (find_data.cFileName);
  strncpy (dir_static.d_name, find_data.cFileName, MAXNAMLEN);
  
  return &dir_static;
}

/* Emulate getpwuid and getpwnam.  */

int getuid ();	/* forward declaration */

#define PASSWD_FIELD_SIZE 256

static char the_passwd_name[PASSWD_FIELD_SIZE];
static char the_passwd_passwd[PASSWD_FIELD_SIZE];
static char the_passwd_gecos[PASSWD_FIELD_SIZE];
static char the_passwd_dir[PASSWD_FIELD_SIZE];
static char the_passwd_shell[PASSWD_FIELD_SIZE];

static struct passwd the_passwd = 
{
  the_passwd_name,
  the_passwd_passwd,
  0,
  0,
  0,
  the_passwd_gecos,
  the_passwd_dir,
  the_passwd_shell,
};

struct passwd *
getpwuid (int uid)
{
  int size = PASSWD_FIELD_SIZE;
  
  if (!GetUserName (the_passwd.pw_name, &size))
    return NULL;

  the_passwd.pw_passwd[0] = '\0';
  the_passwd.pw_uid = 0;
  the_passwd.pw_gid = 0;
  strcpy (the_passwd.pw_gecos, the_passwd.pw_name);
  the_passwd.pw_dir[0] = '\0';
  the_passwd.pw_shell[0] = '\0';

  return &the_passwd;
}

struct passwd *
getpwnam (char *name)
{
  struct passwd *pw;
  
  pw = getpwuid (getuid ());
  if (!pw)
    return pw;

  if (strcmp (name, pw->pw_name))
    return NULL;

  return pw;
}


/* We don't have scripts to automatically determine the system configuration
   for Emacs before it's compiled, and we don't want to have to make the
   user enter it, so we define EMACS_CONFIGURATION to invoke this runtime
   routine.  */

static char configuration_buffer[32];

char *
get_emacs_configuration (void)
{
  char *arch, *oem, *os;

  /* Determine the processor type.  */
  switch (get_processor_type ()) 
    {

#ifdef PROCESSOR_INTEL_386
    case PROCESSOR_INTEL_386:
    case PROCESSOR_INTEL_486:
    case PROCESSOR_INTEL_PENTIUM:
      arch = "i386";
      break;
#endif

#ifdef PROCESSOR_INTEL_860
    case PROCESSOR_INTEL_860:
      arch = "i860";
      break;
#endif

#ifdef PROCESSOR_MIPS_R2000
    case PROCESSOR_MIPS_R2000:
    case PROCESSOR_MIPS_R3000:
    case PROCESSOR_MIPS_R4000:
      arch = "mips";
      break;
#endif

#ifdef PROCESSOR_ALPHA_21064
    case PROCESSOR_ALPHA_21064:
      arch = "alpha";
      break;
#endif

    default:
      arch = "unknown";
      break;
    }

  /* Let oem be "*" until we figure out how to decode the OEM field.  */
  oem = "*";

#ifdef WINDOWS95
  os = "win";
#else
  os = "nt";
#endif

  sprintf (configuration_buffer, "%s-%s-%s%d.%d", arch, oem, os,
	   get_nt_major_version (), get_nt_minor_version ());
  return configuration_buffer;
}

/* Conjure up inode and device numbers that will serve the purpose
   of Emacs.  Return 1 upon success, 0 upon failure.  */
int
get_inode_and_device_vals (Lisp_Object filename, Lisp_Object *p_inode, 
			   Lisp_Object *p_device)
{
  /* File uids on NT are found using a handle to a file, which
     implies that it has been opened.  Since we want to be able
     to stat an arbitrary file, we must open it, get the info,
     and then close it.
     
     Also, NT file uids are 64-bits.  This is a problem.  */

  HANDLE handle;
  BOOL result;
  DWORD attrs;
  BY_HANDLE_FILE_INFORMATION info;

  /* We have to stat files and directories differently, so check
     to see what filename references.  */
  attrs = GetFileAttributes (XSTRING (filename)->data);
  if (attrs == 0xFFFFFFFF) {
    return 0;
  }
  if (attrs & FILE_ATTRIBUTE_DIRECTORY) {
    /* Conjure up bogus, but unique, values.  */
    attrs = GetTickCount ();
    *p_inode = make_number (attrs);
    *p_device = make_number (attrs);
    return 1;
  }

  /* FIXME:  It shouldn't be opened without READ access, but NT on x86
     doesn't allow GetFileInfo in that case (NT on mips does).  */
     
  handle = CreateFile (XSTRING (filename)->data,
		       GENERIC_READ,
		       FILE_SHARE_READ | FILE_SHARE_WRITE,
		       NULL,
		       OPEN_EXISTING,
		       FILE_ATTRIBUTE_NORMAL,
		       NULL);
  if (handle == INVALID_HANDLE_VALUE)
    return 0;

  result = GetFileInformationByHandle (handle, &info);
  CloseHandle (handle);
  if (!result)
    return 0;

  *p_inode = make_number (info.nFileIndexLow);	        /* use the low value */
  *p_device = make_number (info.dwVolumeSerialNumber);

  return 1;
}

/* The following pipe routines are used to support our fork emulation.
   Since NT's crt dup always creates inherited handles, we
   must be careful in setting up pipes.  First create 
   non-inherited pipe handles, then create an inherited handle
   to the write end by dup-ing it, and then close the non-inherited
   end that was just duped.  This gives us one non-inherited handle
   on the read end and one inherited handle to the write end.  As
   the parent, we close the inherited handle to the write end after
   spawning the child.  */

/* From callproc.c  */
extern Lisp_Object Vbinary_process_input;
extern Lisp_Object Vbinary_process_output;

void
pipe_with_inherited_out (int fds[2])
{
  int inherit_out;
  unsigned int flags = _O_NOINHERIT;

  if (!NILP (Vbinary_process_output))
    flags |= _O_BINARY;

  _pipe (fds, 0, flags);
  inherit_out = dup (fds[1]);
  close (fds[1]);
  fds[1] = inherit_out;
}

void
pipe_with_inherited_in (int fds[2])
{
  int inherit_in;
  unsigned int flags = _O_NOINHERIT;

  if (!NILP (Vbinary_process_input))
    flags |= _O_BINARY;

  _pipe (fds, 0, flags);
  inherit_in = dup (fds[0]);
  close (fds[0]);
  fds[0] = inherit_in;
}

/* The following two routines are used to manipulate stdin, stdout, and
   stderr of our child processes.

   Assuming that in, out, and err are inherited, we make them stdin,
   stdout, and stderr of the child as follows:

   - Save the parent's current standard handles.
   - Set the parent's standard handles to the handles being passed in.
     (Note that _get_osfhandle is an io.h procedure that 
     maps crt file descriptors to NT file handles.)
   - Spawn the child, which inherits in, out, and err as stdin,
     stdout, and stderr. (see Spawnve)
   - Reset the parent's standard handles to the saved handles.
     (see reset_standard_handles)
   We assume that the caller closes in, out, and err after calling us.  */

void
prepare_standard_handles (int in, int out, int err, HANDLE handles[4])
{
  HANDLE parent, stdin_save, stdout_save, stderr_save, err_handle;

#ifdef WINDOWS95
  /* The Win95 beta doesn't set the standard handles correctly.
     Handicap subprocesses until we get a version that works correctly.  
     Undefining the subprocesses macro reveals other incompatibilities,
     so, since we're expecting subprocs to work in the near future, 
     disable them here.  */
  report_file_error ("Subprocesses currently disabled on Win95", Qnil);
#endif

  parent = GetCurrentProcess ();
  stdin_save = GetStdHandle (STD_INPUT_HANDLE);
  stdout_save = GetStdHandle (STD_OUTPUT_HANDLE);
  stderr_save = GetStdHandle (STD_ERROR_HANDLE);

#ifndef HAVE_NTGUI
  if (!DuplicateHandle (parent, 
		       GetStdHandle (STD_INPUT_HANDLE), 
		       parent,
		       &stdin_save, 
		       0, 
		       FALSE, 
		       DUPLICATE_SAME_ACCESS))
    report_file_error ("Duplicating parent's input handle", Qnil);
  
  if (!DuplicateHandle (parent,
		       GetStdHandle (STD_OUTPUT_HANDLE),
		       parent,
		       &stdout_save,
		       0,
		       FALSE,
		       DUPLICATE_SAME_ACCESS))
    report_file_error ("Duplicating parent's output handle", Qnil);
  
  if (!DuplicateHandle (parent,
		       GetStdHandle (STD_ERROR_HANDLE),
		       parent,
		       &stderr_save,
		       0,
		       FALSE,
		       DUPLICATE_SAME_ACCESS))
    report_file_error ("Duplicating parent's error handle", Qnil);
#endif /* !HAVE_NTGUI */
  
  if (!SetStdHandle (STD_INPUT_HANDLE, (HANDLE) _get_osfhandle (in)))
    report_file_error ("Changing stdin handle", Qnil);
  
  if (!SetStdHandle (STD_OUTPUT_HANDLE, (HANDLE) _get_osfhandle (out)))
    report_file_error ("Changing stdout handle", Qnil);
  
  /* We lose data if we use the same handle to the pipe for stdout and
     stderr, so make a duplicate.  This took a while to find.  */
  if (out == err) 
    {
      if (!DuplicateHandle (parent,
			   (HANDLE) _get_osfhandle (err),
			   parent,
			   &err_handle,
			   0,
			   TRUE,
			   DUPLICATE_SAME_ACCESS))
	report_file_error ("Duplicating out handle to make err handle.",
			  Qnil);
    } 
  else 
    {
      err_handle = (HANDLE) _get_osfhandle (err);
    }

  if (!SetStdHandle (STD_ERROR_HANDLE, err_handle))
    report_file_error ("Changing stderr handle", Qnil);

  handles[0] = stdin_save;
  handles[1] = stdout_save;
  handles[2] = stderr_save;
  handles[3] = err_handle;
}

void
reset_standard_handles (int in, int out, int err, HANDLE handles[4])
{
  HANDLE stdin_save = handles[0];
  HANDLE stdout_save = handles[1];
  HANDLE stderr_save = handles[2];
  HANDLE err_handle = handles[3];
  int i;

#ifndef HAVE_NTGUI
  if (!SetStdHandle (STD_INPUT_HANDLE, stdin_save))
    report_file_error ("Resetting input handle", Qnil);
  
  if (!SetStdHandle (STD_OUTPUT_HANDLE, stdout_save))
    {
      i = GetLastError ();
      report_file_error ("Resetting output handle", Qnil);
    }
  
  if (!SetStdHandle (STD_ERROR_HANDLE, stderr_save))
    report_file_error ("Resetting error handle", Qnil);
#endif /* !HAVE_NTGUI */
  
  if (out == err) 
    {
      /* If out and err are the same handle, then we duplicated out
	 and stuck it in err_handle.  Close the duplicate to clean up.  */
      if (!CloseHandle (err_handle))
	report_file_error ("Closing error handle duplicated from out.", 
			  Qnil);
    }
}

int
random ()
{
  /* rand () on NT gives us 15 random bits...hack together 30 bits.  */
  return ((rand () << 15) | rand ());
}

void
srandom (int seed)
{
  srand (seed);
}

/* Destructively turn backslashes into slashes.  */
void
dostounix_filename (p)
     register char *p;
{
  while (*p)
    {
      if (*p == '\\')
	*p = '/';
      p++;
    }
}

/* Routines that are no-ops on NT but are defined to get Emacs to compile.  */


int 
sigsetmask (int signal_mask) 
{ 
  return 0;
}

int 
sigblock (int sig) 
{ 
  return 0;
}

int 
kill (int pid, int signal) 
{ 
  return 0;
}

int 
setpgrp (int pid, int gid) 
{ 
  return 0;
}

int 
alarm (int seconds) 
{ 
  return 0;
}

int 
unrequest_sigio (void) 
{ 
  return 0;
}

int 
request_sigio (void) 
{ 
  return 0;
}

int 
getuid () 
{ 
  char buffer[256];
  int size = 256;

  if (!GetUserName (buffer, &size))
    /* Assume all powers upon failure.  */
    return 0;

  if (!stricmp ("administrator", buffer))
    return 0;
  else
    /* A complete fabrication...is there anything to base it on? */
    return 123;
}

int 
geteuid () 
{ 
  /* I could imagine arguing for checking to see whether the user is
     in the Administrators group and returning a UID of 0 for that
     case, but I don't know how wise that would be in the long run.  */
  return getuid (); 
}

/* Remove all CR's that are followed by a LF.
   (From msdos.c...probably should figure out a way to share it,
   although this code isn't going to ever change.)  */
int
crlf_to_lf (n, buf)
     register int n;
     register unsigned char *buf;
{
  unsigned char *np = buf;
  unsigned char *startp = buf;
  unsigned char *endp = buf + n;

  if (n == 0)
    return n;
  while (buf < endp - 1)
    {
      if (*buf == 0x0d)
	{
	  if (*(++buf) != 0x0a)
	    *np++ = 0x0d;
	}
      else
	*np++ = *buf++;
    }
  if (buf < endp)
    *np++ = *buf++;
  return np - startp;
}

#define REG_ROOT "SOFTWARE\\GNU\\Emacs\\"

LPBYTE 
nt_get_resource (key, lpdwtype)
    char *key;
    LPDWORD lpdwtype;
{
  LPBYTE lpvalue;
  HKEY hrootkey = NULL;
  DWORD cbData;
  BOOL ok = FALSE;
  
  /* Check both the current user and the local machine to see if 
     we have any resources.  */
  
  if (RegOpenKeyEx (HKEY_CURRENT_USER, REG_ROOT, 0, KEY_READ, &hrootkey) == ERROR_SUCCESS)
    {
      lpvalue = NULL;

      if (RegQueryValueEx (hrootkey, key, NULL, NULL, NULL, &cbData) == ERROR_SUCCESS 
	  && (lpvalue = (LPBYTE) xmalloc (cbData)) != NULL 
	  && RegQueryValueEx (hrootkey, key, NULL, lpdwtype, lpvalue, &cbData) == ERROR_SUCCESS)
	{
	  return (lpvalue);
	}

      if (lpvalue) xfree (lpvalue);
	
      RegCloseKey (hrootkey);
    } 
  
  if (RegOpenKeyEx (HKEY_LOCAL_MACHINE, REG_ROOT, 0, KEY_READ, &hrootkey) == ERROR_SUCCESS)
    {
      lpvalue = NULL;
	
      if (RegQueryValueEx (hrootkey, key, NULL, NULL, NULL, &cbData) == ERROR_SUCCESS &&
	  (lpvalue = (LPBYTE) xmalloc (cbData)) != NULL &&
	  RegQueryValueEx (hrootkey, key, NULL, lpdwtype, lpvalue, &cbData) == ERROR_SUCCESS)
	{
	  return (lpvalue);
	}
	
      if (lpvalue) xfree (lpvalue);
	
      RegCloseKey (hrootkey);
    } 
  
  return (NULL);
}

void
init_environment ()
{
  /* Open a console window to display messages during dumping. */
  if (!initialized)
    AllocConsole ();

  /* Check for environment variables and use registry if they don't exist */
  {
      int i;
      LPBYTE lpval;
      DWORD dwType;

      static char * env_vars[] = 
      {
	  "emacs_path",
	  "EMACSLOADPATH",
	  "SHELL",
	  "EMACSDATA",
	  "EMACSPATH",
	  "EMACSLOCKDIR",
	  "INFOPATH",
	  "EMACSDOC",
	  "TERM",
      };

      for (i = 0; i < (sizeof (env_vars) / sizeof (env_vars[0])); i++) 
	{
	  if (!getenv (env_vars[i]) &&
	      (lpval = nt_get_resource (env_vars[i], &dwType)) != NULL)
	    {
	      if (dwType == REG_EXPAND_SZ)
		{
		  char buf1[500], buf2[500];

		  ExpandEnvironmentStrings ((LPSTR) lpval, buf1, 500);
		  _snprintf (buf2, 499, "%s=%s", env_vars[i], buf1);
		  putenv (strdup (buf2));
		}
	      else if (dwType == REG_SZ)
		{
		  char buf[500];
		  
		  _snprintf (buf, 499, "%s=%s", env_vars[i], lpval);
		  putenv (strdup (buf));
		}

	      xfree (lpval);
	    }
	}
    }
}

#ifdef HAVE_TIMEVAL
#include <sys/timeb.h>

/* Emulate gettimeofday (Ulrich Leodolter, 1/11/95).  */
void 
gettimeofday (struct timeval *tv, struct timezone *tz)
{
  struct _timeb tb;
  _ftime (&tb);

  tv->tv_sec = tb.time;
  tv->tv_usec = tb.millitm * 1000L;
  if (tz) 
    {
      tz->tz_minuteswest = tb.timezone;	/* minutes west of Greenwich  */
      tz->tz_dsttime = tb.dstflag;	/* type of dst correction  */
    }
}
#endif /* HAVE_TIMEVAL */


#ifdef PIGSFLY
Keep this around...we might need it later.
#ifdef WINDOWSNT
{
  /*
   * Find the user's real name by opening the process token and looking
   * up the name associated with the user-sid in that token.
   */

  char            b[256], Name[256], RefD[256];
  DWORD           length = 256, rlength = 256, trash;
  HANDLE          Token;
  SID_NAME_USE    User;

  if (1)
    Vuser_real_login_name = build_string ("foo");
  else if (!OpenProcessToken (GetCurrentProcess (), TOKEN_QUERY, &Token))
    {
      Vuser_real_login_name = build_string ("unknown");
    }
  else if (!GetTokenInformation (Token, TokenUser, (PVOID)b, 256,
				 &trash))
    {
      CloseHandle (Token);
      Vuser_real_login_name = build_string ("unknown");
    }
  else if (!LookupAccountSid ((void *)0, (PSID)b, Name, &length, RefD,
			      &rlength, &User))
    {
      CloseHandle (Token);
      Vuser_real_login_name = build_string ("unknown");
    }
  else
    Vuser_real_login_name = build_string (Name);
}
#else   /* not WINDOWSNT */
#endif  /* not WINDOWSNT */
#endif  /* PIGSFLY */
