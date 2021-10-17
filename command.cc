/*
 * CS252: Shell project
 *
 * Template file.
 * You will need to add more code here to execute the command table.
 *
 * NOTE: You are responsible for fixing any bugs this code may have!
 *
 * DO NOT PUT THIS PROJECT IN A PUBLIC REPOSITORY LIKE GIT. IF YOU WANT 
 * TO MAKE IT PUBLICALLY AVAILABLE YOU NEED TO REMOVE ANY SKELETON CODE 
 * AND REWRITE YOUR PROJECT SO IT IMPLEMENTS FUNCTIONALITY DIFFERENT THAN
 * WHAT IS SPECIFIED IN THE HANDOUT. WE OFTEN REUSE PART OF THE PROJECTS FROM  
 * SEMESTER TO SEMESTER AND PUTTING YOUR CODE IN A PUBLIC REPOSITORY
 * MAY FACILITATE ACADEMIC DISHONESTY.
 */

#include <cstdio>
#include <cstdlib>
#include <cstring>

#include <iostream>

#include "command.hh"
#include "shell.hh"

#include <unistd.h>
#include <string.h>
#include <fstream>
#include <sys/types.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <errno.h>
#include <string>
#include <stdlib.h>

#include <regex.h>
#include <signal.h>



extern "C" void bang_handler(int) {
  pid_t p;
  int stat;

  while ((p = waitpid(-1, &stat, WNOHANG)) != -1) {
    std::cout << "[" << p << "]" << " exited with code " << stat << std::endl;
  }
}

Command::Command() {
  // Initialize a new vector of Simple Commands
  _simpleCommands = std::vector<SimpleCommand *>();

  _outFile = NULL;
  _inFile = NULL;
  _errFile = NULL;
  _background = false;
  _append = false;
  _ambiguity = 0;
}

void Command::insertSimpleCommand( SimpleCommand * simpleCommand ) {
  // add the simple command to the vector
  _simpleCommands.push_back(simpleCommand);
/*

  int num_simple_commands = _simpleCommands.size();

  for (int i = 0; i < num_simple_commands; i++) {
    if (_env_var) {
      char * current_arg = simpleCommand->_arguments[i];
      char * var = argument + 2;

      int str_len = strlen(var);
      var[str_len - 1] = 0;

      char * cur;

      if (strcmp(var, "SHELL") == 0) {
        cur = _shellLoc;
      }
      else if (strcmp(var, "$") == 0) {
        cur = (char *) malloc(sizeof(char) * 6);
        sprintf(cur, "%d", getpid());
      }
      else if (strcmp(var, "?") == 0) {
        cur = (char *) malloc(sizeof(char));
        sprintf(cur, "%d", _lastCode);
      }
      else if (strcmp(var, "!") == 0) {

        if (_lastBackground == -1) {
          cur = strdup("");
        }
        cur = (char *) malloc(sizeof(char) * 6);
        sprintf(cur, "%d", _lastBackground);
      }
      else if (strcmp(var, "_") == 0) {
        cur = _lastArgument;

      }
      else {
        cur = strdup(getenv(var));
      }

      simpleCommand->_arguments[i] = cur;


    }
  }

  _simpleCommands[ num_simple_commands ] = simpleCommand;
  */
}

void Command::clear() {
  // deallocate all the simple commands in the command vector
  for (auto simpleCommand : _simpleCommands) {
    delete simpleCommand;
  }

  // remove all references to the simple commands we've deallocated
  // (basically just sets the size to 0)
  _simpleCommands.clear();

  if ( _outFile ) {
    delete _outFile;
  }
  _outFile = NULL;

  if ( _inFile ) {
    delete _inFile;
  }
  _inFile = NULL;

  if ( _errFile ) {
    delete _errFile;
  }
  _errFile = NULL;

  _background = false;

  _append = false;

  _ambiguity = 0;

}

void Command::print() {
  printf("\n\n");
  printf("              COMMAND TABLE                \n");
  printf("\n");
  printf("  #   Simple Commands\n");
  printf("  --- ----------------------------------------------------------\n");

  int i = 0;
  // iterate over the simple commands and print them nicely
  for ( auto & simpleCommand : _simpleCommands ) {
    printf("  %-3d ", i++ );
    simpleCommand->print();
  }

  printf( "\n\n" );
  printf( "  Output       Input        Error        Background\n" );
  printf( "  ------------ ------------ ------------ ------------\n" );
  printf( "  %-12s %-12s %-12s %-12s\n",
      _outFile?_outFile->c_str():"default",
      _inFile?_inFile->c_str():"default",
      _errFile?_errFile->c_str():"default",
      _background?"YES":"NO");
  printf( "\n\n" );
}

