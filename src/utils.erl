- module (utils).
- export ([selectPeer/2, pushView/5]).

% Updates the view of a node.
%   NodeId: node to update the view
%   Peers: view of this node
%   Selection: rand or tail, defines if the neighbour to gossip with is chosen
%              at random or if it will be the oldest one.
%   Propagation: push or pushpull, defines if the node sends its local view or
%                exchanges it.
%   Selection
%getPeer(NodeId, Peers, Selection, Propagation, Selection) ->

% Permute: put the H oldest elements at the end,
% and the elements that will be sent at the beginning.
%   - Sort the list based on freshness
%   - Build a list with the H oldest elements (the last elements)
%   - Build a list without the H oldest elements (the first elements)
%   - Take 3 random elements from the second list, build a list with them
%   - Build the resulting list: Taken elements + remaining elements + old elements

% Sorts the view by decreasing order of freshness.
sort(View) ->
  % Anonymous sorting function, based on the freshness.
  Fun = fun({_, CycleA}, {_, CycleB}) -> CycleA >= CycleB end,
  lists:sort(Fun, View).

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
  {PeerPid, Cycle} = Peer,
  takeNRandomPeers([], NewOldestPeers, N-1, [PeerPid|Acc]);
% Take from the freshest peers.
takeNRandomPeers(FreshestPeers, OldestPeers, N, Acc) ->
  Peer = pickRandom(FreshestPeers),
  NewFreshestPeers = lists:delete(Peer, FreshestPeers),
  {PeerPid, Cycle} = Peer,
  takeNRandomPeers(NewFreshestPeers, OldestPeers, N-1, [PeerPid|Acc]).


% Gets a random element from a list.
pickRandom(List) ->
  Rand = rand:uniform(length(List)),
  lists:nth(Rand, List).


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
propagateView(FromPid, PeerPid, Cycle, View, {push, H}) ->
  pushView(FromPid, PeerPid, Cycle, View, H);
propagateView(FromPid, PeerPid, Cycle, View, {pushpull, H}) ->
  pushView(FromPid, PeerPid, Cycle, View, H).

pushView(FromPid, PeerPid, Cycle, View, H) ->
  PermutedView = permute(View, H),
  PeersToSend = lists:sublist(PermutedView, 3),
  PeerPid ! {push, {FromPid, Cycle, PeersToSend}}.

pushPullView(FromPid, PeerPid, Cycle, View, H) ->
  PeerPid ! {pushpull, View, FromPid},
  receive
    {response, View} -> View
  end.
