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
  utils:propagateView(FromPid, PeerPid, Cycle, View, {Propagation, H}),
  loop({NodeId, NodePid}, NewView, Cycle + 1, {Selection, Propagation, H, S}).


% Passive thread
listen() ->
  receive
    {push, View, FromPid} ->

    {pushpull, View, FromPid} ->


    kill -> ok
  end.
