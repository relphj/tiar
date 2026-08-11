/* tiar.c - The Game of TIAR */		/* -*-C-*- */

#include <curses.h>
#include <ctype.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/timeb.h>
#include <time.h>
#include <unistd.h>

#define INIT_LINE 6		/* for games.h */
#define INIT_COL 38

#include "games.h"		/* defs and functions */

#define Right '>'
#define Left '<'
#define Mid '='
#define Score_Name 'Ps:<Relph.Games>Tiar.Bin.1'

typedef enum { Weekly, All_Time } Phases;
typedef char Card[4];
typedef int Piles[9][12];
#if 0
typedef struct {
  char Name[MAXLEN];
  int Total;
} Score_Stuff;
typedef Score_Stuff *Score_Array[2][10];
typedef struct {
  int DayofMon;
  Score_Array Scores;
} Score_Rec;
#endif

static int Plays,Wins,High;
static Piles World;
static int B[15];
static Card M[15] = { 0 };
static bool C[8];
static int D[6],Old_D[6];
static char Our_Name[MAXLEN];

#define Max(left,right) (((left) > (right)) ? (left) : (right))
#define PX(e,f) (((e) * 3) + (f))

bool are_same_type(ch1, ch2)
     char ch1, ch2;
{
  if (isalpha(ch1))
    return(isalpha(ch2));
  else if (isdigit(ch1))
    return(isdigit(ch2));
  else
    return(FALSE);
}

#if 0
void Get_Username (Var Our_Name : MSG_Line);
Var
Success,First : Boolean;
Idx : integer;
{
  JSYS(13B;;Idx); /* GJINF */
  JSYS(41B,-1;Our_Name,Idx); /* DIRST */
  Idx = 1;
  While (Our_Name[Idx] != Chr(0)) Do
    Idx = Idx + 1;
  If (Idx > Namlen)
    Idx = Namlen;
  While (Idx <= MAXLEN) Do
    {
      Our_Name[Idx] = SPACE;
      Idx = Idx + 1;
    }
  First = TRUE;
  For Idx = 1 to Namlen Do
    If First
    First = ! First
    Else If (Our_name[Idx]> 'Z') or (Our_name[Idx]< 'A')
    First = TRUE
    Else
    Our_name[Idx] = Chr(Ord(Our_name[Idx]) + 40B);
}

int today();
Var
Tad : Cheater;
{
  JSYS(227B;;Tad.Int);
  Today = Tad.Lh;
}
#endif

void terminate()
{
  erase();
  move(MAX_LINE,0);
  refresh();
  echo();
  noraw();
  endwin();
}

bool initialize()
{
  int e, f, g, i, h;
  time_t t;
  long int r;

  if (initscr() == NULL) {
    fprintf(stderr,"TIAR: Unable to initialize screen.\n");
    return(FALSE);
  }
  noecho();
  raw();
  typeahead(-1);

  t = time(NULL);
  r = ((long int) t) & 07777;
  srandom(r);

  *Our_Name = '\0';
  Plays = 0;
  Wins = 0;
  High = 0;
  for (e = 0; e <= 1; e++)
    for (f = 0; f <= 1; f++)
      for (g = 0; g <= 1; g++)
	if ((e + f + g) != 3) {
	  h = e*4 + f*2 + g + 1;
	  i = h + 7;
	  if (e == 1) { M[h][0] = Mid; M[i][0] = Mid; }
	  else { M[h][0] = Left; M[i][0] = Right; };
	  if (f == 1) { M[h][1] = Mid; M[i][1] = Mid; }
	  else { M[h][1] = Left; M[i][1] = Right; };
	  if (g == 1) { M[h][2] = Mid; M[i][2] = Mid; }
	  else { M[h][2] = Left; M[i][2] = Right; };
	}
  M[0][0] = Mid;
  M[0][1] = Mid;
  M[0][2] = Mid;
  return(TRUE);
}

