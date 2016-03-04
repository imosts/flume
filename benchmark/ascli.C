
// $Id: ascli.C,v 1.28 2006-04-23 22:17:19 vandebo Exp $

#include "async.h"
#include "rxx.h"
#include "parseopt.h"
#include "vec.h"
#include "stdlib.h"
#include "time.h"
#include "normdist.h"
#include "basecli.h"
#include "trazcart.h"
#include "tmoincli.h"
#include "moincli.h"
#include "w5cli.h"

#include <stdio.h>
#include <stdlib.h>

FILE *ERR;

#define THOUSAND 1000
#define MILLION  ( THOUSAND * THOUSAND )

struct exit_pair_t {
  exit_pair_t (int q, int t) : qsz (q), tm (t) {}
  int qsz;
  int tm;
};

struct stats_t {
  stats_t () 
    : empties (0), timeouts (0), read_errors (0), rejections (0),
      exit_timeouts (0), bad_responses (0) {}

  int empties;
  int timeouts;
  int read_errors;
  int rejections;
  int exit_timeouts;
  int bad_responses;
  void dump ()
  {
    fprintf (ERR, 
	     "FAILURES: empties=%d; timeouts=%d; read_errors=%d; "
	     "rejections=%d; etimeouts=%d; bad_responses=%d; total=%d\n",
	     empties, timeouts, read_errors, rejections, exit_timeouts,
             bad_responses,
	     empties + timeouts + read_errors + rejections + exit_timeouts);
  }

};
stats_t stats;

static rxx hostport ("([^:]+)(:(\\d+))?");
int nreq;
int nreq_fixed;
int nconcur;
int nrunning;
int clusternodes;
bool sdflag;
bool zippity;
bool noisy;
bool exited;
bool do_logins;
int nleft;
str host;
int port;
str inreq;
str inqry;
str static_url;
int rand_modulus;
int hclient_id;
int latency_gcf;
int num_services;
int timeout;
bool use_latencies;
int nusers;
bool emp_login;
str service_prefix;
bool cycle_svc;
bool cycle_users;
int data_size;
int row_limit;
bool batch_puts;
bool search_worker;
int wait_time;

vec< base_cli* > clienttypes;
vec<int> node_clients;
base_cli *clienttype = NULL;

static void
add_clienttypes () {
  clienttypes.push_back (New trazcart_cli (1));
  clienttypes.push_back (New tmoin_cli (1));
  clienttypes.push_back (New moin_cli (1));
  clienttypes.push_back (New w5_cli (1));
}

static void
close_stderr () { fclose (ERR); }

//
// used for sample throughput
//
struct tpt_pair_t {
  tpt_pair_t (int t, int n) : tm (t), nreq (n) {}
  int tm;
  int nreq;
};

timespec tpt_last_sample, _tsnow;
vec<tpt_pair_t> tpt_samples;
int tpt_sample_period_secs;
int tpt_sample_period_nsecs;
void tpt_do_sample (bool last);
int n_successes;
int last_n_successes;
int lose_patience_after; // end the run if we lost patience
int n_still_patient; // if more than n outstanding, we're still patient

timespec startt;
timespec lastexit;

typedef enum { ASOKWS = 1 } pt1cli_mode_t;
pt1cli_mode_t mode;

void global_do_exit (int rc);
long long stop_timer (const timespec &t);
vec<long long> latencies;
vec<exit_pair_t> exits;
normdist_t *dist;

timespec tsnow () {
  clock_gettime (CLOCK_REALTIME, &_tsnow);
  return _tsnow;
}
 
int
get_cli_write_delay (int id)
{
  return use_latencies ? dist->sample () : 0;
}

int
get_svc_id (int id)
{
  return ((id  % num_services) + 1);
}

static str 
get_svc (int id)
{
  strbuf b (service_prefix);
  if (num_services)
    b << get_svc_id (id);
  return b;
}

static str
get_wait_time ()
{
  if (wait_time == 0)
    return NULL;
  strbuf b ("wait=%d", wait_time);
  return b;
}

static str
get_size (int id)
{
  if (data_size == 0)
    return NULL;
  else 
    return strbuf ("sz=%d", data_size);
}

static str
get_searcher (int id)
{
  if (!search_worker)
    return NULL;
  strbuf b;
  if (row_limit)
	  b.fmt ("cmd=SELECTDR+*+FROM+applicants+order+by+random%%28%%29+limit+%d&submit=submit", row_limit);
  else 
	  b.fmt ("cmd=SELECTDR+*+FROM+applicants&submit=submit");
  return b;
}

