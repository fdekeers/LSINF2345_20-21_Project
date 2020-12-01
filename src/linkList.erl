-module(linkList).
-export([search/3]).


search([H|_], _, true) -> H;
search([H|T], Node, false) -> search(T, Node, Node =:= H);
search([], _, _) -> null.