#if 0
void Grab_Name(Var Our_Name : MSG_Line);
Var
Len : Integer;
{ /* Grab_Name */
  add_line(FALSE);
  addstr("Enter your name please:");
  add_line(FALSE);
  addch('>');
  refresh();
  if Get_Line(Namlen,Our_Name,Len)
    {
      If (Len <= 0)
	Get_Username(Our_Name);
    }
  Else
    Get_Username(Our_Name);
} /* Grab_Name */
#endif

/* * * * * * * * */
/* Help routines */
/* * * * * * * * */

void first_game()
{
  erase();
  mvaddstr(1,20,">> TIAR <<"); ADDLN;
  ADDLN;
  addstr("This game is a minimum information problem.  Part of the"); ADDLN;
  addstr("game is that the user must determine for himself how the"); ADDLN;
  addstr("game operates.  The game does follow a single organized"); ADDLN;
  addstr("set of rules that the user should be able to systematically"); ADDLN;
  addstr("determine."); ADDLN;
  ADDLN;
  addstr("To win the game, the user need only get 400 or more points.");
  ADDLN;
  ADDLN;
  addstr("Though I recommend playing the game with only what you know"); ADDLN;
  addstr("now, you can get help by using the \"H\" command."); ADDLN;
  ADDLN;
  addstr("Good luck...");
  ADDLN;
  more();
}

/* again */
/* true if user wishes to continue */

bool again()
{
  char ch;
  int ox, oy;

  move(MAX_LINE,1);
  addstr("--more--");
  getyx(stdscr,ox,oy);		/* save current pos */

  refresh();
  do {
    ch = getch();
    if (ch == '?' || ch == 'h' || ch == 'H') {
      ADDLN;
      addstr(" <Space> to continue, <del> to quit");
      move(ox,oy);
      refresh();
      ch = '\0';
    }
  }
  while (ch < SPACE);
  return(! (ch == 'n' || ch == 'N' || ch == 'Q' || ch == 'q' || ch == CHDEL));
}

void notes()
{
  erase();
  move(1,18);
  addstr(">> Some TIAR Notes <<"); ADDLN;
  ADDLN;
}

void victim()
{
  erase();
  move(1,20);
  addstr(">> TIAR <<"); ADDLN;
  ADDLN;
  addstr("Aha, we have ourselves a victim, er, challenger."); ADDLN;
  ADDLN;
  addstr("This game is a strategic game. The rules, scoring system and"); ADDLN;
  addstr("penalty system are consistent, however, the game will be"); ADDLN;
  addstr("different each time it is played."); ADDLN;
  ADDLN;
  addstr("I hope that you are able to complete your challenge without"); ADDLN;
  addstr("further assistance and I wish you good luck at your task."); ADDLN;
  addstr("   -- Scott L. Richmond, Creator of TIAR"); ADDLN;
  ADDLN;
  addstr("Addendum:  This version was implemented from the original"); ADDLN;
  addstr("TRS-80 Microsoft Basic version by John M. Relph."); ADDLN;
  (void) again();
}

