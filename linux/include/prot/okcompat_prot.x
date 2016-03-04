
%#define OKAUTHTOKSIZE 20
typedef opaque okauthtok_t[OKAUTHTOKSIZE];

enum oksig_t {
  OK_SIG_NONE = 0,
  OK_SIG_HARDKILL = 1,
  OK_SIG_SOFTKILL = 2,
  OK_SIG_KILL = 3,
  OK_SIG_ABORT = 4
};

struct ok_killsig_t {
  oksig_t sig;
  okauthtok_t authtok;
};

