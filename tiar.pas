(* $D-   -*-PASCAL-*- *)
(* <RELPH.GAMES>TIAR.PAS.15,  1-Jul-86 12:39:37, Edit by RELPH *)

Program Tiar;

Const
  X_min = 0;
  Y_min = 0;
  X_max = 25;
  Y_max = 80;
  Scr_x_min = 1;
  Scr_x_max = 24;
  Scr_y_min = 1;
  Scr_y_max = 79;
  Space = ' ';
  Maxlen = 40;
  Empty = '                                        ';
  Init_Line = 7;
  Right = '>';
  Left = '<';
  Mid = '=';
  Star = '*';
  NamLen = 20;
  Score_Name = 'Ps:<Relph.Games>Tiar.Bin.1';

Type
  MSG_Line = Packed Array[1..Maxlen] of Char;
  Screens = Array[X_min..X_max,Y_min..Y_max] of Char;
  Screen_Rec = Record
		 Cx,Cy,	(* current X,Y *)
		 Vx,Vy : Integer;
		 Last, This : Screens;
		 Lines : Array[Scr_x_min..Scr_x_max] of Boolean
	       End;
  Phases = (Weekly, All_Time);
  Coord = 0..2;
  Card = Packed Array[1..3] of Char;
  Piles = Array [Coord,Coord,0..11] of Integer;
  Score_Stuff = Record
		  Name : MSG_Line;
		  Total	: Integer
		End;
  Score_Array = Array[Phases,1..10] of Score_Stuff;
  Score_Rec = Record
		DayofMon : Integer;
		Scores : Score_Array
	      End;
  Cheater = Packed Record
		     Case Boolean of
		       True : (Int : Integer);
		       False : (Lh : 0..777777B;
				Rh : 0..777777B);
		     End;
(*		   End; *)

Var
  Screen : Screen_Rec;
  Setup : Boolean;
  Rnds : Array[1..55] of Real;
  Rnd_j,Rnd_k,Cur_Line,Plays,Wins,High,Seed : Integer;
  World : Piles;
  B : Array[0..14] of Integer;
  M : Array[0..14] of Card;
  C : Array[0..7] of Boolean;
  D,
  Old_D : Array[0..5] of Integer;
  Our_Name : MSG_Line;
  Score_File : File Of Score_Rec;

Initprocedure;
Begin
  Setup := False
End;

	  (* * * * * * * * * * * * * * * *)
	  (* External Macro subroutines	 *)
	  (* * * * * * * * * * * * * * * *)

Procedure Trmchk; Extern;
Procedure Trmini; Extern;
Procedure Interrupts; Extern;
Procedure Deinterrupts; Extern;
Procedure Settty; Extern;
Procedure Restty; Extern;
Procedure Save_Self (Name : String); Extern;
Procedure DCA (X,Y : Integer); Extern;
Procedure CLL; Extern;
Procedure CLS; Extern;
Procedure Bksp; Extern;
Procedure Dnsp; Extern;
Function Comand : Char; Extern;

Procedure Psidefine (Chan,Level : Integer; Procedure Proc); Extern;
Procedure Psienable (Chan : Integer); Extern;
Procedure Psidisable (Chan : Integer); Extern;
Procedure Entercrit; Extern;
Procedure Leavecrit; Extern;
Procedure Setran (I : Integer); Extern Fortran;
Function Erstat (Var F : File) : Integer; Extern;

Procedure VSout (S : String); Extern;

	  (* * * * * * * * * * * * * * * * * * * * * * * * * *)
	  (* Random small procs to help us get the job done  *)
	  (* * * * * * * * * * * * * * * * * * * * * * * * * *)

Function Rnd (Limit : Integer) : Integer;
Var
  Sum : real;
Begin (* Rnd *)
  Sum := Rnds[Rnd_j] + Rnds[Rnd_k];
  If Sum > 1.0 Then
    Sum := Sum - 1.0;
  Rnds[Rnd_k] := Sum;
  Rnd_j := Rnd_j - 1;
  If Rnd_j = 0 Then
    Rnd_j := 55;
  Rnd_k := Rnd_k - 1;
  If Rnd_k = 0 Then
    Rnd_k := 55;
  Rnd := Trunc(Sum * Limit) + 1
End; (* Rnd *)

Function Sign (Foo : Real) : Integer;
Begin
  If (Foo = 0) Then
    Sign := 0
  Else If (Foo < 0) Then
    Sign := -1
  Else
    Sign := 1
End;

Procedure Sleep (Sleep_Time : Integer);
Begin
  Jsys(167B;Sleep_Time*100); (* sleep 1/10 sec *)
End;

	  (* * * * * * * * * * * * *)
	  (* The display routines  *)
	  (* * * * * * * * * * * * *)

Procedure Refresh;
Var
  X,Y,Wid : Integer;

  Procedure Get_There;
  Var
    I,J : Integer;
  Begin (* Get_There *)
    If (X < Screen.Cx) Then
      DCA(Y,X)
    Else If (X > Screen.Cx + 1) Then
      DCA(Y,X)
    Else
      Begin
	I := Y - Screen.Cy;
	If (I < -4) Then
	  DCA(Y,X)
	Else If (I > 4) Then
	  DCA(Y,X)
	Else
	  Begin
	    If (X = Screen.Cx + 1) Then
	      DNSP;
	    If (I < 0) Then
	      For J := I to -1 Do
		BKSP
	    Else If (I > 0) Then
	      For J := Screen.Cy to Y - 1 Do
		JSYS(74B;Screen.This[X,J]) (* PBOUT *)
	  End
      End;
    Screen.Cx := X;
    Screen.Cy := Y + 1
  End; (* Get_There *)

