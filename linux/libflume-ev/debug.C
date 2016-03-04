
#include "flume_ev_debug.h"
#include "flume_ev_debug_int.h"
#include "parseopt.h"

#define __STDC_FORMAT_MACROS
#include <inttypes.h>

u_int64_t flume_debug_flags;

void
set_debug_flags ()
{
  str df = getenv (FLUME_DBG_SRV_EV);
  if (df && !convertint (df, &flume_debug_flags)) {
    warn << "invalid debug flags given: " << df << "\n";
  }
  if (flume_debug_flags)
    warn ("FLUME debug flags set: 0x%" PRIx64 "\n", flume_debug_flags);
}

void 
flumedbg_warn (flumedbg_lev_t l, const char *fmt, ...)
{
  va_list ap;
  va_start (ap, fmt);
  strbuf b;
  b.vfmt (fmt, ap);
  va_end (ap);
  flumedbg_warn (l, b);
}

void
flumedbg_warn (flumedbg_lev_t l, const str &s)
{
  vec<str> lines;
  static rxx newline ("\\n");
  split (&lines, newline, s);
  for (size_t i = 0; i < lines.size (); i++) {
    switch (l) {
    case CHATTER:
      warn << "++ ";
      break;
    case ERROR:
      warn << "** ";
      break;
    case SECURITY:
      warn << "**SECURITY** ";
      break;
    case FATAL_ERROR:
      warn << "XX ";
      break;
    default:
      warn << "";
      break;
    }
    warnx << lines[i] << "\n";
  }
}
