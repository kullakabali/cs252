#include <cstdio>

#include "shell.hh"

#include <unistd.h>
#include <signal.h>
#include <string.h>
#include <sys/wait.h>

#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <pwd.h>
#include <regex.h>

#include "command.hh"



int yyparse(void);

void yyrestart(FILE * file);

void Shell::prompt1() {
  printf("myshell1>");
  fflush(stdout);
}


void Shell::prompt2() {
  printf("myshell2>");
  fflush(stdout);
}


void Shell::prompt3() {
  printf("myshell2>");
  fflush(stdout);
}


void Shell::prompt4() {
  printf("myshell4>");
  fflush(stdout);
}


extern "C" void ctrl_c(int sig) {
  printf("\n");
  if (isatty(0)) {
    Shell::prompt2();
  }
}

extern "C" void zombie_handler(int sig) {
  pid_t pid = wait3(0, 0, NULL);

  while (waitpid(-1, NULL, WNOHANG) > 0) {
    //printf("dcsd\n");
    //printf("[%d] exited.\n", pid);
    //printf("\n");
  }
}

/*

void source(void) {
  FILE * fd = fopen(".shellrc", "r");
  if (!fd) {
    return;
  }
  else {
    yypush_buffer_state(yy_create_buffer(fd, YY_BUF_SIZE));
    Shell::_srcCmd = true;
    yyparse();
    yypop_buffer_state();
    fclose(in);
    Shell::_srcCmd = false;
  }
}

*/

int main(int argc, char ** argv) {
  //Shell::prompt();

  struct sigaction sa;
  sa.sa_handler = ctrl_c;
  sigemptyset(&sa.sa_mask);
  sa.sa_flags = SA_RESTART;

  if (sigaction(SIGINT, &sa, NULL)) {
    perror("sigaction");
    exit(EXIT_FAILURE);
  }


  struct sigaction sa_z;
  sa_z.sa_handler = zombie_handler;
  sigemptyset(&sa_z.sa_mask);
  sa_z.sa_flags = SA_RESTART;

  if (sigaction(SIGCHLD, &sa_z, NULL)) {
    perror("sigaction");
    exit(EXIT_FAILURE);
  }


    char * temp;

    temp = (char *) malloc(sizeof(char) * 6);
    sprintf(temp, "%d", getpid());

    setenv("$", temp, true);

    if (argv[0]) {

      char buff[100];

      setenv("SHELL", realpath(argv[0], buff), true);

    }

  FILE *fd = fopen(".shellrc", "r");
  if (fd) {
    yyrestart(fd);
    yyparse();
    yyrestart(stdin);
    fclose(fd);
  }
  else {
    if (isatty(0)) {
      Shell::prompt2();
    }
  }



  /*
  if (isatty(0)) {
    Shell::prompt();
  }
  */
  yyparse();
}

Command Shell::_currentCommand;
