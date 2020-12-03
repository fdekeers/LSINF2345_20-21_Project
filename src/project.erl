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
  scenario(Nodes, [], Nodes, 0).

scenario(AllNodes, [], AllNodes, 0) ->
  % First cycle, bootstrapping phase
  N = round(math:ceil(0.4 * length(AllNodes))),
  {ActiveNodes, InactiveNodes} = startNodes(N, 0, [], AllNodes),
  io:format("Cycle ~p, ~p active nodes~n", [0, length(ActiveNodes)]),
  activateNodes(ActiveNodes, 0),
  scenario(AllNodes, ActiveNodes, InactiveNodes, 1);

scenario(AllNodes, ActiveNodes, InactiveNodes, 120) ->
  % 120th cycle
  % As 120 is divisible by 30, start 20% of the inactive nodes
  N1 = round(math:ceil(0.2 * length(InactiveNodes))),
  {NewActiveNodes, NewInactiveNodes} = startNodes(N1, 120, ActiveNodes, InactiveNodes),

  % Crash a random number of active nodes, between 50 and 70% of the active nodes
  Ratio = (rand:uniform(21) + 49) / 100,
  N2 = round(math:ceil(Ratio * length(NewActiveNodes))),
  {NewActiveNodes2, NewInactiveNodes2} = crashNodes(N2, NewActiveNodes, NewInactiveNodes),

  % Activate active nodes
  io:format("Cycle ~p, ~p active nodes~n", [120, length(NewActiveNodes2)]),
  activateNodes(NewActiveNodes2, 120),
  scenario(AllNodes, NewActiveNodes2, NewInactiveNodes2, 121);

scenario(_, ActiveNodes, _, 180) ->
  % End of the scenario
  io:format("Cycle ~p, ~p active nodes~n", [180, length(ActiveNodes)]),
  stop;

scenario(AllNodes, ActiveNodes, InactiveNodes, Cycle) ->
  % General case
  DivisibleBy30 = Cycle rem 30 =:= 0,
  if
    DivisibleBy30 ->
      % Growing phase, start 20% of the inactive nodes
      N = round(math:ceil(0.2 * length(InactiveNodes))),
      {NewActiveNodes, NewInactiveNodes} = startNodes(N, Cycle, ActiveNodes, InactiveNodes),
      % Activate active nodes
      io:format("Cycle ~p, ~p active nodes~n", [Cycle, length(NewActiveNodes)]),
      activateNodes(NewActiveNodes, Cycle),
      scenario(AllNodes, NewActiveNodes, NewInactiveNodes, Cycle+1);
    true ->
      % Nothing special to do, only activate active nodes
      io:format("Cycle ~p, ~p active nodes~n", [Cycle, length(ActiveNodes)]),
      activateNodes(ActiveNodes, Cycle),
      scenario(AllNodes, ActiveNodes, InactiveNodes, Cycle+1)
  end.
  %timer:sleep(3000),


% Starts N nodes, and updates the active and inactive nodes lists.
startNodes(0, _, ActiveNodes, InactiveNodes) ->
  {ActiveNodes, InactiveNodes};
startNodes(N, Cycle, ActiveNodes, InactiveNodes) ->
  {NodeId, NodePid} = utils:pickRandom(InactiveNodes),
  NewInactiveNodes = lists:delete({NodeId, NodePid}, InactiveNodes),
  NodePid ! {start},
  NewActiveNodes = [{NodeId, NodePid}|ActiveNodes],
  startNodes(N-1, Cycle, NewActiveNodes, NewInactiveNodes).

% Activate all the active nodes, i.e. start the active thread of each node
% This function is called at every cycle.
activateNodes(ActiveNodes, Cycle) ->
  FunActivate = fun({_, Pid}) -> Pid ! {active, Cycle} end,
  lists:foreach(FunActivate, ActiveNodes).

% Crashes N nodes, and updates the active and inactive nodes lists.
crashNodes(0, ActiveNodes, InactiveNodes) ->
  {ActiveNodes, InactiveNodes};
crashNodes(N, ActiveNodes, InactiveNodes) ->
  {NodeId, NodePid} = utils:pickRandom(ActiveNodes),
  NewActiveNodes = lists:delete({NodeId, NodePid}, ActiveNodes),
  NodePid ! {kill},
  NewInactiveNodes = [{NodeId, NodePid}|InactiveNodes],
  crashNodes(N-1, NewActiveNodes, NewInactiveNodes).