Begin (* Refresh *)
  Entercrit;
  Screen.Cx := -100;
  Screen.Cy := -100; (* force Get_there to use DCA *)
  For X := Scr_x_min to Scr_x_max Do
    Begin
      If Screen.Lines[X] Then
	Begin
	  Screen.This[X,Y_min] := Chr(0);
	  Wid := Scr_y_max;
	  While (Screen.This[X,Wid] = Space) Do
	    Wid := Wid - 1;
	  Screen.This[X,Y_min] := Space;
	  Y := Scr_y_min;
	  While (Y <= Scr_y_max) Do
	    Begin
	      If (Screen.This[X,Y] <> Screen.Last[X,Y]) Then
		Begin
		  If (Y > Wid) Then
		    Begin
		      Y := Wid + 1;
		      Get_There;
		      Screen.Cy := Screen.Cy - 1; (* because we didn''t Write a char *)
		      CLL;
		      Screen.Last[X,Y] := Screen.This[X,Y];
		      While (Y < Scr_y_max) Do
			Begin
			  Y := Y + 1;
			  If (Screen.This[X,Y] <> Screen.Last[X,Y]) Then
			    Screen.Last[X,Y] := Screen.This[X,Y];
			End
		    End
		  Else
		    Begin
		      Get_There;
		      JSYS(74B;Screen.This[X,Y]); (* PBOUT *)
		      Screen.Last[X,Y] := Screen.This[X,Y]
		    End;
		End;
	      Y := Y + 1
	    End;
	  Screen.Lines[X] := False
	End
    End;
  X := Screen.Vx;
  Y := Screen.Vy;
  Get_There;
  Leavecrit
End; (* Refresh *)

Procedure Vdca (X, Y : Integer);
Begin (* Vdca *)
  Screen.Vx := X;
  Screen.Vy := Y
End; (* Vdca *)

Procedure Vpos (Var X, Y : Integer);
Begin (* Vpos *)
  X := Screen.Vx;
  Y := Screen.Vy
End; (* Vpos *)

Procedure Vinit;
Var
  I, J : Integer;
Begin (* Vinit *)
  For I := X_min to X_max Do
    For J := Y_min to Y_max Do
      Begin
	Screen.This[I,J] := Space;
	Screen.Last[I,J] := Space
      End;
  For I := Scr_X_Min to Scr_x_Max Do
    Screen.Lines[I] := False;
  Screen.Vx := 1;
  Screen.Vy := 1;
  Screen.Cx := 1;
  Screen.Cy := 1;
  Cur_Line := Init_Line;
  Cls
End; (* Vinit *)

Procedure Vexit;
Begin (* Vexit *)
  DCA(1,24);
  CLL;
End; (* Vexit *)

Procedure Vfix;
Var
  I, J : Integer;
Begin (* Vfix *)
  For I := X_min to X_max Do
    For J := Y_min to Y_max Do
      Screen.Last[I,J] := Space;
  For I := Scr_X_Min to Scr_x_Max Do
    Screen.Lines[I] := True;
  Screen.Cx := 1;
  Screen.Cy := 1;
  Cls
End; (* Vfix *)

Procedure VBout (Ch : Char);
Begin (* VBout *)
  If (Screen.Vy <= Scr_y_max) Then
    Begin
      Screen.Lines[Screen.Vx] := True;
      Screen.This[Screen.Vx,Screen.Vy] := Ch;
      Screen.Vy := Screen.Vy + 1
    End
End; (* VBout *)

Procedure VNout (N, Cols : Integer);
Var
  Num : Msg_line;
  More : Boolean;
  I : Integer;
Begin (* VNout *)
  Screen.Lines[Screen.Vx] := True;
  JSYS(224B,1;-1:Num,N,100000B+Cols:12B); (* NOUT *)
  More := True;
  I := 1;
  If (Cols = 0) Then
    Begin
      While More Do
	If (Screen.Vy > Scr_y_max) Then
	  More := False
	Else If (Num[I] = Chr(0)) Then
	  More := False
	Else
	  Begin
	    Screen.This[Screen.Vx,Screen.Vy] := Num[I];
	    I := I + 1;
	    Screen.Vy := Screen.Vy + 1
	  End
    End
  Else
    Begin
      While More Do
	If (Screen.Vy > Scr_y_max) Then
	  More := False
	Else If (I > Cols) Then
	  More := False
	Else
	  Begin
	    Screen.This[Screen.Vx,Screen.Vy] := Num[I];
	    I := I + 1;
	    Screen.Vy := Screen.Vy + 1
	  End
    End
End; (* VNout *)

Procedure Vflout (N : Real);
Var
  Num : Msg_line;
  More : Boolean;
  I : Integer;
Begin (* Vflout *)
  Screen.Lines[Screen.Vx] := True;
  JSYS(233B,1;Num,N,240002B:1B); (* FLOUT *)
  More := True;
  I := 1;
  While More Do
    If (Screen.Vy > Scr_y_max) Then
      More := False
    Else If (Num[I] = Chr(0)) Then
      More := False
    Else
      Begin
	Screen.This[Screen.Vx,Screen.Vy] := Num[I];
	I := I + 1;
	Screen.Vy := Screen.Vy + 1
      End
End; (* Vflout *)

Procedure Vcls;
Var
  I,J : Integer;
Begin (* Vcls *)
  For I := Scr_x_min to Scr_x_max Do
    Begin
      Screen.Lines[I] := True;
      For J := Scr_y_min to Scr_y_max Do
	Screen.This[I,J] := Space
    End;
  Screen.Vx := 1;
  Screen.Vy := 1
End; (* Vcls *)

Procedure Vcll;
Var
  J : Integer;
Begin (* Vcll *)
  Screen.Lines[Screen.Vx] := True;
  For J := Screen.Vy to Scr_y_max Do
    Screen.This[Screen.Vx,J] := Space
End; (* Vcll *)

Procedure Vtime;
Var
  T : Msg_line;
  I : Integer;
Begin (* Vtime *)
  JSYS(220B;T,-1,400300B:0);
  For I := 1 to 5 Do
    Vbout(T[I])
End; (* Vtime *)

Procedure More;
Begin (* More *)
  Vsout(' --more--');
  Refresh;
  Repeat
  Until (Comand in [Space,Chr(15B)])
End; (* More *)

Procedure Add_Line (Ask_More : Boolean);
Begin (* Add_Line *)
  If (Cur_Line = Scr_x_max) Then
    Begin
      If Ask_more Then
	More
      Else
	Refresh;
      Vdca(Cur_Line,38);
      Vbout(Space);
      Cur_Line := Init_Line
    End
  Else
    Begin
      Vdca(Cur_Line,38);
      Vbout(Space)
    End;
  Cur_Line := Cur_Line + 1;
  Vdca(Cur_Line,38);
  Vbout('*');
  Vcll;
  If (Cur_Line <> Scr_x_max) Then
    Begin
      Vdca(Cur_Line+1,38);
      Vcll;
      Vdca(Cur_Line,39)
    End;
End; (* Add_Line *)

Procedure Clr_Lines;
Var
  I : Integer;