void hints()
{
  notes();
  ADDLN;
  addstr("Chicken!"); ADDLN;
  ADDLN;
  addstr("Chicken though you may be, you are much wiser than the"); ADDLN;
  addstr("masochists who accepted the challenge."); ADDLN;
  ADDLN;
  addstr("All of the information that is given to you here is useful, but");
  ADDLN;
  addstr("you won't necessarily be told how."); ADDLN;
  ADDLN;
  addstr("TIAR was created by Scott L. Richmond in 1974 using a special"); ADDLN;
  addstr("deck of 150 cards, a pencil, a blank sheet of paper, and the"); ADDLN;
  addstr("rules.  None of the rules have been changed in the computer"); ADDLN;
  addstr("version."); ADDLN;
  if (! again())
    return;

  notes();
  addstr("The pencil and blank sheet of paper have been replaced by the"); ADDLN;
  addstr("computer's automatic scoring system.  The cards have been"); ADDLN;
  addstr("replaced by the computer's memory, so that all you are actually"); ADDLN;
  addstr("missing is the rules.  Ah, gee!"); ADDLN;
  ADDLN;
  addstr("When you run the program you will see on the right side of your"); ADDLN;
  addstr("screen the scoring pad.  There are four types of possible"); ADDLN;
  addstr("scoring and two types of penalties.  Although they are not"); ADDLN;
  addstr("defined for you, they are consistent and if you watch them"); ADDLN;
  addstr("carefully, you should be able to figure out what causes them to"); ADDLN;
  addstr("change and the increments of their various changes."); ADDLN;

  if (! again())
    return;

  notes();
  addstr("Your score will equal the total scores (A, B, C, D) less the"); ADDLN;
  addstr("total penalties (A, B).  The maximum of each score and penalty"); ADDLN;
  addstr("is as follows:"); ADDLN;
  ADDLN;
  addstr("    Score A:  545           Penalty A:  153"); ADDLN;
  addstr("    Score B:  396           Penalty B:  198"); ADDLN;
  addstr("    Score C: 2050"); ADDLN;
  addstr("    Score D:   90           Score:     2562"); ADDLN;
  ADDLN;
  addstr("So you see 400 points isn't really too hard to obtain.  After"); ADDLN;
  addstr("all, there's a theoretical maximum of 2562."); ADDLN;

  if (! again())
    return;

  notes();
  addstr("When you start to play the game, you will note that you have"); ADDLN;
  addstr("five different actions (A, B, C, D, E) that you can operate."); ADDLN;
  ADDLN;
  addstr("Of these five actions, one affects no score; three affect at"); ADDLN;
  addstr("least one score, perhaps two; and one affects at least one"); ADDLN;
  addstr("score, perhaps even two or even three."); ADDLN;
  ADDLN;
  addstr("Of these five actions, one affects no penalty; three affect one"); ADDLN;
  addstr("penalty; and one affects both penalties."); ADDLN;
  ADDLN;
  addstr("The scores and penalties will only be affected by the actions"); ADDLN;
  addstr("if they are used correctly with valid parameters."); ADDLN;

  if (! again())
    return;

  notes();
  addstr("What's a parameter?  Glad you asked that."); ADDLN;
  ADDLN;
  addstr("A parameter is a pile identification title."); ADDLN;
  ADDLN;
  addstr("What's a pile identification title?"); ADDLN;
  ADDLN;
  addstr("A pile identification title is the name of one of the nine"); ADDLN;
  addstr("piles (A, B, C, D, E, F, G, H, I)."); ADDLN;
  ADDLN;
  addstr("By the way, one of the actions requires no parameters; two of"); ADDLN;
  addstr("the actions require one parameter; one of the actions requires"); ADDLN;
  addstr("two parameters; and one of the actions requires three parameters."); ADDLN;

  if (! again())
    return;

  notes();
  addstr("If you give an action which requires more than one parameter an"); ADDLN;
  addstr("initial parameter which is invalid, the game will reject the"); ADDLN;
  addstr("action at that point without asking for additional parameters."); ADDLN;
  ADDLN;
  addstr("By now you should be thoroughly confused.  Don't worry, this"); ADDLN;
  addstr("is normal.  Later you will become both confused and"); ADDLN;
  addstr("frustrated.  This is also normal."); ADDLN;
  ADDLN;
  addstr("My suggestion is that you try running the game once or twice"); ADDLN;
  addstr("and then review these clues and hints.  They will make more"); ADDLN;
  addstr("sense at that point in time."); ADDLN;

  if (! again())
    return;

  notes();
  addstr("And finally, each game is randomly set up.  This means that if"); ADDLN;
  addstr("you play the game more than once, you will not repeat the same"); ADDLN;
  addstr("exact game.  Rather, you will be playing a game with the same"); ADDLN;
  addstr("rules.  In each different game, there is a hidden body of"); ADDLN;
  addstr("knowledge which  is used in the game.  For each different game"); ADDLN;
  addstr("this knowledge will be different, however, for any single game"); ADDLN;
  addstr("this knowledge will be consistent."); ADDLN;
  ADDLN;
  addstr("I wish you good luck and lots of fun."); ADDLN;
  addstr("   -- Scott L. Richmond, Creator of TIAR"); ADDLN;
  ADDLN;
  addstr("Addendum:  This version was implemented from the original"); ADDLN;
  addstr("TRS-80 Microsoft Basic version by John M. Relph."); ADDLN;

  (void) again();
}