str
get_login (int id)
{
  if (!do_logins)
    return NULL;

  strbuf b;
  char prefix = emp_login ? 'e' : 'u';
  assert (nusers <= 1000000);
  id = (id % nusers) + 1;
  b.fmt ("UN=%c%d&PW=%c%d-pw", prefix, id, prefix, id);
  return b;
}

int
next_node ()
{
  for (unsigned i=0; i<node_clients.size(); i++) {
    if (node_clients[i] < (nconcur / clusternodes)) {
      node_clients[i] ++;
      return i + 1;
    }
  }
}

void
done_node (int node)
{
  if (clusternodes) 
    node_clients[node-1] --;
}

class hclient_t {
public:
  hclient_t () : cli_write_delay (get_cli_write_delay (id))
  {
    init ();
  }

  void init ()
  {
    id = hclient_id++;
    reqsz = -1;
    body = NULL;
    success = false;
    output_stuff  = false;
    selread_on  = true;
    tcb  = NULL ;
    wcb  = NULL;
    destroyed  = New refcounted<bool> (false);
    user_idx = -1;
    node = next_node ();

    client_extension = clienttype ? clienttype->clone () : NULL;
  }

  ~hclient_t () 
  {
    close ();
    *destroyed = true;
  }

  void run ();
  void timed_out (ptr<bool> d);

private:
  void launch_others ();
  void connected (ptr<bool> d_local, int f);
  void canread ();
  void do_read ();
  void hclient_do_exit (int c);
  void writewait ();
  void cexit (int rc);
  void sched_read ();
  void sched_write (ptr<bool> d);

  void turn_off ()
  {
    if (selread_on && fd >= 0) {
      fdcb (fd, selread, NULL);
      selread_on = false;
      success = true;
    } else {
      success = false;
    }
  }

  void close ()
  {
    if (fd >= 0) {
      turn_off ();
      // close (fd);
      tcp_abort (fd);
      fd = -1;
    }
  }
    
  timespec cli_start;
  int fd;
  int id;
  int reqsz;
  char *body;
  strbuf buf;
  const int cli_write_delay;
  str qry;
  bool success;
  bool output_stuff;
  bool selread_on;
  timecb_t *tcb, *wcb;
  ptr<bool> destroyed;
  int user_idx;
  base_cli *client_extension;
  int node;
};

vec<hclient_t *> q;

void
hclient_t::launch_others ()
{
  hclient_t *h;
  while (nrunning < nconcur && nleft) {
    if (q.size ()) {
      if (noisy) fprintf (ERR, "launched queued req: %d\n", id);
      h = q.pop_front ();
    } else {
      h = New hclient_t ();
      if (noisy) fprintf (ERR, "alloc/launch new req: %d\n", id);
      nleft --;
    }
    h->run ();
  }
}

void
hclient_t::writewait ()
{
  fd_set fds;
  FD_ZERO (&fds);
  FD_SET (fd, &fds);
  select (fd + 1, NULL, &fds, NULL, NULL);
}

void
hclient_t::cexit (int c)
{
  if (tcb) {
    timecb_remove (tcb);
    tcb = NULL;
  }
  if (wcb) {
    timecb_remove (wcb);
    wcb = NULL;
  }

  if (noisy) fprintf (ERR, "at cexit: %d\n", id);
  turn_off ();
  done_node (node);
  hclient_do_exit (c);
}

void
hclient_t::hclient_do_exit (int c)
{
  if (c == 0)
    n_successes ++;

  lastexit = tsnow ();

  if (noisy) fprintf (ERR, "at cexit2: %d\n", id);
  --nrunning;
  launch_others ();
  if (noisy) fprintf (ERR, "done: %d (nreq: %d)\n", id, nreq);
  if (success)
    latencies.push_back (stop_timer (cli_start));
  if (!--nreq && sdflag)
    global_do_exit (c);
  delete this;
  return;
}

static rxx sz_rxx ("[C|c]ontent-[l|L]ength: (\\d+)\\r\\n");

void
hclient_t::canread ()
{
  do_read ();
}