Begin (* Clr_Lines *)
  For I := Init_Line+1 to Scr_x_max Do
    Begin
      Vdca(I,38);
      Vcll;
    End;
  Cur_Line := Init_Line
End; (* Clr_Lines *)

Function Get_Line (Len : Integer; Var MSG : MSG_line;
		   Var Index : Integer) : Boolean;
Var
  I, Och : Integer;
  Dummy, Ch : Char;
  More,Ok : Boolean;

  Function Are_same_type (Ch1, Ch2 : Char) : Boolean;
  Begin (* Are_same_type *)
  If (Ch1 In ['a'..'z','A'..'Z']) Then
    Are_same_type := (Ch2 In ['a'..'z','A'..'Z'])
  Else If (Ch1 In ['0'..'9']) Then
    Are_same_type := (Ch2 In ['0'..'9'])
  Else
    Are_same_type := False
  End; (* Are_same_Type *)

Begin (* Get_Line *)
  Ok := True;
  Index := 0;
  Repeat
    Ch := Comand;
    Och := Ord(Ch);
    If (OCh = 177B) Then (* DEL *)
      Begin
	Ch := Chr(10B); (* BS *)
	Och := 10B
      End;
    If (Ch >= Space) Then
      If (Index < Len) Then
	Begin
	  Index := Index + 1;
	  MSG[Index] := Ch;
	  Write(tty,Ch)
	End
      Else Write(tty,Chr(7B))
    Else
      Case OCh of
	4, (* ^D,^R *)
	18 : Begin
	       For I := 1 to Index do
		 BKSP;
	       For I := 1 to Index do
		 Write(tty,MSG[I])
	     End;
	8 : If (Index > 0) Then	(* BS *)
	      Begin
		BKSP;
		Write(tty,Space);
		BKSP;
		Index := Index - 1
	      End;
	21 : Begin
	       For I := 1 to Index Do
		 Begin
		   BKSP;
		   Write(tty,Space);
		   BKSP
		 End;
	       Index := 0
	     End;
	23 : Begin (* ^W *)
	       More := (Index <> 0);
	       If More Then
		 Dummy := MSG[Index];
	       While More do
		 Begin
		   Index := Index - 1;
		   BKSP;
		   Write(tty,Space);
		   BKSP;
		   More := (Index <> 0);
		   If More Then
		     If (Dummy = Space) Then
		       Dummy := MSG[Index]
		     Else
		       More := Are_Same_Type(Dummy,MSG[Index])
		 End
	     End;
	27 : Begin
	       Index := 0;
	       Ok := False
	     End;
	Others : ;
      End
  Until (OCh = 15B) or (Ch = Chr(33B));
  Get_Line := Ok;
  More := True;
  While More Do
    If Index = 0 Then
      More := False
    Else If (MSG[Index] <> Space) Then
      More := False
    Else
      Index := Index - 1;
  For I := Index + 1 to Len do
    MSG[I] := Space;
  More := True;
  I := 1;
  While More Do
    If (Screen.Vy > Scr_y_max) Then
      More := False
    Else If (I > Index) Then
      More := False
    Else
      Begin
	Screen.This[Screen.Vx,Screen.Vy] := Msg[I];
	Screen.Last[Screen.Vx,Screen.Vy] := Msg[I];
	I := I + 1;
	Screen.Vy := Screen.Vy + 1
      End
End; (* Get_Line *)

Procedure Vnl;
Begin (* Vnl *)
  Vdca(Screen.Vx+1,Scr_y_min)
End; (* Vnl *)

Procedure Get_Username (Var Our_Name : MSG_Line);
Var
  Success,First : Boolean;
  Idx : integer;
Begin
  JSYS(13B;;Idx); (* GJINF *)
  JSYS(41B,-1;Our_Name,Idx); (* DIRST *)
  Idx := 1;
  While (Our_Name[Idx] <> Chr(0)) Do
    Idx := Idx + 1;
  If (Idx > Namlen) Then
    Idx := Namlen;
  While (Idx <= Maxlen) Do
    Begin
      Our_Name[Idx] := Space;
      Idx := Idx + 1
    End;
  First := True;
  For Idx := 1 to Namlen Do
    If First Then
      First := Not First
    Else If (Our_name[Idx]> 'Z') or (Our_name[Idx]< 'A') Then
      First := True
    Else
      Our_name[Idx] := Chr(Ord(Our_name[Idx]) + 40B)
End;

Function Today : Integer;
Var
  Tad : Cheater;
Begin
  JSYS(227B;;Tad.Int);
  Today := Tad.Lh
End;

Procedure Terminate;
Begin (* Terminate *)
  Refresh;
  Vexit;
  Restty;
  Deinterrupts
End; (* Terminate *)

Procedure Abort;
Var
  Sx,Sy : Integer;
Begin (* Abort *)
  Vpos(Sx,Sy);
  Terminate;
  JSYS(170B);
  Trmchk;
  Settty;
  Interrupts;
  Vdca(Sx,Sy);
  Vfix;
  Psidefine(0,1,Abort);
  JSYS(137B;3B:0B); (* ATI *)
  Psienable(0);
  Refresh
End; (* Abort *)

Procedure Initialize;
Var
  E, F, G, I, H : Integer;
Begin
  Trmchk;
  Settty;
  Interrupts;
  JSYS(14B;;Seed); (* TIME *)
  Seed := Seed mod 199021;
  Setran(Seed);
  For I := 1 to 55 Do
    Rnds[I] := Random(0);
  Rnd_J := 55;
  Rnd_K := 24;
  Our_Name := Empty;
  Vinit;
  Psidefine(0,1,Abort);
  JSYS(137B;3B:0B); (* ATI *)
  Psienable(0);
  Plays := 0;
  Wins := 0;
  High := 0;
  For E := 0 to 1 do
    For F := 0 to 1 do
      For G := 0 to 1 do
	If ((E + F + G) <> 3) Then
	  Begin
	    H := E*4 + F*2 + G + 1;
	    I := H + 7;
	    If (E = 1) Then
	      Begin M[H,1] := Mid; M[I,1] := Mid End
	    Else
	      Begin M[H,1] := Left; M[I,1] := Right End;
	    If (F = 1) Then
	      Begin M[H,2] := Mid; M[I,2] := Mid End
	    Else
	      Begin M[H,2] := Left; M[I,2] := Right End;
	    If (G = 1) Then
	      Begin M[H,3] := Mid; M[I,3] := Mid End
	    Else
	      Begin M[H,3] := Left; M[I,3] := Right End;
	  End;
  M[0,1] := Mid;
  M[0,2] := Mid;
  M[0,3] := Mid
