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
  scenario(Nodes, 1).
  %growingPhase(),
  %crashingPhase(),
  %recoveryPhase(),
  %stop().

% Applies the experimental scenario, as described in the project statement.
scenario(Nodes, 1) ->
  scenario(Nodes, [], 1).
scenario(AllNodes, [], 1) ->
  % First cycle, bootstrapping phase
  ActiveNodes = bootstrappingPhase(AllNodes),
  scenario(AllNodes, ActiveNodes, 2);
scenario(_, _, 181) ->
  % End of the scenario
  stop;
scenario(AllNodes, ActiveNodes, Cycle) ->
  % Nothing special to do
  %timer:sleep(3000),
  scenario(AllNodes, ActiveNodes, Cycle+1).

% Launches the bootstrapping phase:
% Start 40% of the nodes.
bootstrappingPhase(Nodes) ->
  % Number of nodes that are launched during the bootstrapping phase (40%)
  N = round(0.4 * length(Nodes)),
  bootstrappingPhase(Nodes, N, []).
bootstrappingPhase(_, 0, ActiveNodes) ->
  ActiveNodes;
bootstrappingPhase(Nodes, N, ActiveNodes) ->
  {NodeId, NodePid} = utils:pickRandom(Nodes),
  NewNodes = lists:delete({NodeId, NodePid}, Nodes),
  NodePid ! {active, 1},
  bootstrappingPhase(NewNodes, N-1, [{NodeId, NodePid}|ActiveNodes]).
