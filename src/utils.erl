- module (utils).
- export ([selectPeer/2,
           propagateView/5,
           receivedView/6,
           selectView/5]).


%%% UTILITARY FUNCTIONS %%%
% Sorts the view by decreasing order of freshness.
sort(View) ->
  % Anonymous sorting function, based on the freshness.
  Fun = fun({_, CycleA}, {_, CycleB}) -> CycleA >= CycleB end,
  lists:sort(Fun, View).

% Gets a random element from a list.
pickRandom(List) ->
  Rand = rand:uniform(length(List)),
  lists:nth(Rand, List).

% Permute: put the H oldest elements at the end,
% and the elements that will be sent at the beginning.
%   - Sort the list based on freshness
%   - Build a list with the H oldest elements (the last elements)
%   - Build a list without the H oldest elements (the first elements)
%   - Take 3 random elements from the second list, build a list with them
%   - Build the resulting list: Taken elements + remaining elements + old elements
permute(View, H) ->
  SortedView = sort(View),
  IndexH = length(SortedView) - H,
  OldestPeers = lists:nthtail(IndexH, SortedView),
  FreshestPeers = lists:sublist(SortedView, IndexH),
  {Taken, FRemaining, ORemaining} = takeNRandomPeers(FreshestPeers, OldestPeers, 3),
  Taken ++ FRemaining ++ ORemaining.

% Takes N random peers from the view, by starting with the freshest peers.
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
% A peer is a tuple {PeerId, Cycle}.
% The oldest peer is the one with the smallest Cycle.
pickOldestPeer(Peers) ->
  pickOldestPeer(Peers, {0, infinity}).
pickOldestPeer([{HId, HCycle}|T], {PeerId, Cycle}) ->
  if
    HCycle =< Cycle ->
      pickOldestPeer(T, {HId, HCycle});
    true ->
      pickOldestPeer(T, {PeerId, Cycle})
  end;
pickOldestPeer([], Peer) ->
  Peer.


%%% VIEW PROPAGATION %%%

% Propagates a view, either following the push or the pushpull strategy.
propagateView(FromPid, PeerPid, Cycle, View, {push, H, _}) ->
  pushView(FromPid, PeerPid, Cycle, View, H);
propagateView(FromPid, PeerPid, Cycle, View, {pushpull, H, S}) ->
  pushPullView(FromPid, PeerPid, Cycle, View, {H, S}).

% Propagates the view by following the push strategy.
pushView(FromPid, PeerPid, Cycle, View, H) ->
  ThisPeer = {FromPid, Cycle},
  PermutedView = permute(View, H),
  ViewToSend = [ThisPeer] ++ lists:sublist(PermutedView, 3),
  PeerPid ! {FromPid, ViewToSend},
  View.

% Propagates the view by following the pushpull strategy.
pushPullView(FromPid, PeerPid, Cycle, View, {H, S}) ->
  pushView(FromPid, PeerPid, Cycle, View, H),
  receive
    {PeerPid, ReceivedView} ->
      selectView(FromPid, View, ReceivedView, H, S)
  end.

% Responds to the received message if the strategy is pushpull,
% then updates the local view with the received view.
receivedView(NodePid, View, _, _, ReceivedView, {push, H, S}) ->
  selectView(NodePid, View, ReceivedView, H, S);
receivedView(NodePid, View, FromPid, Cycle, ReceivedView, {pushpull, H, S}) ->
  pushView(NodePid, FromPid, Cycle, View, H),
  selectView(NodePid, View, ReceivedView, H, S).


%%% VIEW SELECTION %%%

% Updates the current view, based on the received view and the H and S parameters.
selectView(Pid, View, ReceivedView, H, S) ->
  FunRemovePid = fun({ElemPid, _}) -> ElemPid =/= Pid end,
  ReceivedViewWithoutPid = lists:filter(FunRemovePid, ReceivedView),
  FullView = View ++ ReceivedViewWithoutPid,
  FullViewUnique = removeDuplicates(FullView),
  % Remove the H oldest peers, or until the view size is 7
  FullViewH = removeNOldest(FullViewUnique, max(0, min(H, length(FullViewUnique)-7))),
  % Remove the S first peers in the view, or until the view size is 7
  FullViewS = removeNFirst(FullViewH, max(0, min(S, length(FullViewH)-7))),
  % Remove random elements until the view size is 7
  randomReduceToN(FullViewS, 7).


% Removes the elements of the view that have the same Pid, but that are older.
keepFresher(View, Peer, Index) ->
  keepFresher(View, Peer, Index, 0, []).
keepFresher([], _, _, _, Acc) ->
  lists:reverse(Acc);
keepFresher([{BasePid, BaseCycle}|T], {BasePid, BaseCycle}, BaseIndex, CurIndex, Acc) ->
  if
    CurIndex > BaseIndex ->
      keepFresher(T, {BasePid, BaseCycle}, BaseIndex, CurIndex+1, Acc);
    true ->
      keepFresher(T, {BasePid, BaseCycle}, BaseIndex, CurIndex+1, [{BasePid, BaseCycle}|Acc])
  end;
keepFresher([{BasePid, CurCycle}|T], {BasePid, BaseCycle}, BaseIndex, CurIndex, Acc) ->
  if
    CurCycle < BaseCycle ->
      keepFresher(T, {BasePid, BaseCycle}, BaseIndex, CurIndex+1, Acc);
    true ->
      keepFresher(T, {BasePid, BaseCycle}, BaseIndex, CurIndex+1, [{BasePid, CurCycle}|Acc])
  end;
keepFresher([H|T], Peer, BaseIndex, CurIndex, Acc) ->
  keepFresher(T, Peer, BaseIndex, CurIndex+1, [H|Acc]).

% Removes duplicates of the same Pid, by keeping the freshest one.
removeDuplicates(View) ->
  removeDuplicates(View, 0, View).
removeDuplicates([], _, ResultView) ->
  ResultView;
removeDuplicates([H|T], Index, ResultView) ->
  removeDuplicates(T, Index+1, keepFresher(ResultView, H, Index)).

% Removes the oldest Peer from the view.
removeOldest(View) ->
  removeOldest(View, View, {0, infinity}).
removeOldest(BaseView, [], Oldest) ->
  lists:delete(Oldest, BaseView);
removeOldest(BaseView, [{Pid, Cycle}|T], {OldestPid, OldestCycle}) ->
  if
    Cycle =< OldestCycle ->
      removeOldest(BaseView, T, {Pid, Cycle});
    true ->
      removeOldest(BaseView, T, {OldestPid, OldestCycle})
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
