#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include "cgl.h"
#include "flumeclnt_c.h"
#include "sessclnt_c.h"
#include "flume_prot_c.h"

/**
 * Creates a session on the server
 */

static void
output_form ()
{
  printf ("<h2>sesscgi</h2>\n");
  printf ("<form action=/cgi-bin/cgilaunch method=get>\n"
          "<input type=hidden name=UN value='%s'>\n"
          "<input type=hidden name=PW value='%s'>\n"
          "<input type=hidden name=EXEC value='sesscgi'>\n"
          
          "<p>"
          "<b>Request new session ID:</b> &nbsp;<BR>\n"
          "<input type=submit name=submit value=reqnewid>\n"
          "<HR>\n"
          
          "<p>"
          "<b>Store data:</b> &nbsp;\n"
          "ID: <input name=ID type=text> &nbsp;<BR>\n"
          "Data: <input name=DATA type=text> &nbsp;<BR>\n"
          "<input type=submit name=submit value=savedata>\n"
          "<HR>\n"
          
          "<p>"
          "<b>Retrieve data for session: \n"
          "ID: <input name=ID type=text><BR>\n"
          "<input type=submit name=submit value=getdata><BR>\n"
          "<HR>\n"
          
          "</form>\n", cgl_getvalue("UN"), cgl_getvalue("PW"));
  
}

static void
get_new_id ()
{
  sess_id_t id = sess_request_new();
  if (id) 
    printf ("id is: %llx\n", id);
  else
    printf ("error getting new session id\n");
    
}

static void
store_data ()
{
  sess_id_t id;
  char *id_str = cgl_getvalue("ID");
  char *data = cgl_getvalue("DATA");

  if (!id_str) {
    printf ("ID is not defined!\n");
    return;
  } else if (!data) {
    printf ("DATA is not defined!\n");
    return;
  }

  char *endptr;
  id = strtoull (id_str, &endptr, 0);
  if (*endptr || 
      (id == ULLONG_MAX && errno == ERANGE) ||
      (id == 0 && errno == EINVAL)) {
    printf ("Error parsing ID\n");
    return;
  }

  int err = sess_save_session (id, data, strlen(data));
  if (err) {
    printf ("Error saving session!\n");
  } else {
    printf ("Success saving session!\n");
  }    
}

static void
recall_data ()
{
  sess_id_t id;
  char *id_str = cgl_getvalue("ID");
  char buf[SESS_MAX_SIZE];

  if (!id_str) {
    printf ("ID is not defined!\n");
    return;
  }
  char *endptr;
  id = strtoull (id_str, &endptr, 0);
  if (*endptr || 
      (id == ULLONG_MAX && errno == ERANGE) ||
      (id == 0 && errno == EINVAL)) {
    printf ("Error parsing ID\n");
    return;
  }

  int err = sess_recall_session (id, buf, SESS_MAX_SIZE);
  if (err) {
    printf ("Error recalling session data\n");
  } else {
    printf ("got session data: [%s]\n", buf);
  }
}

int
main (int argc, char *argv[])
{
  int rc=0;
  char *submit = NULL;

  if (cgl_init() < 0) {
    fprintf (stderr, "cgl_init() error %d\n", rc);
    return -1;
  }
  
  cgl_html_header ();
  cgl_html_begin ("sesscgi!");
  
  submit = cgl_getvalue("submit");
  fprintf (stderr, "submit value is %s\n", submit);

  /*
  fprintf (stderr, "O label: ");
  flume_print_label (LABEL_O, stderr);
  fprintf (stderr, "S label: ");
  flume_print_label (LABEL_S, stderr);
  */

  /* Now this CGI is acting as a declassifier */

  if (!submit) {
    output_form ();
    goto done;
  
  } else if (!strcmp(submit, "reqnewid")) {
    get_new_id ();
    
  } else if (!strcmp(submit, "savedata")) {
    store_data ();
    
  } else if (!strcmp(submit, "getdata")) {
    recall_data ();

  } else {
    printf ("Error, unexpected submit value\n");
  }

 done:
  cgl_html_end();
  cgl_freeall();
  return 0;
} 
