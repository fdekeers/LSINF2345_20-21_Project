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
  N = round(0.4 * length(AllNodes)),
  {ActiveNodes, InactiveNodes} = startNodes(N, 0, [], AllNodes),
  scenario(AllNodes, ActiveNodes, InactiveNodes, 1);

scenario(AllNodes, ActiveNodes, InactiveNodes, 120) ->
  % 120th cycle
  % As 120 is divisible by 30, start 20% of the inactive nodes
  N1 = round(0.2 * length(InactiveNodes)),
  {NewActiveNodes, NewInactiveNodes} = startNodes(N1, 120, ActiveNodes, InactiveNodes),

  % Crash a random number of active nodes, between 50 and 70% of the active nodes
  Ratio = (rand:uniform(21) + 49) / 100,
  N2 = round(Ratio * length(NewActiveNodes)),
  {NewActiveNodes2, NewInactiveNodes2} = crashNodes(N2, NewActiveNodes, NewInactiveNodes),
  scenario(AllNodes, NewActiveNodes2, NewInactiveNodes2, 121);

scenario(_, _, _, 180) ->
  % End of the scenario
  stop;

scenario(AllNodes, ActiveNodes, InactiveNodes, Cycle) ->
  DivisibleBy30 = Cycle rem 30 =:= 0,
  if
    DivisibleBy30 ->
      % Growing phase, start 20% of the inactive nodes
      N = round(0.2 * length(InactiveNodes)),
      {NewActiveNodes, NewInactiveNodes} = startNodes(N, Cycle, ActiveNodes, InactiveNodes),
      scenario(AllNodes, NewActiveNodes, NewInactiveNodes, Cycle+1);
    true ->
      % Nothing special to do
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
  NodePid ! {active, Cycle},
  NewActiveNodes = [{NodeId, NodePid}|ActiveNodes],
  startNodes(N-1, Cycle, NewActiveNodes, NewInactiveNodes).

% Crashes N nodes, and updates the active and inactive nodes lists.
crashNodes(0, ActiveNodes, InactiveNodes) ->
  {ActiveNodes, InactiveNodes};
crashNodes(N, ActiveNodes, InactiveNodes) ->
  {NodeId, NodePid} = utils:pickRandom(ActiveNodes),
  NewActiveNodes = lists:delete({NodeId, NodePid}, ActiveNodes),
  NodePid ! {kill},
  NewInactiveNodes = [{NodeId, NodePid}|InactiveNodes],
  crashNodes(N-1, NewActiveNodes, NewInactiveNodes).
