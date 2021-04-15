#include <unistd.h>

extern void call(void (*f)()) {
  f();

  int i = 0;

  while (++i < 5) {
    usleep(1000000);
    f();
  }
}