void
hclient_t::do_read ()
{
  int rc = buf.tosuio()->input (fd);
  if (rc == 0) {
    int ret = 0;

    if (buf.tosuio ()->resid () == 0) {
      stats.empties ++;
      ret = -1;
      fprintf (ERR, "no content before EOF\n");
    }

    if (client_extension && (client_extension->parse_resp (buf) < 0)) {
      stats.bad_responses ++;
      ret = -1;
      fprintf (ERR, "bad response from server\n");
    }

    while (buf.tosuio()->resid ())
      buf.tosuio()->output (1);
    cexit (ret);

  } else if (rc == -1) {
    if (errno != EAGAIN) {
      stats.read_errors ++;
      fprintf (ERR, "read error; errno=%d\n", errno);
      cexit (-1);
    }
  } else {
    // rc > 0
    // Do nothing
  }
}

void 
hclient_t::connected (ptr<bool> d_local, int f)
{
  if (*d_local) {
    if (f > 0)
      ::close (f);
    stats.timeouts ++;
    fprintf (ERR, "timed out before connect succeeded\n");
    return;
  }

  fd = f;

  if (fd < 0) {
    stats.rejections ++;
    fprintf (ERR, "connection rejected\n");
    cexit (-1);
    return;
  }

  if (cli_write_delay == 0)
    sched_write (destroyed);
  else {
    wcb = delaycb (cli_write_delay / 1000, (cli_write_delay % 1000) * 1000000, 
		   wrap (this, &hclient_t::sched_write, destroyed));
  }
}

int id_global_ct = 0;

void
hclient_t::sched_write (ptr<bool> d_local)
{
  wcb = NULL;
  if (*d_local) {
    stats.timeouts ++;
    fprintf (ERR, "destroyed before writing possible\n");
    return;
  }

  strbuf b;
  int id;
  if (cycle_svc)
    id = random() % rand_modulus;
  else
    id = ++ id_global_ct ;

  int id2 = random() % rand_modulus;

  user_idx = cycle_users ? id : id2;

  // format param string extensively
  vec<str> params;
  str s;
  if ((s = get_login (user_idx)))
    params.push_back (s);
  if ((s = get_size (id2)))
    params.push_back (s);
  if (batch_puts)
    params.push_back ("b=1");
  if ((s = get_searcher (id2)))
    params.push_back (s);
  if ((s = get_wait_time ()))
    params.push_back (s);
  //if ((s = get_executable ()))
  //params.push_back (s);

  strbuf b2;
  for (u_int i = 0; i < params.size (); i++) {
    if (i != 0)
      b2 << "&";
    b2 << params[i];
  }
  s = b2;
  
  if (client_extension) {
    b << client_extension->get_req ();

  } else {
    b << "GET /" << get_svc (id) 
      << "?" << s << " HTTP/1.0\r\n"
      << "User-agent: ASCLI - Reaming Web Servers Since 2004\r\n"
      << "Connection: close\r\n\r\n";
  }

  // this might qualify as "deafening"
  str tmp = b;
  if (noisy) 
    fprintf (ERR, "%s", tmp.cstr ());
  
  suio *uio = b.tosuio ();
  while (uio->resid ()) {
    writewait ();
    if (uio->output (fd) < 0)
      fatal << "write error\n";
  }
  sched_read ();
}

void
hclient_t::sched_read ()
{
  selread_on = true;
  fdcb (fd, selread, wrap (this, &hclient_t::canread));
}

// output all measurements in pretty cryptic formats.  we detail those
// formats inline.
void
global_do_exit (int c)
{
  long long total_tm = stop_timer (startt);

  // first print out the latencies.  there is one line here for each
  // request.  the value is the number of microseeconds it takes for the
  // request to complete.
  u_int sz = latencies.size ();
  for (u_int i = 0; i < sz; i++) 
    fprintf (ERR, "%lld\n", latencies[i]);

  // after we're done outputting the latencies, we output the throughputs
  // measured throught the experiment.  we sample throughput once per
  // second, and output the number of requests served in that second.
  // the output is one pair (on a line) per sample.  
  // the first part of the pair is the number of requests completed
  // in the sample interval.
  // the second part of the pair is the number of microsends in the 
  // sample (since we'll never have a 1 second sample exactly).
  tpt_do_sample (true);
  sz = tpt_samples.size ();
  for (u_int i = 0; i < sz; i++)
    fprintf (ERR, "%d,%d\n",  tpt_samples[i].tm, 
	     tpt_samples[i].nreq);

  // output the command line parameters used for this experiment
  // (the number of concurrent clients, the number of total requests,
  // and the time it takes to run the whole experiment).  note that
  // the total time can be misleading, since there might be timeouts
  // (which default to 120 seconds if the server does not respond)
  fprintf (ERR, "%d,%d,%lld\n", nconcur, nreq_fixed, total_tm);

  stats.dump ();

  close_stderr ();
  exit (c);
}