void notes_intro()
{
  bool ready;
  char answer;

  notes();
  if (Plays == 1) {
    addstr("So you made it through the first game, eh?"); ADDLN;
    ADDLN;
  }
  addstr("These notes explain some of what the introduction to the"); ADDLN;
  addstr("program didn't.  This doesn't mean, however, that these"); ADDLN;
  addstr("notes will give you the rules to the game."); ADDLN;
  ADDLN;
  addstr("First of all, you, as the user, must understand that you"); ADDLN;
  addstr("are trying to accomplish two different goals.  First, you"); ADDLN;
  addstr("are attempting to decipher how the game operates, and"); ADDLN;
  addstr("second, you are trying to win the game."); ADDLN;
  if (! again())
    return;

  notes();
  addstr("When the game is described as a minimum information"); ADDLN;
  addstr("problem, this means that the user is given the minimum"); ADDLN;
  addstr("information necessary to solve the problem."); ADDLN;
  ADDLN;
  addstr("Do you think you must receive more clues and hints before"); ADDLN;
  addstr("you are able to accept this intellectual challenge [Y/N]? ");
  refresh();

  while (answer = getch()) {
    if (islower(answer))
      answer = toupper(answer);
    if (answer == 'Y' || answer == 'N' || answer == SPACE)
      break;
  }

  if (answer == 'Y')
    hints();
  else
    victim();
}

bool get_pile_id(what,x,y)
     int what;
     int *x, *y;
{
  char ch;
  int val;
  bool done = FALSE;

  while (1) {
    add_line(FALSE);
    switch (what) {
    case 1:
      addstr("Which pile (A-I)? ");
      break;
    case 2:
      addstr("Which other pile (A-I)? ");
      break;
    case 3:
      addstr("Which final pile (A-I)? ");
      break;
    }
    refresh();
    do {
      ch = getch();
      if (ch == CHESC)
	return(FALSE);
      else if (ch == '?') {
	add_line(TRUE);
	addstr("Pile ID, \"A\" - \"I\"");
	add_line(TRUE);
	addstr("   or <ESC> to abort");
	done = TRUE;
      }
      else if (islower(ch))
	ch = toupper(ch);
      if (ch >= 'A' && ch <= 'I') {
	addch(ch);
	refresh();
	val = ch - 'A';
	*x = val / 3;
	*y = val % 3;
	return(TRUE);
      }
    }
    while (! done);
    if (ch == '?')
      done = FALSE;
  }
}

bool calculate_weirdness(e,f,e1,f1,e2,f2,k)
     int e,f,e1,f1,e2,f2;
     int *k;
{
  *k = 0;
  if ((e == e1) && (e1 == e2))
    *k = e;
  else if ((f == f1) && (f1 == f2))
    *k = f + 3;
  else if ((e == f) && (e1 == f1) && (e2 == f2))
    *k = 6;
  else if (((e == f) && (e == 1) && (e1 == f2) && (e2 == f1) &&
	    (((e1 == 0) && (e2 == 2)) || ((e1 == 2) && (e2 == 0)))) ||
	   ((e2 == f2) && (e2 == 1) && (e == f1) && (e1 == f) &&
	    (((e == 0) && (e1 == 2)) || ((e == 2) && (e1 == 0)))) ||
	   ((e1 == f1) && (e1 == 1) && (e == f2) && (e2 == f) &&
	    (((e == 0) && (e2 == 2)) || ((e == 2) && (e2 == 0)))))
    *k = 7;
  else
    return(FALSE);
  return(TRUE);
}

