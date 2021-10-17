/*
 * CS-252
 * shell.y: parser for shell
 *
 * This parser compiles the following grammar:
 *
 *	cmd [arg]* [> filename]
 *
 * you must extend it to understand the complete shell grammar
 *
 */

%code requires
{
#include <string>
#include <string.h>
#include <sys/types.h>
#include <regex.h>
#include <algorithm>
#include <dirent.h>

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

#include <pwd.h>

#include <cstdio>
#include "shell.hh"
#include <unistd.h>
#include <signal.h>
#include <string.h>
#include <sys/wait.h>


#if __cplusplus > 199711L
#define register      // Deprecated in C++11 so remove the keyword
#endif
}

%union
{
  char        *string_val;
  // Example of using a c++ type in yacc
  std::string *cpp_string;
}

%token <cpp_string> WORD
%token NOTOKEN GREAT NEWLINE LESS PIPE TWOGREAT GREATAND GREATGREAT GREATGREATAND AMPERSAND

%{
  //#define yylex yylex
#include <cstdio>
#include "shell.hh"
#include <string>

  void yyerror(const char * s);
  int yylex();

  void expandWildcard(char * prefix, char * suffix);
  bool compare_strings(char * i, char * j);

  static std::vector<char *> sorting = std::vector<char *>();


  %}

  %%

  goal:
  commands
  ;

commands:
command
| commands command
;

command: simple_command
;

simple_command:
pipe_list iomodifier_list background_opt NEWLINE {
  //printf("   Yacc: Execute command\n");
  Shell::_currentCommand.execute();
}
| NEWLINE {
  Shell::_currentCommand.clear();
  if (isatty(0)) {
    Shell::prompt4();
  }
}
| error NEWLINE { yyerrok; }
;

pipe_list:
pipe_list PIPE command_and_args
| command_and_args
;


command_and_args:
command_word argument_list {
  Shell::_currentCommand.
    insertSimpleCommand( Command::_currentSimpleCommand );
}
;

argument_list:
argument_list argument
| /* can be empty */
;

argument:
WORD {
  //printf("   Yacc: insert argument \"%s\"\n", $1->c_str());

  char *p = (char *) "";
  expandWildcard(p, (char *)$1->c_str());
  std::sort(sorting.begin(), sorting.end(), compare_strings);
  for (auto a: sorting) {
    std::string * insertion = new std::string(a);
    Command::_currentSimpleCommand->insertArgument(insertion);
  }

  sorting.clear();

  //Command::_currentSimpleCommand->insertArgument( $1 );
};

command_word:
WORD {
  //printf("   Yacc: insert command \"%s\"\n", $1->c_str());
  Command::_currentSimpleCommand = new SimpleCommand();
  Command::_currentSimpleCommand->insertArgument( $1 );
}
;

iomodifier_opt:
GREAT WORD {
  //printf("   Yacc: insert output \"%s\"\n", $2->c_str());
  Shell::_currentCommand._outFile = $2;
  Shell::_currentCommand._ambiguity++;
}

| LESS WORD {
  Shell::_currentCommand._inFile = $2;
  //Shell::_currentCommand._ambiguity++;
}

| GREATGREAT WORD {
  Shell::_currentCommand._outFile = $2;
  Shell::_currentCommand._append = true;
  Shell::_currentCommand._ambiguity++;
}

| GREATAND WORD {
  std::string * temp = new std::string($2->c_str());
  Shell::_currentCommand._outFile = $2;
  Shell::_currentCommand._errFile = temp;
  Shell::_currentCommand._ambiguity++;

}

| GREATGREATAND WORD {
  std::string * temp = new std::string($2->c_str());
  Shell::_currentCommand._outFile = $2;
  Shell::_currentCommand._errFile = temp;
  Shell::_currentCommand._append = true;
  Shell::_currentCommand._ambiguity++;
}

| TWOGREAT WORD {
  Shell::_currentCommand._errFile = $2;
  Shell::_currentCommand._ambiguity++;
}
;

iomodifier_list:
iomodifier_list iomodifier_opt
| /* can be empty */
;

background_opt:
AMPERSAND {
  Shell::_currentCommand._background = true;
}
| /* can be empty */
;

%%


bool compare_strings(char * i, char * j) {
  return strcmp(i, j) < 0;
}