// returns a time in us
static int timeval(const timespec &t) {
  return t.tv_nsec / THOUSAND + t.tv_sec * MILLION;
}

static int timediff (const timespec &t1, const timespec &t2)
{
  return ((timeval (t1) - timeval (t2)) / MILLION);
}


// returns a time in microseconds
long long
stop_timer (const timespec &tm)
{
  long long ret = (long long)(tsnow ().tv_nsec - tm.tv_nsec) / (long long)THOUSAND;
  long long tmp = (long long)(tsnow ().tv_sec - tm.tv_sec) * (long long)MILLION;
  ret += tmp;
  return ret;
}

void
hclient_t::run ()
{
  str h;
  if (noisy) fprintf (ERR, "run: %d\n", id);
  if (nrunning >= nconcur) {
    if (noisy) fprintf (ERR,  "queuing: %d\n", id);
    q.push_back (this);
    return;
  }
  nrunning++;
  cli_start = tsnow ();

  if (clusternodes) {
    strbuf sb;
    sb << host << node;
    h = str (sb);
  } else
    h = host;

  if (noisy) fprintf (ERR, "running: %d (nrunning: %d)\n", id, nrunning );
  if (noisy) fprintf (ERR, "connecting to: %s\n", h.cstr ());

  tcb = delaycb (timeout, 0, wrap (this, &hclient_t::timed_out, destroyed));
  tcpconnect (h, port, wrap (this, &hclient_t::connected, destroyed));
}

void
hclient_t::timed_out (ptr<bool> d_local) 
{
  stats.timeouts ++;
  if (*d_local) {
    fprintf (ERR, "unexpected timeout -- XXX\n");
    return;
  }

  fprintf (ERR, "client timed out: %d\n", id);
  tcb = NULL;
  cexit (-1);
}

static void
usage ()
{
  warnx << "usage: " << progname << " [-cdflnprstvwbCLMSTUEmRYeN] <host:port>\n"
	<< "  Description of flags (default values in []'s)\n"
	<< "     -c<i>: set the number of concurrent connections to i [1]\n"
	<< "     -d   : turn on debug statements [false]\n"
	<< "     -f<i>: set thrpt sampling frequency to i msecs [1000]\n"
	<< "     -l   : use random client latencies (normally distributed) "
	<< "[false]\n"
	<< "     -n<i>: set the total number of connections to make to "
	<< "i [1000]\n"
	<< "     -p<s>: set the service prefix to string s [\"s\"]\n"
	<< "     -r<i>: set rand module to i for generating random IDs "
	<< "[30000]\n"
	<< "     -s<i>: request sz=i in URL if i is non-zero [0]\n"
	<< "     -t<i>: start run at time i (UNIX timestamp)\n"
	<< "     -v<i>: rotate between i services [1]\n"
	<< "     -w<i>: tell app to wait i jiffies before responding\n"
	<< "     -b   : batch puts together (no puthcar) [false]\n"
	<< "     -C   : randomly choose service [sequential by default]\n"
	<< "     -L   : turn off logins\n"
	<< "     -M<i>: if using latencies, set mean = i [75msec]\n"
	<< "     -S<i>: if using latencies, set stddev=i [25]\n"
	<< "   -T<i,j>: lose patience if fewer than i left and j "
	<< "secs of quiet elapsed []\n"
	<< "     -U<i>: alternate between i users [1]\n"
	<< "     -E   : login with employers (e1) instead of users (u1)\n"
	<< "     -m   : Use search worker\n"
	<< "     -R<i>: For search worker, return at most i rows from the DB\n"
	<< "     -Y   : pick users randomly [false]\n"
	<< "     -e<s>: Send stderr to the file in s [stderr]\n"
        << "     -N<i>: Cycle through <i> cluster nodes (appends [1,i] to host) (-c means per node concurrenc)\n"
	<< "\n";

  for (int i=0; i<clienttypes.size(); i++)
    warnx << clienttypes[i]->usage (progname) << "\n";

  warnx << "\n"
        << "NOTES\n"
	<< " * I suggest using a numerical IP address as opposed to a \n"
	<< "   hostname to factor out DNS latency.\n" 
	<< " * Output of the form L\\n is a latency measurement; it means\n"
	<< "   that one the connection waited L usecs between issuing its\n"
	<< "   HTTP request and receiving the last byte of the server's\n"
	<< "   response.\n"
	<< " * Output of the form A,B\\n is interpreted as a throughput\n"
	<< "   sample meaning that B connections succeeded in an A usec\n" 
	<< "   window; use the -s flag to adjust the length of this window.\n"
	<< " * Output of the form C,D,E\\n: C and D tell which parameters\n"
	<< "   were used in the run, and E tells how long the run lasted,\n"
	<< "   from start to finish.\n"
	<< "\n";

  close_stderr ();
  exit (1);
}

