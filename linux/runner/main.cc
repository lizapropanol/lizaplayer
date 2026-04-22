#include "my_application.h"
#include <stdlib.h>

int main(int argc, char** argv) {
  setenv("ALSOFT_DRIVERS", "pulse", 1);
  setenv("SDL_AUDIODRIVER", "pulseaudio", 1);
  setenv("PIPEWIRE_REMOTE", "disabled_for_discord_sharing", 1);
  
  setenv("PULSE_PROP_application.name", "lizaplayer", 1);
  setenv("PULSE_PROP_application.icon_name", "lizaplayer", 1);
  setenv("PULSE_PROP_window.x11.res_class", "lizaplayer", 1);

  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
