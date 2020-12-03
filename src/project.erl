- module(project).
- import(bootstrap_server, [listen/2]).
- import(node, [join/2, getNeigs/3, listen/3]).
- export([launch/3]).

% Creates the initial network, and return a list of all the nodes with their Pid.
% More "Erlang-friendly" adaptation of the initial makeNet function.
makeNet(N, BootServerPid, Params) ->
  makeNet(N, BootServerPid, Params, []).
makeNet(0, _, _, Nodes) ->
  lists:reverse(Nodes);
makeNet(N, BootServerPid, Params, Nodes) ->
  NodeId = node:join(BootServerPid),
  NodePid = spawn(node, listen, [NodeId, [], Params]),
  Node = {NodeId, NodePid},
  makeNet(N-1, BootServerPid, Params, [Node|Nodes]).


%%% START THE PROJECT %%%

launch(tree, N, Params) ->
  % Creates server with an empty tree
  BootServerPid = spawn(bootstrap_server, listenT, [ 0, {} ]),
  Nodes = makeNet(N, BootServerPid, Params),
  FunInitNodes = fun({NodeId, NodePid}) ->
    {Neighbors} = node:getNeigs(BootServerPid, NodeId),
    io:format("Neighbors of ~p: ~p.~n", [NodeId, Neighbors])
  end,
  lists:foreach(FunInitNodes, Nodes).