End;

Procedure Grab_Name(Var Our_Name : MSG_Line);
Var
  Len : Integer;
Begin (* Grab_Name *)
  Add_Line(False);
  Vsout('Enter your name please:');
  Add_Line(False);
  Vbout('>');
  Refresh;
  If Get_Line(Namlen,Our_Name,Len) Then
    Begin
      If (Len <= 0) Then
	Get_Username(Our_Name)
    End
  Else
    Get_Username(Our_Name)
End; (* Grab_Name *)

	  (* * * * * * * * *)
	  (* Help routines *)
	  (* * * * * * * * *)

Procedure First_Game;
Begin
  Vcls;
  Vdca(1,20);
  Vsout('>> TIAR <<'); Vnl;
  Vnl;
  Vsout('This game is a minimum information problem.  Part of the'); Vnl;
  Vsout('game is that the user must determine for himself how the'); Vnl;
  Vsout('game operates.  The game does follow a single organized'); Vnl;
  Vsout('set of rules that the user should be able to systematically'); Vnl;
  Vsout('determine.'); Vnl;
  Vnl;
  Vsout('To win the game, the user need only get 400 or more points.');
  Vnl;
  Vnl;
  Vsout('Though I recommend playing the game with only what you know'); Vnl;
  Vsout('now, you can get help by using the "H" command.'); Vnl;
  Vnl;
  Vsout('Good luck...');
  More
End;

Function Again : Boolean; (* True if user wishes to continue *)
Var (* used only in HELP *)
  Ch : Char;
  Ox, Oy : Integer;
Begin
  Again := True;
  Vdca(Scr_x_max,1);
  Vsout('--more--');
  Ox := Screen.Cx; (* save current pos *)
  Oy := Screen.Cy;
  Refresh;
  Repeat
    Ch := Comand;
    If (Ch = '?') Then
      Begin
	Vnl;
	Vsout(' <Space> to continue, <del> to quit');
	Vdca(Ox,Oy);
	Refresh;
	Ch := Chr(0)
      End
  Until (Ch >= Space);
  If (Ch in ['N','n','Q','q',Chr(177B)]) Then
    Again := False
End;

Procedure Notes;
Begin
  Vcls;
  Vdca(Scr_x_min,18);
  Vsout('>> Some TIAR Notes <<'); Vnl;
  Vnl
End;

Procedure Victim;
Var
  Ready : Boolean;
Begin
  Vcls;
  Vdca(Scr_x_min,20);
  Vsout('>> TIAR <<'); Vnl;
  Vnl;
  Vsout('Aha, we have ourselves a victim, er, challenger.'); Vnl;
  Vnl;
  Vsout('This game is a strategic game. The rules, scoring system and'); Vnl;
  Vsout('penalty system are consistent, however, the game will be'); Vnl;
  Vsout('different each time it is played.'); Vnl;
  Vnl;
  Vsout('I hope that you are able to complete your challenge without'); Vnl;
  Vsout('further assistance and I wish you good luck at your task.'); Vnl;
  Vsout('   -- Scott L. Richmond, Creator of TIAR'); Vnl;
  Vnl;
  Vsout('Addendum:  This version was implemented from the original'); Vnl;
  Vsout('TRS-80 Microsoft Basic version by John M. Relph.'); Vnl;
  Ready := Again
End;

Procedure Hints;
Var
  Ready : Boolean;
Begin
  Notes;
  Vnl;
  Vsout('Chicken!'); Vnl;
  Vnl;
  Vsout('Chicken though you may be, you are much wiser than the'); Vnl;
  Vsout('masochists who accepted the challenge.'); Vnl;
  Vnl;
  Vsout('All of the information that is given to you here is useful, but');
  Vnl;
  Vsout('you won''t necessarily be told how.'); Vnl;
  Vnl;
  Vsout('TIAR was created by Scott L. Richmond in 1974 using a special'); Vnl;
  Vsout('deck of 150 cards, a pencil, a blank sheet of paper, and the'); Vnl;
  Vsout('rules.  None of the rules have been changed in the computer'); Vnl;
  Vsout('version.'); Vnl;
  Ready := Again;
  If Ready Then Begin
    Notes;
    Vsout('The pencil and blank sheet of paper have been replaced by the'); Vnl;
    Vsout('computer''s automatic scoring system.  The cards have been'); Vnl;
    Vsout('replaced by the computer''s memory, so that all you are actually'); Vnl;
    Vsout('missing is the rules.  Ah, gee!'); Vnl;
    Vnl;
    Vsout('When you run the program you will see on the right side of your'); Vnl;
    Vsout('screen the scoring pad.  There are four types of possible'); Vnl;
    Vsout('scoring and two types of penalties.  Although they are not'); Vnl;
    Vsout('defined for you, they are consistent and if you watch them'); Vnl;
    Vsout('carefully, you should be able to figure out what causes them to'); Vnl;
    Vsout('change and the increments of their various changes.'); Vnl;
    Ready := Again
    End;
  If Ready Then Begin
    Notes;
    Vsout('Your score will equal the total scores (A, B, C, D) less the'); Vnl;
    Vsout('total penalties (A, B).  The maximum of each score and penalty'); Vnl;
    Vsout('is as follows:'); Vnl;
    Vnl;
    Vsout('    Score A:  545           Penalty A:  153'); Vnl;
    Vsout('    Score B:  396           Penalty B:  198'); Vnl;
    Vsout('    Score C: 2050'); Vnl;
    Vsout('    Score D:   90           Score:     2562'); Vnl;
    Vnl;
    Vsout('So you see 400 points isn''t really too hard to obtain.  After'); Vnl;
    Vsout('all, there''s a theoretical maximum of 2562.'); Vnl;
    Ready := Again
    End;
  If Ready Then Begin
    Notes;
    Vsout('When you start to play the game, you will note that you have'); Vnl;
    Vsout('five different actions (A, B, C, D, E) that you can operate.'); Vnl;
    Vnl;
    Vsout('Of these five actions, one affects no score; three affect at'); Vnl;
    Vsout('least one score, perhaps two; and one affects at least one'); Vnl;
    Vsout('score, perhaps even two or even three.'); Vnl;
    Vnl;
    Vsout('Of these five actions, one affects no penalty; three affect one'); Vnl;
    Vsout('penalty; and one affects both penalties.'); Vnl;
    Vnl;
    Vsout('The scores and penalties will only be affected by the actions'); Vnl;
    Vsout('if they are used correctly with valid parameters.'); Vnl;
    Ready := Again
    End;
  If Ready Then Begin
    Notes;
    Vsout('What''s a parameter?  Glad you asked that.'); Vnl;
    Vnl;
    Vsout('A parameter is a pile identification title.'); Vnl;
    Vnl;
    Vsout('What''s a pile identification title?'); Vnl;
    Vnl;
    Vsout('A pile identification title is the name of one of the nine'); Vnl;
    Vsout('piles (A, B, C, D, E, F, G, H, I).'); Vnl;
    Vnl;
    Vsout('By the way, one of the actions requires no parameters; two of'); Vnl;
    Vsout('the actions require two parameters; one of the actions requires'); Vnl;
    Vsout('two parameters; and one of the actions requires three parameters.'); Vnl;
    Ready := Again
    End;
  If Ready Then Begin
    Notes;
    Vsout('If you give an action which requires more than one parameter an'); Vnl;
    Vsout('initial parameter which is invalid, the game will reject the'); Vnl;
    Vsout('action at that point without asking for additional parameters.'); Vnl;
    Vnl;
    Vsout('By now you should be thoroughly confused.  Don''t worry, this'); Vnl;
    Vsout('is normal.  Later you will become both confused and'); Vnl;
    Vsout('frustrated. This is also normal.'); Vnl;
    Vnl;
    Vsout('My suggestion is that you try running the game once or twice'); Vnl;
    Vsout('and then review these clues and hints.  They will make more'); Vnl;
    Vsout('sense at that point in time.'); Vnl;
    Ready := Again
    End;
  If Ready Then Begin
    Notes;
    Vsout('And finally, each game is randomly set up.  This means that if'); Vnl;
    Vsout('you play the game more than once, you will not repeat the same'); Vnl;
    Vsout('exact game.  Rather, you will be playing a game with the same'); Vnl;
    Vsout('rules.  In each different game, there is a hidden body of'); Vnl;
    Vsout('knowledge which  is used in the game.  For each different game'); Vnl;
    Vsout('this knowledge will be different, however, for any single game'); Vnl;
    Vsout('this knowledge will be consistent.'); Vnl;
    Vnl;
    Vsout('I wish you good luck and lots of fun.'); Vnl;
    Vsout('   -- Scott L. Richmond, Creator of TIAR'); Vnl;
    Vnl;
    Vsout('Addendum:  This version was implemented from the original'); Vnl;
    Vsout('TRS-80 Microsoft Basic version by John M. Relph.'); Vnl;
    Ready := Again
    End