void
tpt_do_sample (bool last)
{
  long long diff = stop_timer (tpt_last_sample);
  int num = n_successes - last_n_successes;
  last_n_successes = n_successes;

  //warnx << diff << "  " << timeval(tsnow ()) << "\n";
  tpt_samples.push_back (tpt_pair_t (diff, num));
  tpt_last_sample = tsnow ();
  if (!last)
    delaycb (tpt_sample_period_secs, tpt_sample_period_nsecs, 
	     wrap (tpt_do_sample, false));
}

static void
main2 (int n)
{
  lastexit = tsnow ();
  startt = tsnow ();
  nleft = n - nconcur;
  
  tpt_last_sample = tsnow ();
  delaycb (tpt_sample_period_secs, tpt_sample_period_nsecs, 
	   wrap (tpt_do_sample, false));
  for (int i = 0; i < nconcur; i++) {
    hclient_t *h = New hclient_t ();
    h->run ();
  }
}

static void schedule_lose_patience_timer ();

static void
lose_patience_cb ()
{
  if (noisy)
    fprintf (ERR, "lpcb: td=%d; nleft=%d\n", 
	     timediff (tsnow (), lastexit), nleft);
  if (lose_patience_after &&  
      timediff (tsnow (), lastexit) > lose_patience_after &&
      n_still_patient &&
      nreq < n_still_patient) {
    stats.exit_timeouts += nreq;
    global_do_exit (0);
  } else
    schedule_lose_patience_timer ();
}

void
schedule_lose_patience_timer ()
{
  delaycb (1, 0, wrap (lose_patience_cb));
}



