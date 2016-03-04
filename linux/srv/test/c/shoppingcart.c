#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include "cgl.h"
#include "flumeclnt_c.h"
#include "sessclnt_c.h"
#include "flume_prot_c.h"

/**
 * Client sends a session cookie, shopping cart
 * 1) reads the session cookie
 * 2) retrieves the session data
 * 3) updates it
 * 4) saves session data back to the session server.
 */

static void
error_response (char *msg)
{
  cgl_html_header ();
  cgl_html_begin ("Flume Shopping Cart!");
  fprintf (stdout, "<h2>Shopping Cart Error!</h2>\n");
  fprintf (stdout, "MSG: %s\n", msg);
  cgl_html_end();
  exit(0);
}

void
output_cart (const char *msg1, const char *msg2, const char *sessdata)
{
  printf ("<h2>%s Shopping Cart Contents</h2>\n", msg1);
  printf ("%s\n", sessdata);
  printf ("<BR><BR>\n");
  if (msg2) printf ("Message from server: %s\n", msg2);
}

void
output_form (sess_id_t id, const char *desc, const char *subtotal)
{
  printf ("<HR>\n");
  printf ("<h2>Shopping Cart Actions</h2>\n");
  printf ("<form action=/cgi-bin/cgilaunch method=get>\n"
          "<input type=hidden name=UN value='%s'>\n"
          "<input type=hidden name=PW value='%s'>\n"
          "<input type=hidden name=EXEC value='%s'>\n"
          "<input type=hidden name=CART_ID value='%d'>\n"
          "<b></b> &nbsp;\n"
          "<table>"
          "<tr><td>Cart ID</td><td>%d</td></tr>\n"
          "<tr><td>Description</td><td><input name=desc type=text value='%s'></td></tr>\n"
          "<tr><td>Subtotal</td><td><input name=subtotal type=text value='%s'></td></tr>\n"
          "</table>"
          "<input type=submit name=submit value=submit><BR>\n"
          "</form>\n", 
          cgl_getvalue("UN"), cgl_getvalue("PW"),cgl_getvalue("EXEC"), (int) id,
          (int) id, desc, subtotal);
}

int
main (int argc, char *argv[])
{
  int rc=0;
  char *id_str, *desc = "", *subtotal = "", *submit;
  sess_id_t id = 0;
  char s[32];
  char buf[SESS_MAX_SIZE];
  char *extra_msg = NULL;
  bzero (&buf, sizeof (buf));

  if (cgl_init() < 0) {
    fprintf (stderr, "cgl_init() error %d\n", rc);
    return -1;
  }

  /* If the client did not specify an ID, we create a new one */
  if ((id_str = cgl_getcookie ("CART_ID"))) {
    char *endptr;
    id = strtoull (id_str, &endptr, 0);
    if (*endptr || 
        (id == ULLONG_MAX && errno == ERANGE) ||
        (id == 0 && errno == EINVAL)) {
      extra_msg = "Error parsing CART_ID, created a new CART_ID\n";
      id = 0;
    }
  }
  if (id) {
    if ((rc = sess_recall_session (id, buf, SESS_MAX_SIZE))) {
      extra_msg = "Error recalling cart data, created a new cart\n";
      id = 0;
    }
  } 
  if (id == 0) {
    if (!(id = sess_request_new ())) {
      error_response ("Error creating new session\n");
    }
    if (!extra_msg)
      extra_msg = "Created a new cart for your new session\n";
    sprintf (buf, "Empty");
  }
  sprintf (s, "%d", (int) id);
  rc = cgl_put_cookie("CART_ID", s, "", "", "", 0);


  cgl_html_header ();
  cgl_html_begin ("Flume Shopping Cart");

  /* If the client is submitting new cart contents, update the cart */
  if ((submit = cgl_getvalue ("submit"))) {
    if (!((desc = cgl_getvalue ("desc")) && 
          (subtotal = cgl_getvalue ("subtotal")))) {
      error_response ("Error, either desc or subtotal are undefined\n");
    }

    bzero (&buf, sizeof (buf));
    sprintf (buf, "Product description = %s, Subtotal = %s", desc, subtotal);

    if ((rc = sess_save_session (id, buf, strlen(buf))))
      error_response ("Error 1 saving session!\n");
    output_cart ("New", extra_msg, buf);

  } else {
    if ((rc = sess_save_session (id, buf, strlen(buf))))
      error_response ("Error 2 saving session!\n");
    output_cart ("", extra_msg, buf);
  }

  output_form (id, desc, subtotal);

  cgl_html_end();
  cgl_freeall();
  return 0;
} 