End;

Procedure Notes_Intro;
Var
  Ready : Boolean;
  Answer : Char;
Begin (* Notes_Intro *)
  Notes;
  If (Plays = 1) Then
    Begin
      Vsout('So you made it through the first game, eh?'); Vnl;
      Vnl
    End;
  Vsout('These notes explain some of what the introduction to the'); Vnl;
  Vsout('program didn''t.  This doesn''t mean, however, that these'); Vnl;
  Vsout('notes will give you the rules to the game.'); Vnl;
  Vnl;
  Vsout('First of all, you, as the user, must understand that you'); Vnl;
  Vsout('are trying to accomplish two different goals.  First, you'); Vnl;
  Vsout('are attempting to decipher how the game operates, and'); Vnl;
  Vsout('second, you are trying to win the game.'); Vnl;
  Ready := Again;
  If Ready Then Begin
    Notes;
    Vsout('When the game is described as a minimum information'); Vnl;
    Vsout('problem, this means that the user is given the minimum'); Vnl;
    Vsout('information necessary to solve the problem.'); Vnl;
    Vnl;
    Vsout('Do you think you must receive more clues and hints before'); Vnl;
    Vsout('you are able to accept this intellectual challenge [Y/N]? ');
    Refresh;
    Repeat
      Answer := Comand
    Until (Answer In ['y','n','Y','N']);
    If (Answer in ['y','Y']) Then
      Hints
    Else
      Victim
    End
End; (* Notes_Intro *)

Function Get_pile_id (What : Integer; Var X, Y : Coord) : Boolean;
Var
  Ch : Char;
  Val : Integer;
  Done : Boolean;
Begin (* Get_pile_id *)
  Done := False;
  Repeat
    Add_Line(False);
    Case What of
      1 : Vsout('Which pile (A-I)? ');
      2 : Vsout('Which other pile (A-I)? ');
      3 : Vsout('Which final pile (A-I)? ')
    End;
    Refresh;
    Repeat
      Ch := Comand;
      If (Ch = Chr(33B)) Then
	Begin
	  Done := True;
	  Get_pile_id := False
	End
      Else If (Ch = '?') Then
	Begin
	  Add_Line(True);
	  Vsout('Pile ID, "A" - "I"');
	  Add_Line(True);
	  Vsout('   or <ESC> to abort');
	  Done := True
	End
      Else If (Ch in ['a'..'z']) Then
	Ch := Chr(Ord(Ch) - 40B);
      If (Ch in ['A'..'I']) Then
	Begin
	  Vbout(ch);
	  Refresh;
	  Val := Ord(Ch) - Ord('A');
	  X := Val Div 3;
	  Y := Val Mod 3;
	  Get_pile_id := True;
	  Done := True
	End
    Until Done;
    If (Ch = '?') Then
      Done := False
  Until Done
End; (* Get_pile_id *)

Procedure Calculate_Weirdness (E,F,E1,F1,E2,F2 : Integer;
			       Var OK : Boolean; Var K : Integer);
Begin
  OK := True;
  K := 0;
  If (E = E1) and (E1 = E2) Then
    K := E
  Else If (F = F1) and (F1 = F2) Then
    K := F + 3
  Else If (E = F) and (E1 = F1) and (E2 = F2) Then
    K := 6
  Else If (((E = F) and (E = 1) and (E1 = F2) and (E2 = F1) and
	    (((E1 = 0) and (E2 = 2)) or ((E1 = 2) and (E2 = 0)))) or
	   ((E2 = F2) and (E2 = 1) and (E = F1) and (E1 = F) and
	    (((E = 0) and (E1 = 2)) or ((E = 2) and (E1 = 0)))) or
	   ((E1 = F1) and (E1 = 1) and (E = F2) and (E2 = F) and
	    (((E = 0) and (E2 = 2)) or ((E = 2) and (E2 = 0))))) Then
    K := 7
  Else
    Ok := False
