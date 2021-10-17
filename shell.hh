#ifndef shell_hh
#define shell_hh

#include "command.hh"

struct Shell {

  static void prompt1();
  static void prompt2();
  static void prompt3();
  static void prompt4();

  static Command _currentCommand;
};

#endif
