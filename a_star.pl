% according to the concept of a* search, we need to store open and closed points in basically 2 lists
:- dynamic open/6.
:- dynamic closed/6.
:- dynamic nextVertex/6.

% location of the items on the map
:- dynamic covid/2.
:- dynamic home/2.
:- dynamic mask/2.
:- dynamic doctor/2.

% storing paths leading to home
:- dynamic path/2.
:- dynamic step/7.
:- dynamic numberOfPaths/1.
:- dynamic minLength/1.

% everything in prolog is an object so we specify our objects
object(X, Y) :-
    covid(X, Y);
    home(X, Y);
    mask(X, Y);
    doctor(X, Y);
    (   X == 0, Y == 0).

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

% defining free
free(X, Y, M) :-
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

    (X >= 0, X =< M),
    (Y >= 0, Y =< M).

% Generating the final path
generateFinalPath(X, Y, Number):-
    (   X \= 0; Y \= 0)-> (
                            path(FinalPath, Number),
                            append([[X, Y]], FinalPath, FinalPath1),
                            retractall(path(_, Number)),
                            assert(path(FinalPath1, Number)),
                            step(X, Y, _, _, PrevX, PrevY, Number) ->  (
                                                                           retract(step(X, Y, _, _, PrevX, PrevY, Number)),
                                                                         generateFinalPath(PrevX, PrevY, Number)
                                                                       );
                            (
                              (   closed(X, Y, _, _, PrevX, PrevY); open(X, Y, _, _, PrevX, PrevY)),
                                generateFinalPath(PrevX, PrevY, Number)
                            )
                        ); true.
% generating path from a mask or a doctor to home
generatePath(X, Y, G, Number):-
    home(HomeX, HomeY),
    (   X \= HomeX; Y \= HomeY) ->
    (
      (   (   HomeX > X ->  I = 1); HomeX < X ->  I = -1; I = 0),
        (   (   HomeY > Y ->  J = 1); HomeY < Y ->  J = -1; J = 0),

      NextX is X + I,
        NextY is Y + J,

      G1 is G + 1,

       abs(HomeX - X, DX),
        abs(HomeY - Y, DY),
        (DX < DY -> H1 is DY; H1 is DX),

    %writeln("NEXT"),
      %forall(maskPath(A, B, C, D, E, F), writeln(maskPath(A, B, C, D, E, F))),

      assert(step(NextX, NextY, G1, H1, X, Y, Number)),
        generatePath(NextX, NextY, G1, Number)

    ); true.


% We begin to search from this point
% Traversing through all adjacent points and choosing the closest one by comparing F values of the points
% F is G + H, where G is the length of the distance travelled and H is the distance to home
% all the adjacent points become open, after checking the adjacent points, the current one becomes closed
aStar(X, Y, G, H, PrevX, PrevY, M):-
    home(HomeX, HomeY),
    (
        (   X == HomeX , Y == HomeY) ->   (
                                              assert(closed(X, Y, _, _, PrevX, PrevY)),
                                                assert(path([], 0)),
                                                generateFinalPath(X, Y, 0)
                                          );
        (
            checkAllAdjacent(X, Y, M),
            assert(closed(X, Y, G, H, PrevX, PrevY)),
            retract(open(X, Y, G, H, PrevX, PrevY)),
            forall(open(X0, Y0, G0, H0, PrevX0, PrevY0),
                (
                    nextVertex(_, _, G1, H1, _, _),
                    H0 + G0 =< H1 + G1 -> (
                                            retractall(nextVertex(_, _, _, _, _, _)),
                                            assert(nextVertex(X0, Y0, G0, H0, PrevX0, PrevY0))
                                        ); true
                )
            ),

            nextVertex(X1, Y1, G1, H1, PrevX1, PrevY1),
            retractall(nextVertex(_, _, _, _, _, _)),
            assert(nextVertex(_, _, 999, 999, _, _)),
            (   G1 < 100) ->  aStar(X1, Y1, G1, H1, PrevX1, PrevY1, M); true
        )
    ).