void Command::execute() {
  // Don't do anything if there are no simple commands
  if ( _simpleCommands.size() == 0 ) {
    if (isatty(0)) {
      Shell::prompt1();
    }
    return;
  }

  //print();


  // Detecting ambiguity with output files

  if (_ambiguity > 1) {
    printf("Ambiguous output redirect.\n");
    clear();
    exit(1);
    //Shell::prompt();
    return;

  }


  // Exit

  if (!strcmp(_simpleCommands[0]->_arguments[0]->c_str(), "exit")) {
    //printf("Good bye!!\n");
    exit(1);
  }


  int num_simple_commands = _simpleCommands.size();

  // setenv - set the environment variable A to value B

  if (!strcmp(_simpleCommands[0]->_arguments[0]->c_str(), "setenv")) {
    setenv(_simpleCommands[0]->_arguments[1]->c_str(), _simpleCommands[0]->_arguments[2]->c_str(), 1);
    clear();
    /*if (isatty(0)) {
      Shell::prompt();
    }*/
    return;
  }

  // unsetenv

  if (!strcmp(_simpleCommands[0]->_arguments[0]->c_str(), "unsetenv")) {
    unsetenv(_simpleCommands[0]->_arguments[1]->c_str());
    clear();
    if (isatty(0)) {
      Shell::prompt2();
    }
    return;
  }

  // cd

  if (!strcmp(_simpleCommands[0]->_arguments[0]->c_str(), "cd")) {
    //printf("Value = %d\n", _simpleCommands[0]->_arguments.size());

    int cd_suc;
    if (_simpleCommands[0]->_arguments.size() == 1) {
      //printf("GOING HOMEEE\n");
      cd_suc = chdir( getenv("HOME") );
    }
    else if (!strcmp(_simpleCommands[0]->_arguments[1]->c_str(), "${HOME}")) {
      cd_suc = chdir( getenv("HOME") );
    }
    else {
      //printf("NOT GOING HOMEEE\n");
      //cd_suc = chdir( _simpleCommands[0]->_arguments[1]->c_str() );
      if ( chdir( _simpleCommands[0]->_arguments[1]->c_str() )) {
        std::string text = ("cd: can't cd to " + *_simpleCommands[0]->_arguments[1]);
        const char *mess = text.c_str();
        perror(mess);
      }
    }

    //printf("0\n");

    if (cd_suc < 0) {
      //perror("cd");
    }

    clear();
    //printf("1\n");

    if (isatty(0)) {
      Shell::prompt3();
      //printf("rr\n");
    }
    return;
  }



  // save stdin, stdout, stderr

  int tmpin = dup(0);
  int tmpout = dup(1);
  int tmperr = dup(2);

  // set the initial input

  int fdin;

  if (_inFile) {
    fdin = open(_inFile->c_str(), O_RDONLY);
  }
  else {
    fdin = dup(tmpin);
  }

  // set the initial error

  int fderr;

  int ret;
  int fdout;


  for (int i = 0; i < num_simple_commands; i++) {
    //redirect input

    dup2(fdin, 0);
    close(fdin);


    // source

    /*

    if (!strcmp(_simpleCommands[0]->_arguments[0]->c_str(), "source")) {

         //FILE *file_pointer = fopen(_simpleCommands[0]->_arguments[1]->c_str(), "r");
         //char cmdline [1024];

         //fgets(cmdline, 1023, file_pointer);

         //fclose(file_pointer);


      std::string cmd;
      std::ifstream fd;

      fd.open(_simpleCommands[i]->_arguments[1]->c_str());

      std::getline(fd, cmd);
      fd.close();

      int tmpin = dup(0);
      int tmpout = dup(1);

      int fdpipein[2];
      int fdpipeout[2];

      pipe(fdpipein);
      pipe(fdpipeout);

      write(fdpipein[1], cmd.c_str(), strlen(cmd.c_str()));
      write(fdpipein[1], "\n", 1);

      close(fdpipein[1]);

      dup2(fdpipein[0], 0);
      close(fdpipein[0]);
      dup2(fdpipeout[1], 1);
      close(fdpipeout[1]);

      int ret = fork();

      if (ret == 0) {
        execvp("/proc/self/exe", NULL);
        _exit(1);
      }
      else if (ret < 0) {
        perror("fork");
        exit(1);
      }

      dup2(tmpin, 0);
      dup2(tmpout, 1);
      close(tmpin);
      close(tmpout);

      char c;
      //char * buff = (char *) malloc (100);

      char * buff = new char[i];

      int x = 0;

      while (read(fdpipeout[0], &c, 1)) {
        if (c != '\n') {
          buff[x++] = c;
        }
      }
      buff[x] = '\0';
      printf("%s\n", buff);

      fflush(stdout);
      clear();
      //Shell::prompt();
      return;


    }

    */




    //setup output

    if (i == num_simple_commands - 1) {
      // last simple command

      // for output file

      if (_outFile) {
        if (_append) {
          fdout = open(_outFile->c_str(), O_CREAT | O_WRONLY | O_APPEND, 0664);
        }
        else {
          fdout = open(_outFile->c_str(), O_CREAT | O_WRONLY | O_TRUNC, 0664);
        }
      }

      else {
        fdout = dup(tmpout);
      }

      // for error file

      if (_errFile) {
        if (_append) {
          fderr = open(_errFile->c_str(), O_CREAT | O_WRONLY | O_APPEND, 0664);
        }
        else {
          fderr = open(_errFile->c_str(), O_CREAT | O_WRONLY | O_TRUNC, 0664);
        }
      }
      else {
        fderr = dup(tmperr);
      }

      dup2(fderr, 2);
      close(fderr);

    }

    else {
      // not last simple command

      // create pipe

      int fdpipe[2];
      pipe(fdpipe);
      fdout = fdpipe[1];
      fdin = fdpipe[0];

    }

    // redirect output

    dup2(fdout, 1);
    close(fdout);

    // create child process

    ret = fork();

    /*

       if (ret == -1) {
       perror("fork\n");
       exit(2);
       }

     */

    int num_sub_arguments = _simpleCommands[i]->_arguments.size();
    char ** args = new char*[num_sub_arguments + 1];

    //args[num_sub_arguments] = NULL;
    int j;
    for (j = 0; j < num_sub_arguments; j++) {
      args[j] = strdup(_simpleCommands[i]->_arguments[j]->c_str());
    }

    args[j] = NULL;



    if (ret == 0) {
      // printenv

      close(tmpin);
      close(tmpout);
      close(tmperr);

      if (!strcmp(_simpleCommands[i]->_arguments[0]->c_str(), "printenv")) {
        char **p = environ;
        while (*p != NULL) {
          printf("%s\n", *p);
          p++;
        }

        exit(0);



      }
      execvp(_simpleCommands[i]->_arguments[0]->c_str(), args);

      //printf("before ex error\n");
      perror("execvp");

      //printf("after ex error\n");
      _exit(1);

    }
    else if (ret < 0) {
      perror("fork");
      return;
    }

  }

  // restore stdin, stdout defaults

  dup2(tmpin, 0);
  dup2(tmpout, 1);
  close(tmpin);
  close(tmpout);

  // restore stderr defualt

  dup2(tmperr, 2);
  close(tmperr);




  if (!_background) {
    // wait for last command
    int last_status;
    waitpid(ret, &last_status, 0);
    //std::string stat = std::to_string(WEXITSTATUS(last_status));
    if (WIFEXITED(last_status)) {
      setenv("?", std::to_string(WEXITSTATUS(last_status)).c_str(), true);
    }
    /*
    char *perr = getenv("ON_ERROR");
    if (perr != NULL && WEXITSTATUS(last_status)) {
      printf("%s\n", perr);
    }*/

    setenv("_", _simpleCommands.back()->_arguments.back()->c_str(), true);


    char * temp;

    temp = (char *) malloc(sizeof(char) * 6);
    sprintf(temp, "%d", getpid());

    setenv("$", temp, true);


  }
  else {
  /*
    std::string last_process = std::to_string(ret);
    setenv("!", last_process.c_str(), true);
    Shell::_bgPIDs.push_back(ret);

    */

   std::cout << "[1] " << ret << std::endl;
   struct sigaction s;
   s.sa_handler = bang_handler;
   sigemptyset(&s.sa_mask);
   s.sa_flags = SA_RESTART;
   if (sigaction(SIGCHLD, &s, NULL)) {
      exit(-1);
   }

   setenv("!", std::to_string(ret).c_str(), true);

   /*

    char * temp;

    temp = (char *) malloc(sizeof(char) * 6);
    sprintf(temp, "%d", getpid());

    setenv("$", temp, true);

    */


  }


  // Print contents of Command data structure
  //print();

  // Add execution here
  // For every simple command fork a new process
  // Setup i/o redirection
  // and call exec

  // Clear to prepare for next command
  clear();

  // Print new prompt
  if (isatty(0)) {
    Shell::prompt2();
  }
}

SimpleCommand * Command::_currentSimpleCommand;
