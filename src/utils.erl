- module (utils).
- export ([buildInitView/2,
           pickRandom/1,
           selectPeer/2,
           selectBuffer/5,
           receivedBuffer/7,
           selectView/4]).


%%% UTILITARY FUNCTIONS %%%

% Returns the initial view of a node, that contains its initial neighbors
% in the data structure (tree or linked-list).
% The cycle of all the neighbors in the initial view is 0.
buildInitView(Nodes, Neighbors) ->
  buildInitView(Nodes, Neighbors, []).
buildInitView([], _, Acc) ->
  lists:reverse(Acc);
buildInitView([{NodeId, NodePid}|T], Neighbors, Acc) ->
  IsMember = lists:member(NodeId, Neighbors),
  if
    IsMember ->
      buildInitView(T, Neighbors, [{NodeId, NodePid, 0}|Acc]);
    true ->
      buildInitView(T, Neighbors, Acc)
  end.

% Sorts the view by decreasing order of freshness.
sort(View) ->
  % Anonymous sorting function, based on the freshness.
  Fun = fun({_, _, CycleA}, {_, _, CycleB}) -> CycleA >= CycleB end,
  lists:sort(Fun, View).

% Gets a random element from a list.
pickRandom(List) ->
  Rand = rand:uniform(length(List)),
  lists:nth(Rand, List).

% Permute: put the H oldest elements at the end,
% and the N elements that will be sent at the beginning.
%   - Sort the list based on freshness
%   - Build a list with the H oldest elements (the last elements)
%   - Build a list without the H oldest elements (the first elements)
%   - Take N random elements from the second list, build a list with them
%   - Build the resulting list: Taken elements + remaining elements + old elements
permute(View, N, H) ->
  SortedView = sort(View),
  IndexH = max(0, length(SortedView) - H),
  OldestPeers = lists:nthtail(IndexH, SortedView),
  FreshestPeers = lists:sublist(SortedView, IndexH),
  {Taken, FRemaining, ORemaining} = takeNRandomPeers(FreshestPeers, OldestPeers, N),
  Taken ++ FRemaining ++ ORemaining.

% Takes N random peers from the view, by starting with the freshest peers.
% Returns the peers taken, the remaining fresh peers, and the remaining old peers.
takeNRandomPeers(FreshestPeers, OldestPeers, N) ->
  takeNRandomPeers(FreshestPeers, OldestPeers, N, []).
% Both lists are empty, return even if there are not enough peers.
takeNRandomPeers([], [], _, Acc) ->
  {lists:reverse(Acc), [], []};
% Enough peers have been taken, return
takeNRandomPeers(FreshestPeers, OldestPeers, 0, Acc) ->
  {lists:reverse(Acc), FreshestPeers, OldestPeers};
% List of fresh peers is empty, take from the H oldest peers.
takeNRandomPeers([], OldestPeers, N, Acc) ->
  Peer = pickRandom(OldestPeers),
  NewOldestPeers = lists:delete(Peer, OldestPeers),
  takeNRandomPeers([], NewOldestPeers, N-1, [Peer|Acc]);
% Take from the freshest peers.
takeNRandomPeers(FreshestPeers, OldestPeers, N, Acc) ->
  Peer = pickRandom(FreshestPeers),
  NewFreshestPeers = lists:delete(Peer, FreshestPeers),
  takeNRandomPeers(NewFreshestPeers, OldestPeers, N-1, [Peer|Acc]).


%%% PEER SELECTION %%%

% Selects a peer from the view.
% The strategy can be rand or tail.
% If rand, a random peer is selected.
% If tail, the oldest peer is selected, which is the last one in the list.
selectPeer(Peers, rand) ->
  pickRandom(Peers);
selectPeer(Peers, tail) ->
  pickOldestPeer(Peers).

% Returns the oldest node from the list of peers.
% A peer is a tuple {PeerId, PeerPid, Cycle}.
% The oldest peer is the one with the smallest Cycle.
pickOldestPeer(Peers) ->
  pickOldestPeer(Peers, {0, 0, infinity}).
pickOldestPeer([], Peer) ->
  Peer;
pickOldestPeer([{HId, HPid, HCycle}|T], {PeerId, PeerPid, PeerCycle}) ->
  if
    HCycle =< PeerCycle ->
      pickOldestPeer(T, {HId, HPid, HCycle});
    true ->
      pickOldestPeer(T, {PeerId, PeerPid, PeerCycle})
  end.


%%% VIEW PROPAGATION %%%

% Selects the buffer to send, by permuting the view.
% Returns the permuted view, and the buffer to send.
selectBuffer(FromId, FromPid, Cycle, View, {ViewSize, H}) ->
  ThisPeer = {FromId, FromPid, Cycle},
  N = round(math:ceil((ViewSize/2) - 1)),
  PermutedView = permute(View, N, H),
  {PermutedView, [ThisPeer] ++ lists:sublist(PermutedView, N)}.

