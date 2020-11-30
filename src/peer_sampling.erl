- module (peer_sampling).
- export ([selectPeer/2]).

% Updates the view of a node.
%   NodeId: node to update the view
%   Peers: view of this node
%   Selection: rand or tail, defines if the neighbour to gossip with is chosen
%              at random or if it will be the oldest one.
%   Propagation: push or pushpull, defines if the node sends its local view or
%                exchanges it.
%   Selection
%getPeer(NodeId, Peers, Selection, Propagation, Selection) ->



%%% PEER SELECTION %%%

% Selects a peer from the view.
% The strategy can be rand or tail.
% If rand, a random peer is selected.
% If tail, the oldest peer is selected, which is the last one in the list.
selectPeer(Peers, rand) ->
  Rand = rand:uniform(length(Peers)),
  pickPeerN(Peers, Rand-1);
selectPeer(Peers, tail) ->
  pickPeerN(Peers, length(Peers)-1).

% Returns the node at index N in the list of peers (index starts at 0).
pickPeerN([H|_], 0) ->
  H;
pickPeerN([_|T], N) ->
  pickPeerN(T, N-1).


%%% VIEW PROPAGATION %%%

pushView(PeerPid, View) ->
  PeerPid ! {push, View}.

pushPullView(PeerPid, View) ->
  PeerPid ! {pushpull, View},
  receive
    {response, View} -> View
  end.
