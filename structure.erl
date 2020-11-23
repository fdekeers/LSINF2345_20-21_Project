-module(structure).
-export([loop/1, start/0]).
-import(lists, [reverse/1]).

loop(H) ->
  receive
  {add, Node} ->
      io: format("The list is ~p~n", [[Node]++H]),
      loop([Node]++H);
  {getNeighbors, Node} ->
      io: format("The neighbors are ~p and ~p~n", [search(H, Node, false), search(reverse(H), Node, false)]),
      loop(H)
  end.

search([H|_], Node, true) -> H;
search([H|T], Node, false) -> search(T, Node, Node =:= H);
search([], _, _) -> null.

start() ->
  Loop_pid = spawn(structure, loop, [[]]),
  Loop_pid ! {add, 1},
  Loop_pid ! {add, 2},
  Loop_pid ! {getNeighbors, 2}.