int 
main (int argc, char *argv[])
{
  timeout = 120;
  noisy = false;
  zippity = false;
  srandom(time(0));
  setprogname (argv[0]);
  int ch;
  int sample_tmp;
  int n = 1000;
  nconcur = 1; 
  clusternodes = 0;
  bool delay = false;
  timespec startat;
  startat.tv_nsec = 0;
  exited = false;
  rand_modulus = 30000;
  hclient_id = 1;
  use_latencies = false;
  num_services = 1;
  tpt_sample_period_secs = 1;
  tpt_sample_period_nsecs = 0;
  int lat_stddv = 25;
  int lat_mean = 75;
  nusers = 1;
  emp_login = false;
  service_prefix = "s";
  cycle_svc = false;
  do_logins = true;
  data_size = 0;
  row_limit = 0;
  batch_puts = false;
  search_worker = false;
  n_successes = 0;
  last_n_successes = 0;
  cycle_users = true;
  wait_time = 0;
  lose_patience_after = 0;
  ERR = stderr;

  add_clienttypes ();

  static rxx lose_patience_rxx ("(\\d+),(\\d+)");

  while ((ch = getopt (argc, argv, 
		       "+Cdp:f:c:n:t:r:v:lS:M:U:Ls:bR:mEw:T:e:N:")) != -1) {
    switch (ch) {
    case 'e':
      ERR = fopen (optarg, "a");
      if (!ERR) 
	fatal << "cannot open stderr file: " << optarg << "\n";
      break;
    case 'T':
      if (!lose_patience_rxx.match (optarg) ||
	  !convertint (lose_patience_rxx[1], &n_still_patient) ||
	  !convertint (lose_patience_rxx[2], &lose_patience_after))
	usage ();
      break;
    case 'w':
      if (!convertint (optarg, &wait_time))
	usage ();
      if (noisy) warn << "Setting application wait time at " << wait_time
		      << " jiffies\n";
      break;
    case 'Y':
      cycle_users = false;
      if (noisy) warn << "Now picking random users...\n";
      break;
    case 'b':
      batch_puts = true;
      break;
    case 's':
      if (!convertint (optarg, &data_size))
	usage ();
      if (noisy)
	warn << "Using data sz=" << data_size << " for all REQs\n";
      break;
    case 'L':
      do_logins = false;
      if (noisy) warn << "Not doing logins...\n";
      break;
    case 'm':
      search_worker = true;
      if (noisy) warn << "Using search worker...\n";
      break;
    case 'R':
      if (!convertint (optarg, &row_limit))
		  usage ();
      break;
    case 'C':
      cycle_svc = true;
      break;
    case 'U':
      if (!convertint (optarg, &nusers))
	usage ();
      if (noisy) warn << "Number of users: " << nusers << "\n";
      break;
    case 'E':
      emp_login = true;
      break;
    case 'p':
      service_prefix = optarg;
      break;
    case 'f':
      if (!convertint (optarg, &sample_tmp))
	usage ();
      if (noisy) 
	warn << "Sample throughput w/ frequence=" << sample_tmp << "ms\n";
      tpt_sample_period_secs = sample_tmp / 1000;
      tpt_sample_period_nsecs = (sample_tmp % 1000) * 1000000;
      break;
    case 'S':
      if (!convertint (optarg, &lat_stddv))
        usage ();
      if (noisy) warn << "Standard dev. of latency: " << lat_stddv << "\n";
      break;
    case 'M':
      if (!convertint (optarg, &lat_mean))
        usage ();
      if (noisy) warn << "Mean of latencies: " << lat_mean << "\n";
      break;
    case 'r':
      if (!convertint (optarg, &rand_modulus))
	usage ();
      if (noisy) warn << "Random modulus: " << rand_modulus << "\n";
      break;
    case 'v':
      if (!convertint (optarg, &num_services))
	usage ();
      if (noisy) warn << "Num Services: " << num_services << "\n";
      break;
    case 'l':
      use_latencies = true;
      if (noisy) warn << "Using Latencies\n";
      break;
    case 'd':
      noisy = true;
      break;
    case 'c':
      if (!convertint (optarg, &nconcur))
	usage ();
      if (noisy) warn << "Concurrency factor: " << nconcur << "\n";
      break;
    case 'n':
      if (!convertint (optarg, &n))
	usage ();
      if (noisy) warn << "Number of requests: " << n << "\n";
      break;
    case 't': 
      {
	if (!convertint (optarg, &startat.tv_sec))
	  usage ();
	delay = true;
	if (noisy) warn << "Delaying start until time=" 
			<< startat.tv_sec << "\n";
	time_t mytm = time (NULL);
	int tmp =  startat.tv_sec - mytm;
	if (tmp < 0) {
	  warn << "time stamp alreached (it's " << mytm << " right now)!\n";
	  usage ();
	}
	if (noisy) {
	  warn << "Starting in T minus " << tmp << " seconds\n";
	}
	break;
      }
    case 'N':
      if (!convertint (optarg, &clusternodes))
	usage ();
      if (noisy) warn << "Number of cluster nodes: " << clusternodes << "\n";
      break;
      
    default:
      usage ();
    }
  }

  argc -= optind;
  argv += optind;

  if (argc < 1)
    usage ();

  /* Are we running with a different extension? */
  for (int i=0; i<clienttypes.size(); i++)
    if (!strcmp (argv[0], clienttypes[i]->cmd_name().cstr())) {
      clienttype = clienttypes[i];
      clienttype->set_noisy (noisy);
      clienttype->set_errout (ERR);
      
      // optind = optreset = 1;
      optind = 1;
      if ((optind = clienttype->parse_args (argc, argv)) < 0)
        usage ();
      argc -= optind;
      argv += optind;
      break;
    }

  if (argc != 1) 
    usage ();

  if (lose_patience_after && n_still_patient) {
    schedule_lose_patience_timer ();
  }

  str dest = argv[0];

  // normdist (mean, std-dev, "precision")
  if (use_latencies)
    dist = New normdist_t (200,25);

  if (!hostport.match (dest)) 
    usage ();
  host = hostport[1];
  str port_s = hostport[3];
  if (port_s) {
    if (!convertint (port_s, &port)) usage ();
  } else {
    port = 80;
  }

  if (clusternodes) {
    for (int i=0; i<clusternodes; i++)
      node_clients.push_back (0);
    nconcur = nconcur * clusternodes;
    if (noisy) warn << "New concurrency factor: " << nconcur << "\n";
  }

  nrunning = 0;
  sdflag = true;
  nreq = n;
  nreq_fixed = n;

  if (delay) {
    timecb (startat, wrap (main2, n));
  } else {
    main2 (n);
  }
  amain ();
}