bool game_complete()
{
  int e, f, g, e1, e2, f1, f2, k;
  bool j;

  add_line(FALSE);
  add_line(FALSE);
  addstr("    >> Processing <<");
  mvaddch(MAX_LINE,COLS - 1,SPACE);
  move(0,0);
  refresh();
  add_line(FALSE);

  sleep(1);			/* sleep 1 sec */

  for (e = 0; e <= 2; e++)
    for (f = 0; f <= 2; f++)
      if (World[PX(e,f)][0] != 0)
	if (World[PX(e,f)][World[PX(e,f)][0]] == 0)
	  return(FALSE);
	else {
	  g = World[PX(e,f)][World[PX(e,f)][0]] + 7;
	  if (g > 14)
	    g -= 14;
	  if (B[g] > 0)
	    return(FALSE);
	}

  sleep(1);
  for (e = 0; e <= 2; e++)
    for (f = 0; f <= 2; f++)
      if (World[PX(e,f)][0] != 0)
	for (e1 = 0; e1 <= 2; e1++)
	  for (f1 = 0; f1 <= 2; f1++)
	    if (((e != e1) || (f != f1)) &&
		(abs(e - e1) < 2) && (abs(f - f1) < 2) &&
		(World[PX(e1,f1)][0] != 0)) {
	      g = World[PX(e,f)][World[PX(e,f)][0]] + 7;
	      if (g > 14)
		g -= 14;
	      if (g == World[PX(e1,f1)][World[PX(e1,f1)][0]])
		return(FALSE);
	    }

  sleep(1);
  for (e = 0; e <= 2; e++)
    for (f = 0; f <= 2; f++)
      for (e1 = 0; e1 <= 2; e1++)
	for (f1 = 0; f1 <= 2; f1++)
	  if (((e1 != e) || (f1 != f)) &&
	      (World[PX(e,f)][World[PX(e,f)][0]] == World[PX(e1,f1)][World[PX(e1,f1)][0]]))
	    for (e2 = 0; e2 <= 2; e2++)
	      for (f2 = 0; f2 <= 2; f2++)
		if (((e != e2) || (f != f2)) && ((e1 != e2) || (f1 != f2)) &&
		    (World[PX(e,f)][World[PX(e,f)][0]] == World[PX(e2,f2)][World[PX(e2,f2)][0]])) {
		  if (calculate_weirdness(e,f,e1,f1,e2,f2,&k) &&
		      ((World[PX(e,f)][World[PX(e,f)][0]] != 0) || (! C[k])))
		    return(FALSE);
		}

#if 0
  if (done)
    clr_lines();
#endif
  return(TRUE);
}

void update_scores()
{
  int total;

  move(1,47);
  printw("%5d",D[0]*5);
  move(2,47);
  printw("%5d",D[1]*4);
  move(3,47);
  printw("%5d",D[2]*50);
  move(4,47);
  printw("%5d",D[3]*10);
  move(1,66);
  printw("%3d",D[4]*3);
  move(2,66);
  printw("%3d",D[5]*2);
  total = (D[0]*5) + (D[1]*4) + (D[2]*50) + (D[3]*10) - (D[4]*3) - (D[5]*2);
  move(4,64);
  printw("%5d",total);
}

void update_pile(e,f)
     int e,f;
{
  move(e * 4 + 3, 10 * f + 4);
  if (World[PX(e,f)][0] > 0)
    addstr((char *) M[World[PX(e,f)][World[PX(e,f)][0]]]);
  else
    addstr("   ");
}

void stats()
{
  move(20,2);
  printw("You have won %d out of %d games",Wins,Plays);
  move(21,2);
  printw("Your highest is %d",High);
}

void build_screen()
{
  int i,j;

  erase();
  for (i = 1; i <= 13; i++) {
    if ((i % 4) == 1)
      addstr("+---------+---------+---------+");
    else
      addstr("|         |         |         |");
    ADDLN;
  }
  for (i = 0; i <= 2; i++)
    for (j = 0; j <= 2; j++) {
      mvaddch(i*4+1,j*10+4,'<');
      addch(65+j+i*3);
      addch('>');
      update_pile(i,j);
    }
  mvaddstr(1,39,"Score A:");
  mvaddstr(2,39,"Score B:");
  mvaddstr(3,39,"Score C:");
  mvaddstr(4,39,"Score D:");
  mvaddstr(1,54,"Penalty A:");
  mvaddstr(2,54,"Penalty B:");
  mvaddstr(4,54,"Total:");
  update_scores();
  mvaddstr(14,10,">> TIAR <<");
  if (Plays > 0) {
    stats();
    if (*Our_Name) {
      mvaddstr(17,1,"Name: ");
      addstr(Our_Name);
      clrtoeol();
    }
  }
  clr_lines();
}

