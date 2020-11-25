- module(tree).
- export([add/2, getNeigs/2]).
% gets N'parent and where the node N should be placed
getParentId(N) ->
  if
    N rem 2 =:= 1 -> { N div 2, left };
    N rem 2 =:= 0 -> { (N div 2) - 1, right }
  end.
% creates root
add(0, {}) -> { 0, { nil, nil, nil } };
% other than root
add(N, { M, { F, Ls, Rs } }) -> add(N, getParentId(N), { M, { F, Ls, Rs } }).

% adds sibling to the left of its parent
add(N, { ParentId, Side }, { ParentId, { F, nil, Rs } }) when Side =:= left ->
  { ParentId, { F, { N, { ParentId, nil, nil } }, Rs } };
% adds sibling to the right of its parent
add(N, { ParentId, Side }, { ParentId, { F, Ls, nil } }) when Side =:= right ->
  { ParentId, { F, Ls, { N, { ParentId, nil, nil } } } };

add(_, { ParentId, _ }, { M, { F, nil, nil } }) ->
  { M, { F, nil, nil } };
%
add(N, { ParentId, Side }, { M, { F, Ls, Rs } }) ->
  { M, { F, add(N, { ParentId, Side }, Ls), add(N, { ParentId, Side }, Rs) } }.


getNeigs(N, nil) -> [];
% when node N is a leaf
getNeigs(N, { N, { ParentId, nil, nil } }) ->
  [ ParentId ];
% when node N has only two neighbors (tree is incomplete)
getNeigs(N, { N, { ParentId, Ls, nil } }) ->
  { M, { N, _, _ } } = Ls,
  [ ParentId, M ];
getNeigs(N, { N, { ParentId, nil, Rs } }) ->
  { O, { N, _, _ } } = Rs,
  [ ParentId,  O ];
% when there are three neighbors
getNeigs(N, { N, { ParentId, Ls, Rs } }) ->
  { M, { N, _, _ } } = Ls,
  { O, { N, _, _ } } = Rs,
  [ ParentId, M,  O ];
% lookup
getNeigs(N, { M, { ParentId, Ls, Rs } }) ->
  getNeigs(N, Ls) ++ getNeigs(N, Rs) .
