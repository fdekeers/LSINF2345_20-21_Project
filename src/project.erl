- module(project).
- import(bootstrap_server, [listen/2]).
- import(node, [join/2, getNeigs/3, listen/4]).
- export([launch/3]).

% Creates the initial network, and return a list of all the nodes with their Pid.
% More "Erlang-friendly" adaptation of the initial makeNet function.
makeNet(N, BootServerPid, Params) ->
  makeNet(N, BootServerPid, Params, []).
makeNet(0, _, _, Nodes) ->
  lists:reverse(Nodes);
makeNet(N, BootServerPid, Params, Nodes) ->
  NodeId = node:join(BootServerPid),
  NodePid = spawn(node, listen, [NodeId, down, [], Params]),
  Node = {NodeId, NodePid},
  makeNet(N-1, BootServerPid, Params, [Node|Nodes]).

% Initialize each node's view, which contains its neighbors in the data structure.
initializeViews(BootServerPid, Nodes) ->
  FunInitNodes = fun({NodeId, NodePid}) ->
    {Neighbors} = node:getNeigs(BootServerPid, NodeId),
    InitView = utils:buildInitView(Nodes, Neighbors),
    NodePid ! {init, InitView}
  end,
  lists:foreach(FunInitNodes, Nodes).


%%% START THE PROJECT %%%

launch(tree, N, Params) ->
  % Create server with an empty tree
  BootServerPid = spawn(bootstrap_server, listenT, [ 0, {} ]),
  % Add all the nodes to the data structure
  Nodes = makeNet(N, BootServerPid, Params),
  % Initialize nodes view
  initializeViews(BootServerPid, Nodes),

  % Experimental scenario
  scenario(Nodes).
  %growingPhase(),
  %crashingPhase(),
  %recoveryPhase(),
  %stop().

% Applies the experimental scenario, as described in the project statement.
scenario(Nodes) ->
  scenario(Nodes, [], Nodes, 1).
scenario(AllNodes, [], AllNodes, 1) ->
  % First cycle, bootstrapping phase
  N = round(0.4 * length(AllNodes)),
  {ActiveNodes, InactiveNodes} = startNodes(N, [], AllNodes),
  io:format("Active nodes: ~p~n", [ActiveNodes]),
  io:format("Inactive nodes: ~p~n", [InactiveNodes]),
  scenario(AllNodes, ActiveNodes, InactiveNodes,  2);
scenario(_, _, _, 181) ->
  % End of the scenario
  stop;
scenario(AllNodes, ActiveNodes, InactiveNodes, Cycle) ->
  % Nothing special to do
  %timer:sleep(3000),
  scenario(AllNodes, ActiveNodes, InactiveNodes, Cycle+1).

% Starts N nodes, and updates the active and inactive nodes lists.
startNodes(0, ActiveNodes, InactiveNodes) ->
  {ActiveNodes, InactiveNodes};
startNodes(N, ActiveNodes, InactiveNodes) ->
  {NodeId, NodePid} = utils:pickRandom(InactiveNodes),
  NewInactiveNodes = lists:delete({NodeId, NodePid}, InactiveNodes),
  NodePid ! {start},
  NodePid ! {active, 1},
  NewActiveNodes = [{NodeId, NodePid}|ActiveNodes],
  startNodes(N-1, NewActiveNodes, NewInactiveNodes).