void init_game()
{
  int e, f, g, i, h;

  for (e = 0; e <= 5; e++) {
    D[e] = 0;
    Old_D[e] = -1;
  }
  for (e = 0; e <= 7; e++)
    C[e] = FALSE;
  for (e = 0; e <= 14; e++)
    B[e] = 10;
  for (e = 0; e <= 2; e++)
    for (f = 0; f <= 2; f++) {
      for (g = 1; g <= 11; g++) {
	h = random() % 15;
	while (B[h] == 0)
	  h = (h + 1) % 15;
	B[h]--;
	World[PX(e,f)][g] = h;
      }
      World[PX(e,f)][0] = 11;
    }
  D[0] = B[0];
  B[0] = 0;
  D[4] = 51 - D[0];
  D[5] = 99;
  build_screen();
}

void change_pile(e,f)
     int e,f;
{
  World[PX(e,f)][0]--;
  if (World[PX(e,f)][0] == 0)
    D[3]++;
  update_pile(e,f);
}

void do_A()
{
  int e, f;

  if (get_pile_id(1,&e,&f)) {
    if (World[PX(e,f)][0] != 0)
      if (World[PX(e,f)][World[PX(e,f)][0]] == 0) {
	change_pile(e,f);
	D[0]++;
	D[5]--;
	update_scores();
      }
  }
  clr_lines();
}

void do_B()
{
  int e,f,g;

  if (get_pile_id(1,&e,&f)) {
    if ((World[PX(e,f)][0] != 0) && (World[PX(e,f)][World[PX(e,f)][0]] != 0)) {
      g = World[PX(e,f)][World[PX(e,f)][0]] + 7;
      if (g > 14)
	g -= 14;
      if (B[g] != 0) {
	B[g]--;
	D[4]--;
	D[1]++;
	D[5]--;
	change_pile(e,f);
	update_scores();
      }
    }
  }
  clr_lines();
}

void do_C()
{
  int e, f, e1, f1, g;

  if (get_pile_id(1,&e,&f)) {
    if ((World[PX(e,f)][0] != 0) && (World[PX(e,f)][World[PX(e,f)][0]] != 0)) {
      if (get_pile_id(2,&e1,&f1)) {
	if ((World[PX(e1,f1)][0] != 0) && (World[PX(e1,f1)][World[PX(e1,f1)][0]] != 0) &&
	    ((e1 != e) || (f1 != f)) &&
	    (abs(e - e1) < 2) && (abs(f - f1) < 2)) {
	  g = World[PX(e,f)][World[PX(e,f)][0]] + 7;
	  if (g > 14)
	    g -= 14;
	  if (g == World[PX(e1,f1)][World[PX(e1,f1)][0]]) {
	    D[5] -= 2;
	    D[1]++;
	    change_pile(e,f);
	    change_pile(e1,f1);
	    update_scores();
	  }
	}
      }
    }
  }
  clr_lines();
}

