#include "libflumec.h"
#include "flumeclnt_c.h"
#include "sysflume.h"

/* Great a group and puts a few handles in it.
 * Output the new handles to the screen.
 */

static void
usage ()
{
  fprintf (stderr, "usage: newgroup num_users\n");
  exit (1);
}

int main (int argc,  char *argv[])
{
  flume_status_tc status;
  x_handle_tc grouph, temph;
  int nusers;
  int i;

  char *groupname = "allusers";
  char *grouppw;

  if (argc < 2) 
    usage ();

  nusers = atoi (argv[1]);

  /* Make the group handle and its login */
  status = flume_new_group (&grouph, groupname, NULL);
  if (status != FLUME_OK) {
    printf ("error creating group\n");
    exit (1);
  }

  temph = handle_construct (CAPABILITY_GROUP_SELECT | 
                            HANDLE_OPT_PERSISTENT | 
                            HANDLE_OPT_GROUP,
                            grouph);
  status = flume_make_login (temph, 0, 0, &grouppw);
  if (status != FLUME_OK) {
    printf ("error making login\n");
    exit (1);
  } else 
    printf ("group 0x%llx %s\n", grouph, grouppw);
                            
  /* Make each user's handle, login and add all of them to the group */
  x_handlevec_tc userhandles;
  userhandles.len = nusers;
  userhandles.val = malloc (nusers * sizeof(x_handle_tc));

  for (i=0; i<nusers; i++) {
    char *username = "user";
    
    status = flume_new_handle (&temph, 
                              HANDLE_OPT_PERSISTENT | HANDLE_OPT_DEFAULT_ADD, 
                              username);
    if (status != FLUME_OK) {
      printf ("error creating user %d\n", i);
      exit (1);
    }

    userhandles.val[i] = handle_construct (HANDLE_OPT_PERSISTENT | 
                                           HANDLE_OPT_DEFAULT_ADD |
                                           CAPABILITY_SUBTRACT,
                                           temph);

    /* everyone uses the same pw for now */
    status = flume_make_login (userhandles.val[i], 0, 0, &grouppw); 
    if (status != FLUME_OK) {
      printf ("error making login for user %d\n", i);
      exit (1);
    } 
    printf ("user 0x%llx %s\n", userhandles.val[i], grouppw);
  }

  int rc = flume_add_to_group (grouph, &userhandles);
  if (rc) {
    printf ("error adding users to group %d\n", flume_errno);
    exit (1);
  } else
    printf ("Success!\n");
  
  return 0;
}