End;

Function Game_Complete : Boolean;
Var
  E, F, G, E1, E2, F1, F2, K : Integer;
  J, Done : Boolean;
Begin
  Add_Line(False);
  Add_Line(False);
  Vsout('    >> Processing <<');
  Add_Line(False);
  Vdca(Screen.Vx,Screen.Vy-1);
  Vbout(Space);
  Vdca(Scr_x_min,Scr_y_min);
  Refresh;
  Sleep(10); (* sleep 1 sec *)
  Done := False;
  For E := 0 to 2 do
    For F := 0 to 2 do
      If (World[E,F,0] <> 0) Then
	If (World[E,F,World[E,F,0]] = 0) Then
	  Done := True
	Else
	  Begin
	    G := World[E,F,World[E,F,0]] + 7;
	    If (G > 14) Then G := G - 14;
	    If Not Done and (B[G] > 0) Then
	      Done := True
	  End;
  If Not Done Then
    Begin
      Sleep(10);
      For E := 0 to 2 do
	For F := 0 to 2 do
	  If (World[E,F,0] <> 0) Then
	    For E1 := 0 to 2 do
	      For F1 := 0 to 2 do
		If (((E <> E1) or (F <> F1))
		    And (Abs(E-E1) < 2) and (Abs(F-F1) < 2)
		    and (World[E1,F1,0] <> 0)) Then
		  Begin
		    G := World[E,F,World[E,F,0]] + 7;
		    If (G > 14) Then G := G - 14;
		    If (G = World[E1,F1,World[E1,F1,0]]) Then
		      Done := true
		  End
    End;
  If Not Done Then
    Begin
      Sleep(10);
      For E := 0 to 2 do
	For F := 0 to 2 do
	  For E1 := 0 to 2 do
	    For F1 := 0 to 2 do
	      If (((E1 <> E) or (F1 <> F)) and
		  (World[E,F,World[E,F,0]] = World[E1,F1,World[E1,F1,0]])) Then
		For E2 := 0 to 2 do
		  For F2 := 0 to 2 do
		    If (((E<>E2) or (F<>F2)) and ((E1<>E2) or (F1<>F2)) and
			(World[E,F,World[E,F,0]] = World[E2,F2,World[E2,F2,0]])) Then
		      Begin
			Calculate_Weirdness(E,F,E1,F1,E2,F2,J,K);
			If (J and ((World[E,F,World[E,F,0]] <> 0) or
				   (Not C[K]))) Then
			  Done := True
		      End
    End;
  If Done Then
    Begin
      Game_Complete := False;
      Clr_Lines
    End
  Else
    Game_Complete := True
End;

Procedure Update_Scores;
Var
  Total : Integer;
Begin
  Vdca(2,47);
  Vnout(D[0]*5,5);
  Vdca(3,47);
  Vnout(D[1]*4,5);
  Vdca(4,47);
  Vnout(D[2]*50,5);
  Vdca(5,47);
  Vnout(D[3]*10,5);
  Vdca(2,66);
  Vnout(D[4]*3,3);
  Vdca(3,66);
  Vnout(D[5]*2,3);
  Total := (D[0]*5) + (D[1]*4) + (D[2]*50) + (D[3]*10) - (D[4]*3) - (D[5]*2);
  Vdca(5,64);
  Vnout(Total,5)
End;

Procedure Update_Pile (E,F : Coord);
Begin
  Vdca(E*4+4,10*F+5);
  If (World[E,F,0] > 0) Then
    Vsout(M[World[E,F,World[E,F,0]]])
  Else
    Vsout('   ')
End;

Procedure Stats;
Begin (* Stats *)
  Vdca(20,2);
  Vsout('You have won ');
  Vnout(Wins,0);
  Vsout(' out of ');
  Vnout(Plays,0);
  Vsout(' games');
  Vdca(21,2);
  Vsout('Your highest is ');
  Vnout(High,0)
End; (* Stats *)

Procedure Build_Screen;
Var
  I,J : Integer;
Begin (* Build_screen *)
  Vcls;
  For I := 1 to 13 Do
    Begin
      If ((I mod 4) = 1) Then
	Vsout('+---------+---------+---------+')
      Else
	Vsout('|         |         |         |');
      Vnl
    End;
  For I := 0 to 2 do
    For J := 0 to 2 do
      Begin
	Vdca(I*4+2,J*10+5);
	Vbout('<');
	Vbout(Chr(65+J+I*3));
	Vbout('>');
	Update_Pile(I,J);
      End;
  Vdca(2,39);
  Vsout('Score A:');
  Vdca(3,39);
  Vsout('Score B:');
  Vdca(4,39);
  Vsout('Score C:');
  Vdca(5,39);
  Vsout('Score D:');
  Vdca(2,54);
  Vsout('Penalty A:');
  Vdca(3,54);
  Vsout('Penalty B:');
  Vdca(5,54);
  Vsout('Total:');
  Update_Scores;
  Vdca(15,11);
  Vsout('>> TIAR <<');
  Vdca(17,2);
  Vsout('Time: ');
  If (Plays > 0) Then
    Begin
      Stats;
      If (Our_Name <> Empty) Then
	Begin
	  Vdca(18,2);
	  Vsout('Name: ');
	  For I := 1 to Namlen Do
	    Vbout(Our_Name[I])
	End
    End
End; (* Build_screen *)

Procedure Init_Game;
Var
  E, F, G, I, H : Integer;
Begin
  For E := 0 to 5 do
    Begin
      D[E] := 0;
      Old_D[E] := -1
    End;
  For E := 0 to 7 do
    C[E] := False;
  For E := 0 to 14 do
    B[E] := 10;
  for E := 0 to 2 do
    For F := 0 to 2 do
      Begin
	For G := 1 to 11 do
	  Begin
	    H := Rnd(15) - 1;
	    While (B[H] = 0) do
	      H := (H + 1) Mod 15;
	    B[H] := B[H] - 1;
	    World[E,F,G] := H
	  End;
	World[E,F,0] := 11
      End;
  D[0] := B[0];
  B[0] := 0;
  D[4] := 51 - D[0];
  D[5] := 99;
  Build_Screen
End;

Procedure Change_Pile (E,F : Coord);
Begin
  World[E,F,0] := World[E,F,0] - 1;
  If (World[E,F,0] = 0) Then
    D[3] := D[3] + 1;
  Update_Pile(E,F)