void do_D()
{
  int e, f, e1, f1, e2, f2, k, h, g;
  bool J;

  if (get_pile_id(1,&e,&f)) {
    if (World[PX(e,f)][0] == 0) {
      if (get_pile_id(2,&e1,&f1)) {
	if ((World[PX(e1,f1)][0] == 0) && ((e1 != e) || (f1 != f))) {
	  if (get_pile_id(3,&e2,&f2)) {
	    if ((World[PX(e2,f2)][0] == 0) &&
		((e1 != e2) || (f1 != f2)) &&
		((e != e2) || (f != f2))) {
	      if (calculate_weirdness(e,f,e1,f1,e2,f2,&k) && (! C[k])) {
		C[k] = TRUE;
		D[2]++;
		for (g = 0; g <= 2; g++) {
		  if (k < 3)
		    move(4 * e + 3, g * 10 + 4);
		  else if ((k > 2) && (k < 6))
		    move(4 * g + 3, f * 10 + 5);
		  else if (k == 6)
		    move(4 * g + 3, g * 10 + 6);
		  else
		    move(4 * g + 3, 26 - g * 10);
		  addch(STAR);
		}
		update_scores();
	      }
	    }
	  }
	}
      }
    }
    else {			/*  World[E,F,0] != 0  */
      if (get_pile_id(2,&e1,&f1)) {
	if ((World[PX(e,f)][World[PX(e,f)][0]] == World[PX(e1,f1)][World[PX(e1,f1)][0]]) &&
	    (World[PX(e,f)][World[PX(e,f)][0]] != 0) &&
	    ((e1 != e) || (f1 != f))) {
	  if (get_pile_id(3,&e2,&f2)) {
	    if (((e1 != e2) || (f1 != f2)) && ((e2 != e) || (f2 != f)) &&
		(World[PX(e,f)][World[PX(e,f)][0]] == World[PX(e2,f2)][World[PX(e2,f2)][0]])) {
	      if (calculate_weirdness(e,f,e1,f1,e2,f2,&k)) {
		D[0] += 3;
		D[5] -= 3;
		D[2]++;
		change_pile(e,f);
		change_pile(e1,f1);
		change_pile(e2,f2);
		update_scores();
	      }
	    }
	  }
	}
      }
    }
  }
  clr_lines();
}

#if 0
void fill_score(Var The_Scores : Score_Rec);
Var
I : Phases;
J, Num : Integer;
Nam : MSG_Line;
{
  Reset(Score_File,Score_Name,0,0,0,10B);
  If ! EOF(Score_file)
    The_Scores = Score_File^
    Else
    {
      For I = Weekly To All_Time Do
	For J = 1 To 10 Do
	{
	  The_scores.Scores[I,J].Total = -1000;
	  The_scores.Scores[I,J].Name[1] = Chr(0);
	}
      The_Scores.DayofMon = 0;
    }
}

void Store_Score(Phase : Phases;
		 Var The_Scores : Score_Rec;
		 Score : Integer;
		 Var Changed : Boolean);
Var
Day, J, I : Integer;
Done : Boolean;
{
  Day = Today;
  With The_Scores Do
    {
      If (Day >= DayofMon)
	{
	  DayofMon = Day + 7;
	  For I = 1 To 10 Do
	    {
	      Scores[Weekly,I].Total = -1000;
	      Scores[Weekly,i].Name[1] = Chr(0);
	    }
	  Changed = TRUE;
	}
      If (Score > Scores[Phase,10].Total)
	{
	  I = 9;
	  Done = FALSE;
	  While ! Done do
	    If (I == 0)
	      Done = TRUE
	      Else If (Score > Scores[Phase,I].Total)
	    {
	      Scores[Phase,I+1] = Scores[Phase,I];
	      I = I - 1;
	    }
	  Else
	    Done = TRUE;
	  I = I + 1;
	  Scores[Phase,I].Total = Score;
	  Scores[Phase,I].Name = Our_Name;
	  Changed = TRUE;
	}
    }
}

void Empty_Scores(The_Scores : Score_Rec);
Var
I : Phases;
J : Integer;
{
  Rewrite(Score_File,Score_Name,0,0,0,10B);
  If (Erstat(Score_File) == 0)
    {
      Score_File^ = The_Scores;
      Put(Score_File);
      Close(Score_File);
    }
}

void Disp_Scores(Scores : Score_Array);
Var
I,J : Integer;
{
  Clr_Lines;
  Add_Line(FALSE);
  addstr("Weekly Scores:");
  For J = 1 to 10 do
    If (Scores[Weekly,J].Total != -1000)
    {
      Add_Line(FALSE);
      For I = 1 to 25 Do
	Vbout(Scores[Weekly,J].Name[I]);
      Vnout(Scores[Weekly,J].Total,5);
    }
  Add_Line(FALSE);
  More;
  Clr_Lines;
  Add_Line(FALSE);
  addstr("All-Time Scores:");
  For J = 1 to 10 do
    If (Scores[All_Time,J].Total != -1000)
    {
      Add_Line(FALSE);
      For I = 1 to 25 Do
	Vbout(Scores[All_time,J].Name[I]);
      Vnout(Scores[All_time,J].Total,5);
    }
}

