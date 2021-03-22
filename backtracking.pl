% according to the concept of backtracking search, we need to traverse all the paths using DFS

% location of the items on the map
:- dynamic home/2.
:- dynamic covid/2.
:- dynamic pathHome/1.
:- dynamic pathSize/1.
:- dynamic mask/2.
:- dynamic doctor/2.


% everything in prolog is an object so we specify our objects
object(X, Y) :-
    covid(X, Y),
    home(X, Y),
    mask(X, Y),
    doctor(X, Y).


% randomly setting the coordinates of covid, home and mask and doctor
setCovid(X, Y) :-
    \+illegal(X, Y), assert(covid(X, Y)).

setHome(X, Y) :-
    \+illegal(X, Y), assert(home(X, Y)).

setMask(X, Y) :-
    \+illegal(X, Y), assert(mask(X, Y)).

setDoctor(X, Y) :-
    \+illegal(X, Y), assert(doctor(X, Y)).

% defining illegal
illegal(X, Y) :- object(W, V), X==W, Y==V.

% adding path by connecting the visited nodes
addPath(X, Y, M, CurrentPath, Visited):-
    pathSize(PathSize),
    append(CurrentPath, [[X, Y]], NewCurrentPath),
    append(Visited, [[X, Y]], NewVisited),
    length(NewCurrentPath, CurrentLength),
    home(HomeX, HomeY),
    abs(HomeX - X, DX),
    abs(HomeY - Y, DY),
    (DX < DY -> D is DY; D is DX),
    CurrentLength + D < PathSize,
    ((X == HomeX, Y == HomeY) ->  (
                                      retractall(pathHome(_)),
                                      assert(pathHome(NewCurrentPath)),
                                        length(NewCurrentPath, Size),
                                        retractall(pathSize(_)),
                                        assert(pathSize(Size))
                                    ); true),
    (  (
      mask(MaskX, MaskY),
        doctor(DoctorX, DoctorY),
           (   (X == MaskX, Y == MaskY) ; (   X == DoctorX, Y == DoctorY))
       )
      ->  goHome(X, Y, NewCurrentPath);
        nextMove(X, Y, M, NewCurrentPath, NewVisited)
    ).

% building path to safely go home
goHome(X, Y, CurrentPath) :-
    home(HomeX, HomeY),
    (   HomeX > X -> I = 1; (   HomeX < X ->  I = -1; I = 0)),
    (   HomeY > Y -> J = 1; (   HomeY < Y ->  J = -1; J = 0)),
    NextX is X + I,
    NextY is Y + J,
    append(CurrentPath, [[NextX, NextY]], NewCurrentPath),
    length(NewCurrentPath, CurrentLength),
    ((X == HomeX, Y == HomeY) ->  (
                                      pathSize(PathSize),
                                      length(NewCurrentPath, CurrentLength),
                                        CurrentLength < PathSize,
                                      retractall(pathHome(_)),
                                      assert(pathHome(NewCurrentPath)),
                                        length(NewCurrentPath, Size),
                                        retractall(pathSize(_)),
                                        assert(pathSize(Size))
                                    ); goHome(NextX, NextY, NewCurrentPath)).
% defining free
free(X, Y, M, Visited) :-
    Xplus is X + 1,
    Xminus is X - 1,
    Yplus is Y + 1,
    Yminus is Y - 1,
    \+covid(X, Y),
    \+covid(Xplus, Y),
    \+covid(Xminus, Y),
    \+covid(X, Yplus),
    \+covid(X, Yminus),
    \+covid(Xplus, Yplus),
    \+covid(Xplus, Yminus),
    \+covid(Xminus, Yplus),
    \+covid(Xminus, Yminus),
    \+member([X, Y], Visited),
    (X >= 0, X =< M),
    (Y >= 0, Y =< M).

% defining trap
trap(X, Y, M, Visited) :-
    Xplus is X + 1,
    Xminus is X - 1,
    Yplus is Y + 1,
    Yminus is Y - 1,
    \+free(X, Y, M, Visited),
    \+free(Xplus, Y, M, Visited),
    \+free(Xminus, Y, M, Visited),
    \+free(X, Yplus, M, Visited),
    \+free(X, Yminus, M, Visited),
    \+free(Xplus, Yplus, M, Visited),
    \+free(Xplus, Yminus, M, Visited),
    \+free(Xminus, Yplus, M, Visited),
    \+free(Xminus, Yminus, M, Visited).

%  recursive backtracking
backtrack(ActorX, ActorY, I, J, M, CurrentPath, Visited) :-
    X is ActorX + I,
    Y is ActorY + J,
    \+trap(X, Y, M, Visited),
    (
      (   free(X, Y, M, Visited)) ->
      addPath(X, Y, M, CurrentPath, Visited)
    ),
    true.


% checking if the next move is valid
nextMove(X, Y, M, CurrentPath, Visited) :-
    (   backtrack(X, Y, 1, 1, M, CurrentPath, Visited); true),
    (   backtrack(X, Y, 1, 0, M, CurrentPath, Visited); true),
    (   backtrack(X, Y, 1, -1, M, CurrentPath, Visited); true),
    (   backtrack(X, Y, 0, -1, M, CurrentPath, Visited); true),
    (   backtrack(X, Y, 0, 1, M, CurrentPath, Visited); true),
    (   backtrack(X, Y, -1, -1, M, CurrentPath, Visited); true),
    (   backtrack(X, Y, -1, 1, M, CurrentPath, Visited); true),
    (   backtrack(X, Y, -1, 0, M, CurrentPath, Visited); true).




% the main function
% spawning everything
% preparing all the dynamic predicates to work with later
% having an outcome for the kotlin code
run(M, C1X, C1Y, C2X, C2Y, MX, MY, DX, DY, HX, HY, L) :-
    setCovid(C1X, C1Y),
    setCovid(C2X, C2Y),
    setMask(MX, MY),
    setDoctor(DX, DY),
    setHome(HX, HY),

    assert(pathSize(9999)),
    retractall(pathHome(_)),
     free(0, 0, M, []) ->  (
                                  backtrack(0, 0, 0, 0, M, [], []),
                                  pathHome(L)
                              ).
