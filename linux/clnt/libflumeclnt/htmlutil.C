// -*-c++-*-
#include "async.h"
#include "flume_cpp.h"
#include "flume_prot.h"
extern "C" { 
#include "cgl.h"
}

str htmlescape (str s) {
  
  short	c;
  char	*cp;

  if (!s)
    return NULL;

  const char  *p = s.cstr ();
  strbuf sb;

  for (cp = (char *)p; *cp; cp++) {
    c = cgl_transtab((unsigned char)(*cp));
    switch(c) {
    case 0:
      sb.fmt ("%c", *cp);
      break;
    case -1:
      break;
    default:
      sb.fmt ("&#%d;", c);
      break;
    }
  }

  return sb;
}
