- module(node).
- import(utils, [selectPeer/2, propagateView/3]).
- export([join/1, getNeigs/2, loop/4, listen/0]).

join(BootServerPid) ->
  BootServerPid ! { join, self() },
  receive
    { joinOk, NodeId } ->
      NodeId
  end.

getNeigs(BootServerPid, NodeId) ->
  BootServerPid ! { getPeers, { self(), NodeId } },
  receive
    { getPeersOk, Neigs } -> Neigs
  end.


%%% PEER SAMPLING %%%

% Active thread
loop({NodeId, NodePid}, View, Cycle, {Selection, Propagation, H, S}) ->
  timer:sleep(3000),
  {PeerPid, _} = utils:selectPeer(View, Selection),
  NewView = utils:propagateView(NodePid, PeerPid, Cycle, View, {Propagation, H, S),
  loop({NodeId, NodePid}, NewView, Cycle + 1, {Selection, Propagation, H, S}).


% Passive thread
listen({NodeId, NodePid}, View, {Propagation, H, S}) ->
  receive
    {FromPid, Cycle, ReceivedPeers} ->
      utils:receivedView(NodePid, View, FromPid, Cycle, ReceivedPeers, {Propagation, H, S});
    kill -> ok
  end.
