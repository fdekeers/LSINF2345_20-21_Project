-module(linked_list).
-export([loop/1, search/3]).
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

search([H|_], _, true) -> H;
search([H|T], Node, false) -> search(T, Node, Node =:= H);
search([], _, _) -> nil.
