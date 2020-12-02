- module (utils).
- export ([selectPeer/2, propagateView/5, removeHOldest/2]).

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
  {PeerPid, _} = Peer,
  takeNRandomPeers([], NewOldestPeers, N-1, [PeerPid|Acc]);
% Take from the freshest peers.
takeNRandomPeers(FreshestPeers, OldestPeers, N, Acc) ->
  Peer = pickRandom(FreshestPeers),
  NewFreshestPeers = lists:delete(Peer, FreshestPeers),
  {PeerPid, _} = Peer,
  takeNRandomPeers(NewFreshestPeers, OldestPeers, N-1, [PeerPid|Acc]).

% Adds the cycle to the list of peers.
setCycle(Peers, Cycle) ->
  setCycle(Peers, Cycle, []).
setCycle([], _, Acc) ->
  lists:reverse(Acc);
setCycle([H|T], Cycle, Acc) ->
  setCycle(T, Cycle, [{H, Cycle}|Acc]).


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
pickOldestPeer([], {PeerId, Cycle}) ->
  {PeerId, Cycle}.


%%% VIEW PROPAGATION %%%
propagateView(FromPid, PeerPid, Cycle, View, {push, H, _}) ->
  pushView(FromPid, PeerPid, Cycle, View, H);
propagateView(FromPid, PeerPid, Cycle, View, {pushpull, H, S}) ->
  pushPullView(FromPid, PeerPid, Cycle, View, {H, S}).

pushView(FromPid, PeerPid, Cycle, View, H) ->
  PermutedView = permute(View, H),
  PeersToSend = lists:sublist(PermutedView, 3),
  PeerPid ! {FromPid, Cycle, PeersToSend}.

pushPullView(FromPid, PeerPid, Cycle, View, {H, S}) ->
  pushView(FromPid, PeerPid, Cycle, View, H),
  receive
    {PeerPid, PeerCycle, PeersSent} ->
      PeerView = setCycle(PeersSent, PeerCycle),
      selectView(View, PeerView, H, S)
  end.


%%% VIEW SELECTION %%%
selectView(View, PeerView, H, S) ->
  FullView = View ++ PeerView,
  FullViewUnique = removeDuplicates(FullView).

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

% Removes the H oldest peers from the view.
removeHOldest(View, H) ->
  2.

% Removes the S first peers from the view.
removeSFirst(View, S) ->
  lists:nthtail(length(View)-S-1, View).