void Savescore (Score : Integer; Quit : Boolean);
Var
Phase : Phases;
Scores : Score_Rec;
Cool : Boolean;
{
  Fill_Score(Scores);
  Cool = FALSE;
  If ! Quit
    {
      If (Our_Name == Empty)
	Grab_Name(Our_Name)
	Else
	More;
      For Phase = Weekly to All_Time do
	Store_Score(Phase,Scores,Score,Cool);
    }
  Disp_Scores(Scores.Scores);
  If Cool
    Empty_Scores(Scores);
}
#endif

void show_score()
{
  int diff,score;

  add_line(TRUE);
  addstr("The game has been completed.");
  add_line(TRUE);
  addstr("There is no further possible");
  add_line(TRUE);
  addstr("  change in your score.");
  score = (D[0]*5) + (D[1]*4) + (D[2]*50) + (D[3]*10) - (D[4]*3) - (D[5]*2);
  add_line(TRUE);
  printw("Your score is %d.",score);
  add_line(TRUE);
  Plays++;
  High = Max(High,score);
  printw("You have %s by %d points.", (score < 400) ? "lost" : "won",
	 abs(score - 400));
  if (score >= 400)
    Wins++;
  getyx(stdscr,SX,SY);
  stats();
  move(SX,SY);
#if 0
  savescore(score,quit);
#endif
}

bool playing()
{
  bool quit,game_in_progress,done,helpme;
  char ch;
  
  if (Plays == 1)
    notes_intro();
  init_game();
  game_in_progress = TRUE;
  quit = FALSE;
  if (Plays == 0) {
    add_line(FALSE);
    addstr("Welcome to TIAR!");
  }
  helpme = FALSE;
  while (game_in_progress) {
    add_line(FALSE);
    addstr("Which action (A/B/C/D/E)? ");
    refresh();
    while (1) {
      ch = getch();
      if (islower(ch))
	ch = toupper(ch);
      if (ch == '?' || ch == 'h' || ch == 'H')
	break;
#if 0
      else if (ch == CHCTZ) {	/* C-Z */
	tstp();
	break;
      }
#endif
      else if (ch == CHFFD) {	/* C-L */
	wrefresh(curscr);
	continue;
      }
      else if (ch == CHCTC ||	/* C-C */
	       ch == 'q' ||
	       ch == 'Q') {
	add_line(FALSE);
	addstr("Quit? ");
	refresh();
	ch = getch();
	if (ch == 'y' || ch == 'Y') {
	  game_in_progress = FALSE;
	  return(FALSE);
	}
	else {
	  addstr("No");
	  refresh();
	  ch = CHCTC;
	  break;
	}
      }
      else if (ch >= 'A' && ch <= 'E')
	break;
    }

    if (ch > SPACE) {
      addch(ch);
      refresh();
      switch (ch) {
      case 'A':
	do_A();
	break;
      case 'B':
	do_B();
	break;
      case 'C':
	do_C();
	break;
      case 'D':
	do_D();
	break;
      case 'E':
	game_in_progress = (! game_complete());
	flushinp();
	break;
      case '?':
      case 'h':
      case 'H':
	if (helpme) {
	  notes_intro();
	  build_screen();
	  helpme = FALSE;
	}
	else {
	  add_line(TRUE);
	  addstr("  Pick an action, \"A\" - \"E\"");
	  add_line(TRUE);
	  addstr("  \"?\" for help");
	  add_line(TRUE);
	  addstr("  C-C to quit");
	  add_line(TRUE);
	  addstr("  C-L to refresh");
	  helpme = TRUE;
	}
	continue;
      default:
	break;
      }
      helpme = FALSE;
    }
  }
  show_score();
  add_line(FALSE);
  addstr("Another game? ");
  refresh();
  ch = getch();
  if (ch == 'n' || ch == 'N')
    quit = TRUE;

  return(! quit);
}

void play()
{
  first_game();
  while (playing())
    ;
}

void main()
{
  if (initialize()) {
    play();
    terminate();
  }
}