int compare_const(const void *first, const void *second) {
  return strcmp(*(char *const*)first, *(char *const*)second);
}

  void
yyerror(const char * s)
{
  fprintf(stderr,"%s", s);
}


void expandWildcardsIfNecessary(std::string *arg) {

  /*

     char *store = strdup(arg->c_str());

     if (strchr(store, '*') == NULL && strchr(store, '?') == NULL && strchr(store, '~') == NULL) {
     Command::_currentSimpleCommand->insertArgument(arg);
     return;
     }

     expandWildcard("", store);

     if (entries > 1) {
     qsort(array, entries, sizeof(char *), compare_const);
     }

     for (int i = 0; i < entries; i++) {
     Command::_currentSimpleCommand->insertArgument(array[i]);
     }

     if (array != NULL) {
     free(array);
     }

     array = NULL;
     entries = 0;
     return;



   */






  /*

     char * arg_string = (char *)arg->c_str();

     std::string path;

     if (strchr(arg_string, '?') == NULL & strchr(arg_string, '*') == NULL) {
     Command::_currentSimpleCommand->insertArgument(arg);
     return;
     }

     DIR * directory;

     char * sub;

     if (arg_string[0] == '/') {
     std::size_t finding = arg->find('/');

     while (arg->find('/', finding+1) != -1) {
     finding = arg->find('/', finding+1);
     }

     path = arg->substr(0, finding+1);
     sub = (char *) arg->substr(finding+1, -1).c_str();
     directory = opendir(path.c_str());
     }
     else {
     directory = opendir(".");
     sub = arg_string;
     }

     if (directory == NULL) {
     perror("dir");
     return;
     }

  // 1 convert wildcard to regular expression

  char * regex = (char *) malloc (2 * strlen(arg_string) + 10);
  char * reg = regex;

   *reg = '^';
   reg++;

   while (*sub) {
   if (*sub == '*') {
   *reg = '.';
   reg++;
   *reg = '*';
   reg++;
   }
   else if (*sub == '?') {
   *reg = '.';
   reg++;
   }
   else if (*sub == '.') {
   *reg = '\\';
   reg++;
   *reg = '.';
   reg++;
   }
   else {
   *reg = *sub;
   reg++;
   }

   sub++;
   }

   *reg = '$';
   reg++;
  *reg = 0;

  // 2. compile regular expression

  regex_t re;

  int exbuf = regcomp(&re, regex, REG_EXTENDED|REG_NOSUB);

  if (exbuf != 0) {
    perror("reg");
    return;
  }

  // 3. List directory and add as arguments the entries that match the regular expression

  std::vector<char *> sort = std::vector<char *>();

  struct dirent * ent;

  while ((ent = readdir(directory)) != NULL) {
    if (regexec(&re, ent->d_name, 1, NULL, 0) == 0) {
      if (regex[1] == '.') {
        if (ent->d_name[0] != '.') {
          std::string name(ent->d_name);
          name = path + name;
          sort.push_back(strdup((char *) name.c_str()));
        }
      }
    }
  }

  closedir(directory);
  regfree(&re);

  std::sort(sort.begin(), sort.end(), compare_strings);

  for (auto a: sort) {
    std::string * insertion = new std::string(a);
    Command::_currentSimpleCommand->insertArgument(insertion);
  }

  sort.clear();

  */

}