End;

Procedure Do_A;
Var
  E, F : Coord;
Begin
  If Get_Pile_ID(1,E,F) Then
    Begin
      If (World[E,F,0] <> 0) Then
	If (World[E,F,World[E,F,0]] = 0) Then
	  Begin
	    Change_Pile(E,F);
	    D[0] := D[0] + 1;
	    D[5] := D[5] - 1;
	    Update_Scores
	  End
    End;
  Clr_Lines
End;

Procedure Do_B;
Var
  E, F : Coord;
  G : Integer;
Begin
  If Get_Pile_ID(1,E,F) Then
    Begin
      If ((World[E,F,0] <> 0) and (World[E,F,World[E,F,0]] <> 0)) Then
	Begin
	  G := World[E,F,World[E,F,0]] + 7;
	  If (G > 14) Then G := G - 14;
	  If (B[G] <> 0) Then
	    Begin
	      B[G] := B[G] - 1;
	      D[4] := D[4] - 1;
	      D[1] := D[1] + 1;
	      D[5] := D[5] - 1;
	      Change_Pile(E,F);
	      UpDate_Scores
	    End
	End
    End;
  Clr_Lines
End;

Procedure Do_C;
Var
  E, F, E1, F1 : Coord;
  G : Integer;
Begin
  If Get_Pile_ID(1,E,F) Then
    Begin
      If (World[E,F,0] <> 0) and (World[E,F,World[E,F,0]] <> 0) Then
	Begin
	  If Get_Pile_ID(2,E1,F1) Then
	    Begin
	      If ((World[E1,F1,0] <> 0) and (World[E1,F1,World[E1,F1,0]] <> 0)
		  And ((E1<>E) or (F1<>F)) and (Abs(E-E1)<2) and (Abs(F-F1)<2)) Then
		Begin
		  G := World[E,F,World[E,F,0]] + 7;
		  If (G > 14) then G := G -14;
		  If (G = World[E1,F1,World[E1,F1,0]]) Then
		    Begin
		      D[5] := D[5] - 2;
		      D[1] := D[1] + 1;
		      Change_Pile(E,F);
		      Change_Pile(E1,F1);
		      Update_Scores
		    End
		End
	    End
	End
    End;
  Clr_Lines
End;

Procedure Do_D;
Var
  E, F, E1, F1, E2, F2 : Coord;
  J : Boolean;
  K, H, G : Integer;
Begin
  If Get_Pile_ID(1,E,F) Then
    Begin
      If (World[E,F,0] = 0) Then
	Begin
	  If Get_Pile_ID(2,E1,F1) Then
	    Begin
	      If (World[E1,F1,0] = 0) and ((E1<>E) or (F1<>F)) Then
		Begin
		  If Get_Pile_ID(3,E2,F2) Then
		    Begin
		      If ((World[E2,F2,0] = 0) and
			  ((E1<>E2) or (F1<>F2)) and
			  ((E<>E2) or (F<>F2))) Then
			Begin
			  Calculate_Weirdness(E,F,E1,F1,E2,F2,J,K);
			  If (J = True) and (Not C[K]) Then
			    Begin
			      C[K] := True;
			      D[2] := D[2] + 1;
			      For G := 0 to 2 do
				Begin
				  If (K < 3) Then
				    Vdca(4*E+4,G*10+5)
				  Else If (K > 2) and (K < 6) Then
				    Vdca(4*G+4,F*10+6)
				  Else If (K = 6) Then
				    Vdca(4*G+4,G*10+7)
				  Else
				    Vdca(4*G+4,27-G*10);
				  Vbout(Star)
				End;
			      Update_Scores
			    End
			End
		    End
		End
	    End
	End (* If (World[E,F,0] = 0) *)
      Else
	Begin (*  World[E,F,0] <> 0  *)
	  If Get_Pile_ID(2,E1,F1) Then
	    Begin
	      If ((World[E,F,World[E,F,0]] = World[E1,F1,World[E1,F1,0]]) and
		  (World[E,F,World[E,F,0]] <> 0) and
		  ((E1<>E) or (F1<>F))) Then
		Begin
		  If Get_Pile_ID(3,E2,F2) Then
		    Begin
		      If (((E1<>E2) or (F1<>F2)) and ((E2<>E) or (F2<>F)) and
			  (World[E,F,World[E,F,0]] = World[E2,F2,World[E2,F2,0]])) Then
			Begin
			  Calculate_Weirdness(E,F,E1,F1,E2,F2,J,K);
			  If (J = True) Then
			    Begin
			      D[0] := D[0] + 3;
			      D[5] := D[5] - 3;
			      D[2] := D[2] + 1;
			      Change_Pile(E,F);
			      Change_Pile(E1,F1);
			      Change_Pile(E2,F2);
			      UpDate_Scores
			    End
			End
		    End
		End
	    End
	End
    End;
  Clr_Lines
End;
	  
Procedure Fill_Score (Var The_Scores : Score_Rec);
Var
  I : Phases;
  J, Num : Integer;
  Nam : MSG_Line;
Begin
  Reset(Score_File,Score_Name,0,0,0,10B);
  If Not EOF(Score_file) Then
    The_Scores := Score_File^
  Else
    Begin
      For I := Weekly To All_Time Do
	For J := 1 To 10 Do
	  Begin
	    The_scores.Scores[I,J].Total := -1000;
	    The_scores.Scores[I,J].Name[1] := Chr(0);
	  End;
      The_Scores.DayofMon := 0;
    End
End;

Function Max (Left, Right : Integer) : Integer;
Begin
  If (Left > Right) Then
    Max := Left
  Else Max := Right
End;

Procedure Store_Score(Phase : Phases;
		      Var The_Scores : Score_Rec;
		      Score : Integer;
		      Var Changed : Boolean);
Var
  Day, J, I : Integer;
  Done : Boolean;
Begin
  Day := Today;
  With The_Scores Do
    Begin
      If (Day >= DayofMon) Then
	Begin
	  DayofMon := Day + 7;
	  For I := 1 To 10 Do
	    Begin
	      Scores[Weekly,I].Total := -1000;
	      Scores[Weekly,i].Name[1] := Chr(0);
	    End;
	  Changed := True
	End;
      If (Score > Scores[Phase,10].Total) Then
	Begin
	  I := 9;
	  Done := False;
	  While Not Done do
	    If (I = 0) Then
	      Done := True
	  Else If (Score > Scores[Phase,I].Total) Then	  
	    Begin
	      Scores[Phase,I+1] := Scores[Phase,I];
	      I := I - 1
	    End
	  Else
	    Done := True;
	  I := I + 1;
	  Scores[Phase,I].Total := Score;
	  Scores[Phase,I].Name := Our_Name;
	  Changed := True
	End
    End
