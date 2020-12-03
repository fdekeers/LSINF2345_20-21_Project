- module(node).
- import(utils, [selectPeer/2, propagateView/3]).
- export([join/1, getNeigs/2, listen/3]).

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


%%% PEER SAMPLING SERVICE %%%

listen({NodeId, NodePid}, View, {Selection, Propagation, H, S}) ->
  receive
    {active, Cycle} ->
      % First active section, selects the peer to contact, the subset of the
      % view to send, and send it.
      {PeerPid, _} = utils:selectPeer(View, Selection),
      Buffer = utils:selectBuffer(NodePid, Cycle, View, H),
      PeerPid ! {push, FromPid, Cycle, Buffer},
      listen({NodeId, NodePid}, View, {Selection, Propagation, H, S});

    {push, FromPid, Cycle, ReceivedBuffer} ->
      % Passive section, updates local view with received view.
      % If strategy is pushpull, first respond to sender with local buffer.
      NewView = utils:receivedBuffer(NodePid, FromPid, Cycle, View, ReceivedBuffer, {Propagation, H, S}),
      listen({NodeId, NodePid}, NewView, {Selection, Propagation, H, S});

    {response, ReceivedBuffer} ->
      % Received response to pushpull message, updates local view.
      NewView = utils:selectView(NodePid, View, ReceivedBuffer, H, S),
      listen({NodeId, NodePid}, NewView, {Selection, Propagation, H, S})
    end.
