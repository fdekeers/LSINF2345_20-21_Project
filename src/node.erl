- module(node).
- import(utils, [selectPeer/2, propagateView/3]).
- export([join/1, getNeigs/2, listen/4]).

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

% Node has not started the peer-sampling service yet
listen(NodeId, down, View, {Selection, Propagation, H, S}) ->
  receive
    {init, InitView} ->
      % Initialization of the node's view.
      listen(NodeId, down, InitView, {Selection, Propagation, H, S});

    {start} ->
      % Start of the peer-sampling service
      listen(NodeId, up, View, {Selection, Propagation, H, S})
  end;

% Node is running the peer-sampling service
listen(NodeId, up, View, {Selection, Propagation, H, S}) ->
  receive
    {active, Cycle} ->
      io:format("Node ~p active~n", [self()]),
      % Active section, selects the peer to contact, the subset of the
      % view to send, and send it.
      {PeerPid, _} = utils:selectPeer(View, Selection),
      {PermutedView, Buffer} = utils:selectBuffer(self(), Cycle, View, H),
      PeerPid ! {push, self(), Cycle, Buffer},
      listen(NodeId, up, PermutedView, {Selection, Propagation, H, S});

    {push, FromPid, Cycle, ReceivedBuffer} ->
      io:format("Node ~p received push from node ~p~n", [self(), FromPid]),
      io:format("Node ~p local view:    ~p~n", [self(), View]),
      io:format("Node ~p received view: ~p~n", [self(), ReceivedBuffer]),
      % Passive section, updates local view with received view.
      % If strategy is pushpull, first respond to sender with local buffer.
      NewView = utils:receivedBuffer(self(), FromPid, Cycle, View, ReceivedBuffer, {Propagation, H, S}),
      io:format("Node ~p updated view:  ~p~n", [self(), NewView]),
      listen(NodeId, up, NewView, {Selection, Propagation, H, S});

    {response, ReceivedBuffer} ->
      io:format("Node ~p received response~n", [self()]),
      % Received response to pushpull message, updates local view.
      NewView = utils:selectView(self(), View, ReceivedBuffer, H, S),
      listen(NodeId, up, NewView, {Selection, Propagation, H, S});

    {kill} ->
      % Stop the peer-sampling service on the node
      listen(NodeId, down, View, {Selection, Propagation, H, S})
  end.