End;

Procedure Empty_Scores(The_Scores : Score_Rec);
Var
  I : Phases;
  J : Integer;
Begin
  Rewrite(Score_File,Score_Name,0,0,0,10B);
  If (Erstat(Score_File) = 0) Then
    Begin
      Score_File^ := The_Scores;
      Put(Score_File);
      Close(Score_File)
    End
End;

Procedure Disp_Scores(Scores : Score_Array);
Var
  I,J : Integer;
Begin
  Clr_Lines;
  Add_Line(False);
  Vsout('Weekly Scores:');
  For J := 1 to 10 do
    If (Scores[Weekly,J].Total <> -1000) Then
      Begin
	Add_Line(False);
	For I := 1 to 25 Do
	  Vbout(Scores[Weekly,J].Name[I]);
	Vnout(Scores[Weekly,J].Total,5)
      End;
  Add_Line(False);
  More;
  Clr_Lines;
  Add_Line(False);
  Vsout('All-Time Scores:');
  For J := 1 to 10 do
    If (Scores[All_Time,J].Total <> -1000) Then
      Begin
	Add_Line(False);
	For I := 1 to 25 Do
	  Vbout(Scores[All_time,J].Name[I]);
	Vnout(Scores[All_time,J].Total,5)
      End
End;

Procedure Savescore (Score : Integer; Quit : Boolean);
Var
  Phase : Phases;
  Scores : Score_Rec;
  Cool : Boolean;
Begin
  Fill_Score(Scores);
  Cool := False;
  If Not Quit Then
    Begin
      If (Our_Name = Empty) Then
	Grab_Name(Our_Name)
      Else
	More;
      For Phase := Weekly to All_Time do
	Store_Score(Phase,Scores,Score,Cool)
    End;
  Disp_Scores(Scores.Scores);
  If Cool Then
    Empty_Scores(Scores)
End;

Procedure Show_Score (Quit : Boolean);
Var
  Diff,Score,Sx,Sy : Integer;
Begin
  If Not Quit Then
    Begin
      Add_Line(True);
      Vsout('The game has been completed.');
      Add_Line(True);
      Vsout('There is no further possible');
      Add_Line(True);
      Vsout('  change in your score.');
      Score := (D[0]*5) + (D[1]*4) + (D[2]*50) + (D[3]*10) - (D[4]*3) - (D[5]*2);
      Add_Line(True);
      Vsout('Your score is ');
      Vnout(Score,0);
      Vbout('.');
      Add_Line(True);
      Plays := Plays + 1;
      High := Max(High,Score);
      If (Score < 400) Then
	Vsout('You have lost by ')
      Else
	Begin
	  Wins := Wins + 1;
	  Vsout('You have won by ')
	End;
      Vnout(abs(Score-400),0);
      Vsout(' points.');
      Vpos(Sx,Sy);
      Stats;
      Vdca(Sx,Sy)
    End; (* If Not Quit *)
  SaveScore(Score,Quit)
End;

Function Playing : Boolean;
Var
  Quit,Game_In_Progress,Done : Boolean;
  Ch : Char;
Begin
  If (Plays = 1) Then
    Begin
      Notes_Intro;
      Build_Screen
    End;
  Init_Game;
  Game_In_Progress := True;
  Quit := False;
  Clr_Lines;
  If (Plays = 0) Then
    Begin
      Add_Line(False);
      Vsout('Welcome to TIAR!')
    End;
  While Game_In_Progress do
    Begin
      Vdca(17,9);
      Vtime;
      Add_Line(False);
      Vsout('Which action (A/B/C/D/E)? ');
      Refresh;
      Done := False;
      Repeat
	Ch := Comand;
	If (Ch = '?') Then
	  Begin
	    Add_Line(True);
	    Vsout('  Pick an action, "A" - "E"');
	    Add_Line(True);
	    Vsout('  "H" for help');
	    Add_Line(True);
	    Vsout('  C-C to quit');
	    Add_Line(True);
	    Vsout('  C-L to refresh');
	    Done := True;
	  End
	Else If (Ch = Chr(14B)) Then (* C-L *)
	  Begin
	    Clr_Lines;
	    Vfix;
	    Done := True
	  End
	Else If (Ch = Chr(3B)) Then (* C-C *)
	  Begin
	    Add_Line(False);
	    Vsout('Quit? ');
	    Refresh;
	    Done := True;
	    Ch := Comand;
	    If (Ch in ['y','Y']) Then
	      Begin
		Game_in_progress := False;
		Quit := True
	      End
	    Else
	      Begin
		Vsout('No');
		Refresh;
		Ch := Chr(3B)
	      End
	  End
	Else If (Ch in ['A'..'E','H','a'..'e','h']) Then
	  Begin
	    If (Ch >= 'a') Then
	      Ch := Chr(Ord(Ch) - 40B);
	    Done := True
	  End
      Until Done;
      If ((Ch > Space) and (Ch <> '?')) Then
	Begin
	  Vbout(Ch);
	  Refresh;
	  Case Ch of
	    'A' : Do_A;
	    'B' : Do_B;
	    'C' : Do_C;
	    'D' : Do_D;
	    'E' : Game_In_Progress := Not Game_Complete;
	    'H' : Begin
		    Notes_Intro;
		    Build_Screen
		  End;
	    Others:;
	  End
	End
    End; (* While Game_In_Progress *)
  Show_Score(Quit);
  If Not Quit Then
    Begin
      Add_Line(False);
      Vsout('Another game? ');
      Refresh;
      Ch := Comand;
      If Not (Ch in ['y','Y',' ']) Then
	Quit := True
    End;
  Playing := Not Quit
End;

Procedure Play;
Begin (* Play *)
  First_Game;
  While Playing Do
End; (* Play *)

Begin (* MAIN *)
  If Not Setup Then
    Begin
      Trmini;
      Setup := True;
      Save_Self('Tiar.Exe')
    End
  Else
    Begin
      Initialize;
      Play;
      Terminate
    End;
End. (* MAIN *)
