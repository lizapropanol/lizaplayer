#include "my_application.h"
#include <stdlib.h>

int main(int argc, char** argv) {
  setenv("ALSOFT_DRIVERS", "pulse", 1);
  setenv("PULSE_PROP_application.name", "lizaplayer", 1);
  setenv("PULSE_PROP_media.role", "music", 1);
  setenv("PULSE_PROP_application.icon_name", "lizaplayer", 1);

  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