% Received a buffer from a peer.
% If propagate strategy is push, returns the updated view.
% If pushpull, first send local buffer, then returns the updated view.
receivedBuffer(_, NodePid, _, _, View, ReceivedBuffer, {ViewSize, push, H, S}) ->
  selectView(NodePid, View, ReceivedBuffer, {ViewSize, H, S});
receivedBuffer(NodeId, NodePid, FromPid, Cycle, View, ReceivedBuffer, {ViewSize, pushpull, H, S}) ->
  {PermutedView, Buffer} = selectBuffer(NodeId, NodePid, Cycle, View, {ViewSize, H}),
  FromPid ! {response, Buffer},
  selectView(NodePid, PermutedView, ReceivedBuffer, {ViewSize, H, S}).


%%% VIEW SELECTION %%%

% Updates the current view, based on the received view and the H and S parameters.
selectView(Pid, View, ReceivedBuffer, {ViewSize, H, S}) ->
  FunRemovePid = fun({_, ElemPid, _}) -> ElemPid =/= Pid end,
  ReceivedBufferWithoutPid = lists:filter(FunRemovePid, ReceivedBuffer),
  FullView = View ++ ReceivedBufferWithoutPid,
  FullViewUnique = removeDuplicates(FullView),
  % Remove the H oldest peers,
  % or remove the oldest peers until the maximum view size has been reached.
  FullViewH = removeNOldest(FullViewUnique, max(0, min(H, length(FullViewUnique)-ViewSize))),
  % Remove the S first peers in the view,
  %or remove the first peers until the maximum view size has been reached.
  FullViewS = removeNFirst(FullViewH, max(0, min(S, length(FullViewH)-ViewSize))),
  % Remove random elements until the view size is 7
  randomReduceToN(FullViewS, ViewSize).


% Removes the elements of the view that have the same Pid, but that are older.
keepFresher(View, Peer, Index) ->
  keepFresher(View, Peer, Index, 0, []).
keepFresher([], _, _, _, Acc) ->
  lists:reverse(Acc);
keepFresher([BasePeer|T], BasePeer, BaseIndex, CurIndex, Acc) ->
  % The same peer with the same age is present more than once, keep the first one
  if
    CurIndex > BaseIndex ->
      keepFresher(T, BasePeer, BaseIndex, CurIndex+1, Acc);
    true ->
      keepFresher(T, BasePeer, BaseIndex, CurIndex+1, [BasePeer|Acc])
  end;
keepFresher([{BaseId, BasePid, CurCycle}|T], {BaseId, BasePid, BaseCycle}, BaseIndex, CurIndex, Acc) ->
  % The same peer is present more than once, keep the freshest one
  if
    CurCycle < BaseCycle ->
      keepFresher(T, {BaseId, BasePid, BaseCycle}, BaseIndex, CurIndex+1, Acc);
    true ->
      keepFresher(T, {BaseId, BasePid, BaseCycle}, BaseIndex, CurIndex+1, [{BaseId, BasePid, CurCycle}|Acc])
  end;
keepFresher([CurPeer|T], BasePeer, BaseIndex, CurIndex, Acc) ->
  % The two compared peers are different, keep both
  keepFresher(T, BasePeer, BaseIndex, CurIndex+1, [CurPeer|Acc]).

% Removes duplicates of the same Pid, by keeping the freshest one.
removeDuplicates(View) ->
  removeDuplicates(View, 0, View).
removeDuplicates([], _, ResultView) ->
  ResultView;
removeDuplicates([H|T], Index, ResultView) ->
  removeDuplicates(T, Index+1, keepFresher(ResultView, H, Index)).

% Removes the oldest Peer from the view.
removeOldest(View) ->
  removeOldest(View, View, {0, 0, infinity}).
removeOldest(BaseView, [], Oldest) ->
  lists:delete(Oldest, BaseView);
removeOldest(BaseView, [{Id, Pid, Cycle}|T], {OldestId, OldestPid, OldestCycle}) ->
  if
    Cycle =< OldestCycle ->
      removeOldest(BaseView, T, {Id, Pid, Cycle});
    true ->
      removeOldest(BaseView, T, {OldestId, OldestPid, OldestCycle})
  end.

% Removes the N oldest peers from the view.
removeNOldest(View, 0) ->
  View;
removeNOldest(View, N) ->
  removeNOldest(removeOldest(View), N-1).

% Removes the N first peers from the view.
removeNFirst(View, N) ->
  lists:nthtail(N, View).

% Removes random elements from the view, until the size of the view is N.
randomReduceToN(View, N) ->
  randomReduceToN(View, N, length(View)).
randomReduceToN(View, N, Length) ->
  if
    Length =< N ->
      View;
    true ->
      Random = pickRandom(View),
      randomReduceToN(lists:delete(Random, View), N, Length-1)
  end.