% checking all the adjacent points
checkAllAdjacent(X, Y, M):-
    Xplus is X + 1,
    Xminus is X - 1,
    Yplus is Y + 1,
    Yminus is Y - 1,
    (   check(Xplus, Yplus, X, Y, M); true),
    (   check(Xplus, Y, X, Y, M); true),
    (   check(Xplus, Yminus, X, Y, M); true),
    (   check(X, Yplus, X, Y, M); true),
    (   check(X, Yminus, X, Y, M); true),
    (   check(Xminus, Yplus, X, Y, M); true),
    (   check(Xminus, Y, X, Y, M); true),
    (   check(Xminus, Yminus, X, Y, M); true).

% By this point we have already finished the checking procedure
% If we get a point in this predicate then we make it open only if we have not met this point yet
% Calculating the G and H values
% if this point is already open then we calculate the G and H values again and compare with the existing ones
% if the new values give a smaller sum then we replace the existing point with the new one
% if a mask or a doctor lie on the point, we build a path and store it
check(X, Y, PrevX, PrevY, M):-
    open(PrevX, PrevY, D0, _, _, _),
    G is D0 + 1,

    home(HomeX, HomeY),
    abs(HomeX - X, DX),
    abs(HomeY - Y, DY),
    (DX < DY -> H is DY; H is DX),

    (   \+open(X, Y, _, _, _, _), \+closed(X, Y, _, _, _, _), free(X, Y, M)) ->
    (
      assert(open(X, Y, G, H, PrevX, PrevY)),
        (   mask(MaskX, MaskY) ; true),
        (   (   MaskX == X, MaskY == Y)) ->
        (
            assert(open(X, Y, G, H, PrevX, PrevY)),
            numberOfPaths(Number),
            Number1 is Number + 1,
            retract(numberOfPaths(_)),
            assert(numberOfPaths(Number1)),
            assert(path([], Number1)),
            assert(step(X, Y, G, H, PrevX, PrevY, Number1)),
          generatePath(X, Y, G, Number1),
            generateFinalPath(HomeX, HomeY, Number1)
        ); true
    );
    (
        open(PrevX, PrevY, D0, _, _, _),
        G is D0 + 1,

        home(HomeX, HomeY),
        abs(HomeX - X, DX),
        abs(HomeY - Y, DY),
        (DX < DY -> H is DY; H is DX),

        open(X, Y, G1, H1, _, _),
        (   G + H =< G1 + H1) ->  (
                                  retract(open(X, Y, _, _, _, _)),
                                      assert(open(X, Y, G, H, PrevX, PrevY))
                                  ); true

    ).

% the main function
% spawning everything
% preparing all the dynamic predicates to work with later
% having an outcome for the kotlin code
run(M, C1X, C1Y, C2X, C2Y, MX, MY, DX, DY, HX, HY, Rout) :-
    setCovid(C1X, C1Y),
    setCovid(C2X, C2Y),
    setMask(MX, MY),
    setDoctor(DX, DY),
    setHome(HX, HY),

    home(HomeX, HomeY),
    (   HomeX > HomeY ->  H is HomeX; H is HomeY),

    assert(nextVertex(_, _, 999, 999, _, _)),

    assert(numberOfPaths(0)),
    assert(open(0, 0, 0, H, _, _)),
    assert(minLength(999)),

    aStar(0, 0, 0, H, _, _, M),

    numberOfPaths(NumberOfPaths),
    forall(between(0, NumberOfPaths, I),
           (
           path(Path, I),
               minLength(MinLength),
               length(Path, PathLength),
               (   PathLength < MinLength) ->  (
                                               retractall(minLength(_)),
                                                   assert(minLength(PathLength))
                                               ); true
           )
    ),




    path(Rout, I),
    I > -1,
    NOP is NumberOfPaths + 1,
    I < NOP,
               minLength(MinLength),
               length(Rout, PathLength),
                PathLength == MinLength,
    retractall(path(_, _)),
    minLength(MinLength),
    MinLength < 999.