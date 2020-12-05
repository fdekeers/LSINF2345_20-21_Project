- module(node).
- import(utils, [selectPeer/2, propagateView/3]).
- export([join/1,
          getNeigs/2,
          listen/4,
          log/3]).

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
      % Active section, selects the peer to contact, the subset of the
      % view to send, and send it.
      {_, PeerPid, _} = utils:selectPeer(View, Selection),
      {PermutedView, Buffer} = utils:selectBuffer(NodeId, self(), Cycle, View, H),
      PeerPid ! {push, self(), Cycle, Buffer},
      NewView = listen(NodeId, waiting, PermutedView, {Selection, Propagation, H, S}),
      log(Cycle, NodeId, NewView),
      listen(NodeId, up, NewView, {Selection, Propagation, H, S});
    {kill} ->
      % Stop the peer-sampling service on the node
      listen(NodeId, down, View, {Selection, Propagation, H, S})
  end;

% Passive section, node has sent its message and waits for a response.
% Returns the new view after having handled all the received messages.
listen(NodeId, waiting, View, {Selection, Propagation, H, S}) ->
  receive
    {push, FromPid, Cycle, ReceivedBuffer} ->
      % Passive section, updates local view with received view.
      % If strategy is pushpull, first respond to sender with local buffer.
      NewView = utils:receivedBuffer(NodeId, self(), FromPid, Cycle, View, ReceivedBuffer, {Propagation, H, S}),
      listen(NodeId, waiting, NewView, {Selection, Propagation, H, S});

    {response, ReceivedBuffer} ->
      % Received response to pushpull message, updates local view.
      NewView = utils:selectView(self(), View, ReceivedBuffer, H, S),
      listen(NodeId, waiting, NewView, {Selection, Propagation, H, S})
  after 1500 ->
    View
  end.


%%% LOGS %%%

% Logs the cycle, the node ID, and the node's full view.
log(Cycle, NodeId, View) ->
  io:format("~p;~p;~p~n", [Cycle, NodeId, viewToLog(View)]).

% Converts the view into a printable list of peer IDs.
viewToLog(View) ->
  viewToLog(View, []).
viewToLog([], Acc) ->
  lists:reverse(Acc);
viewToLog([{PeerId, _, _}|T], Acc) ->
  viewToLog(T, [PeerId|Acc]).
