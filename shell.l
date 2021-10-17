
/*
 *
 * CS-252 
 * shell.l: lexical analyzer for shell
 * You have to extend it.
 *
 */



%{

#include <cstring>
#include "y.tab.hh"

#include <iostream>

#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include "shell.hh"

#include <sys/types.h>
#include <sys/wait.h>
#include <string.h>
#include <fstream>



////////////  Start added code ///////////


extern "C" char * read_line();

int mygetc(FILE * f) {
  static char *p;
  char ch;

     if (!isatty(0)) {
  // stdin is not a tty. Call real getc
    return getc(f);
  }

  // stdin is a tty. Call our read_line.
  if (p==NULL || *p == 0) {
    char * s = read_line();
    p = s;
  }

  ch = *p;
  p++;

  return ch;
}

#undef getc
#define getc(f) mygetc(f)

/////////// End added code ///////////



static  void yyunput (int c,char *buf_ptr  );

void myunputc(int c) {
  unput(c);
}

%}

%option noyywrap

%%

\n {
  return NEWLINE;
}

[ \t] {
  /* Discard spaces and tabs */
}

">" {
  return GREAT;
}

"<" {
  return LESS;
}

"|" {
  return PIPE;
}

"2>" {
  return TWOGREAT;
}

">&" {
  return GREATAND;
}

">>" {
  return GREATGREAT;
}

">>&" {
  return GREATGREATAND;
}

"&" {
  return AMPERSAND;
}


"source "[^ \t\n|><][^ \t\n|><]* {
    std::string *name = new std::string(yytext + strlen("source "));
    std::ifstream file;
    file.open(*name);
    std::vector<std::string> all_lines;
    std::string line;

    while(std::getline(file, line)) {
        line += "\n";
        all_lines.push_back(line);
    }
    file.close();
    for(int l = all_lines.size() - 1; l >= 0; l--) {
        for (int j = all_lines[l].length() - 1; j >= 0; j--) {
            myunputc(all_lines[l][j]);
        }
    }
}

$\{[^ \}\n]*\}([^ \n]*|$\{[^ \}\n]*\})* {


  std::string text = std::string(yytext);
  std::string qu = "";

  std::size_t dollar = text.find('$');

  while (dollar != -1) {
    std::string c;

    qu += text.substr(0, dollar);
    if (text[dollar+1] == '{') {
      std::size_t last = text.find('}');

      if (last != -1) {
        c = text.substr(dollar + 2, last - dollar - 2);

        if (getenv(c.c_str())) {
          qu = qu + getenv(c.c_str());
        }
        else {
          qu = qu + c;
        }
        text = text.substr(last + 1, -1);
      }
    }
    dollar = text.find('$');
  }

  qu = qu + text;
  yylval.cpp_string = new std::string(qu);
  return WORD;
}



\$\([^\n\$]*\)|`[^\n`]*` {

  std::string * text = new std::string(yytext);
  text->pop_back();

  if (strchr(text->c_str(), '`') != NULL) {
    text = new std::string(yytext + 1);
  }
  else {
    text = new std::string(yytext+2);
    text->pop_back();
  }

  int tmpin = dup(0);
  int tmpout = dup(1);

  int fdpipein[2];
  int fdpipeout[2];

  pipe(fdpipein);
  pipe(fdpipeout);

  write(fdpipein[1], text->c_str(), text->size());
  write(fdpipein[1], "\n", 1);
  write(fdpipein[1], "exit", 4);
  write(fdpipein[1], "\n", 1);
  close(fdpipein[1]);

  dup2(fdpipein[0], 0);
  close(fdpipein[0]);
  dup2(fdpipeout[1], 1);
  close(fdpipeout[1]);


  int ret = fork();
  if (ret == 0) {
    // child process

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

  char out_char;
  int i = 0;

  char *buffer = new char[6666];
  while (read(fdpipeout[0], &out_char, 1)) {
    if (out_char == '\n' ? buffer[i++] = ' ' : buffer[i++] = out_char);
  }

  buffer[i] = '\0';

  i = strlen(buffer) - 1;

  for (i; i >= 0; i--) {
    unput(buffer[i]);
  }


}

~[^ \n\t]* {

  std::string text = std::string(yytext);
  std::string home_dir = getenv("HOME");

  if (text.size() == 1) {
    yylval.cpp_string = new std::string(home_dir);
  }
  else {
    if (text[1] == '/') {
      text = home_dir + text.substr(1, -1);
    }
    else {
      text = std::string("/homes/") + text.substr(1, -1);
    }

    yylval.cpp_string = new std::string(text);
  }

  return WORD;

}


["][^\n\"]*["] {

  // quotes

  /*

  char * without_quotes = new char[strlen(yytext)];
  char * arguments = yytext;

  int arg_count = 0;
  while (*arguments) {
    if (*arguments != '\"') {
      without_quotes[arg_count] = *arguments;
    } else {
      without_quotes[arg_count] = *(++arguments);
    }

    arg_count++;
    arguments++;
  }

  without_quotes[arg_count] = '\0';
  yylval.cpp_string = new std::string(without_quotes);

  */

  //

  std::string text = std::string(yytext);
  text = text.substr(1, text.size() - 2);

  //std::cout << text;

  yylval.cpp_string = new std::string(text);

  //printf("%s\n", text);

  //


  return WORD;
}

[^ \\\t\n]*(\\[^nt])((\\[^nt])|[^ \\\t\n])* {

  std::string text = std::string(yytext);
  std::size_t esc_finder = text.find('\\');

  while (esc_finder != -1) {
    text = text.substr(0, esc_finder) + text.substr(esc_finder+1, std::string::npos);
    esc_finder = text.find('\\', esc_finder+1);
  }

  yylval.cpp_string = new std::string(text);
  return WORD;

}


[^ \t\n|><][^ \t\n|><]*  {
  /* Assume that file names have only alpha chars */
  yylval.cpp_string = new std::string(yytext);

  //std::cout << yytext;
  return WORD;
}