void expandWildcard(char * prefix, char * suffix) {

  /*

     if (suffix[0] == 0) {
     return;
     }

     bool dir = false;
     if (suffix[0] == '/') {
     dir = true;
     }

     char * s = strchr(suffix, '/');
     char component[1024];

     for (int i = 0; i < 1024; i++) {
     component[i] = 0;
     }

     if (s != NULL) {
     if (prefix[0] == 0 && dir) {
     suffix = s + 1;
     s = strchr(suffix, '/');
     if (s == NULL) {
     strcpy(component, suffix);
     suffix = suffix + strlen(suffix);
     prefix = "/";
     }
     else {
     strncpy(component, suffix, s - suffix);
     suffix++;
     prefix = "/";

     }
     }
     else {
     strncpy(component, suffix, s - suffix);
     suffix++;
     }
     }
     else {
     strcpy(component, suffix);
     suffix = suffix + strlen(suffix);
     }

     char t_prefix[1024];
     for (int i = 0; i < 1024; i++) {
     t_prefix[i] = 0;
     }

     if (component[0] == '~') {
     struct passwd *p;

     if (strcmp(component, "~") == 0) {
     p = getpwnam(getenv("USER"));
     }
     else {
     p = getpwnam(component + 1);
     }

     if (p == NULL) {
     printf("Could not access user %s.\n", component + 1);
     }
     else {
     if (suffix[0] == 0 && prefix[0] == 0) {
     sprintf(t_prefix, "%s", p->pw_dir);
     }
     else if (suffix[0] == 0) {
     sprintf(t_prefix, "%s/%s", p->pw_dir, component);
     }
     else if (suffix[0] == 0) {
     sprintf(t_prefix, "%s/%s", p->pw_dir, suffix);
}

expandWildcardsIfNecesary(t_prefix);
return;
}
}

char n_prefix[1024];

*/

if (suffix[0] == 0) {
  //char * temporary = strdup(prefix);
  sorting.push_back(strdup(prefix));
  return;
}

bool period = false;

if (suffix[0] == '.') {
  period = true;
}

char Prefix[1024];

if (prefix[0] == 0) {
  if (suffix[0] == '/') {
    suffix += 1;
    sprintf(Prefix, "%s/", prefix);
  }
  else {
    strcpy(Prefix, prefix);
  }
}
else {
  sprintf(Prefix, "%s/", prefix);
}

char * s = strchr(suffix, '/');
char component[1024];

if (s != NULL) {
  strncpy(component, suffix, s - suffix);
  component[s - suffix] = 0;
  suffix = s + 1;
}
else {
  strcpy(component, suffix);
  suffix = suffix + strlen(suffix);
}

char newPrefix[1024];
if (strchr(component, '?') == NULL & strchr(component, '*') == NULL) {
  if (Prefix[0] == 0) {
    strcpy(newPrefix, component);
  }
  else {
    sprintf(newPrefix, "%s/%s", prefix, component);
  }

  expandWildcard(newPrefix, suffix);
  return;
}

// 1 convert wildcard to regular expression

char * regex = (char *) malloc (2 * strlen(component) + 10);
char * reg = regex;

*reg = '^';
reg++;

int i = 0;

while (component[i]) {
  if (component[i] == '*') {
    *reg = '.';
    reg++;
    *reg = '*';
    reg++;
  }
  else if (component[i] == '?') {
    *reg = '.';
    reg++;
  }
  else if (component[i] == '.') {
    *reg = '\\';
    reg++;
    *reg = '.';
    reg++;
  }
  else {
    *reg = component[i];
    reg++;
  }

  i++;
}

*reg = '$';
reg++;
*reg = 0;

// 2. compile regular expression

regex_t re;

int exbuf = regcomp(&re, regex, REG_EXTENDED|REG_NOSUB);

char * directory;

if (Prefix[0] == 0) {
  directory = (char *)".";
}
else {
  directory = Prefix;
}

DIR * d = opendir(directory);
if (d == NULL) {
  return;
}


// 3. List directory and add as arguments the entries that match the regular expression

struct dirent * ent;
bool find = false;

while ((ent = readdir(d)) != NULL) {
  if (regexec(&re, ent->d_name, 1, NULL, 0) == 0) {
    find = true;

    //fprintf(stdout, "component = %s, ent->d_name = %s\n", regex, ent->d_name);
    if (Prefix[0] == 0) {
      strcpy(newPrefix, ent->d_name);
    }
    else {
      sprintf(newPrefix, "%s/%s", prefix, ent->d_name);
    }


    if (ent->d_name[0] == '.') {
      //fprintf(stdout, "period\n");

      //fprintf(stdout, "component = %s, ent->d_name = %s\n", regex, ent->d_name);
      if (regex[1] != '.') {
        expandWildcard(newPrefix, suffix);
      }
    }
    else {

      if (strstr(ent->d_name, "resolvconf") == NULL) {

        expandWildcard(newPrefix, suffix);
      }
    }
  }
}

if (!find) {
  if (Prefix[0] == 0) {
    strcpy(newPrefix, component);
  }
  else {
    sprintf(newPrefix, "%s/%s", prefix, component);
  }
  expandWildcard(newPrefix, suffix);
}

closedir(d);
regfree(&re);
free(regex);


}

#if 0
main()
{
  yyparse();
}
#endif
