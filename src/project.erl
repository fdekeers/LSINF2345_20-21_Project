- module(project).
- import(bootstrap_server, [listen/2]).
- import(node, [join/2, getNeigs/3, listen/4]).
- export([launch/3, main/1]).

%%% MAIN FUNCTION %%%
% Launches the program with the command line arguments,
% which are specified in the following order:
%   - N (int): maximum number of nodes in the network
%   - Struct (atom): tree or linked_list, specifies the data structure to use
%   - ViewSize (int): maximum size of the view
%   - Selection (atom): tail or rand, specifies the peer selection
%   - Propagation (atom): push or pushpull, specifies the peer selection
%   - H (int): self-healing parameter
%   - S (int): swapping parameter
main(Args) ->
  [NStr, StructStr, SizeStr, SelectionStr, PropagationStr, HStr, SStr] = Args,
  % Convert arguments, that are all strings, to the correct data type
  N = list_to_integer(NStr),
  Struct = list_to_atom(StructStr),
  ViewSize = list_to_integer(SizeStr),
  Selection = list_to_atom(SelectionStr),
  Propagation = list_to_atom(PropagationStr),
  H = list_to_integer(HStr),
  S = list_to_integer(SStr),
  Params = {ViewSize, Selection, Propagation, H, S},
  % Launch the project
  launch(N, Struct, Params).

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

% Starts the project with a binary tree as initial data structure.
launch(N, tree, Params) ->
  % Create server with an empty tree
  BootServerPid = spawn(bootstrap_server, listenT, [ 0, {} ]),
  % Add all the nodes to the data structure
  Nodes = makeNet(N, BootServerPid, Params),
  % Initialize nodes view
  initializeViews(BootServerPid, Nodes),
  % Experimental scenario
  scenario(Nodes);
% Starts the project with a double linked list as initial data structure.
launch(N, linked_list, Params) ->
  % Create server with an empty tree
  BootServerPid = spawn(bootstrap_server, listenL, [ 0, [] ]),
  % Add all the nodes to the data structure
  Nodes = makeNet(N, BootServerPid, Params),
  % Initialize nodes view
  initializeViews(BootServerPid, Nodes),
  % Experimental scenario
  scenario(Nodes).


% Applies the experimental scenario, as described in the project statement.
scenario(Nodes) ->
  scenario([], Nodes, 0).

scenario([], AllNodes, 0) ->
  % First cycle, bootstrapping phase
  N = round(trunc(0.4 * length(AllNodes))),
  {ActiveNodes, InactiveNodes} = startNodes(N, [], AllNodes),
  activateNodes(ActiveNodes, 0),
  timer:sleep(3000),
  scenario(ActiveNodes, InactiveNodes, 1);

scenario(ActiveNodes, InactiveNodes, 120) ->
  % 120th cycle, crash 60% of the active nodes
  N = round(trunc(0.6 * length(ActiveNodes))),
  {NewActiveNodes, NewInactiveNodes} = crashNodes(N, ActiveNodes, InactiveNodes),
  % Activate active nodes
  activateNodes(NewActiveNodes, 120),
  timer:sleep(3000),
  scenario(NewActiveNodes, NewInactiveNodes, 121);

scenario(ActiveNodes, InactiveNodes, 150) ->
  % 150th cycle, recovery phase
  N = round(trunc(0.6 * length(InactiveNodes))),
  {NodeId, NodePid} = utils:pickRandom(ActiveNodes),
  InitView = [{NodeId, NodePid, 150}],
  {NewActiveNodes, NewInactiveNodes} = restartNodes(N, ActiveNodes, InactiveNodes, InitView),
  % Activate active nodes
  activateNodes(NewActiveNodes, 150),
  timer:sleep(3000),
  scenario(NewActiveNodes, NewInactiveNodes, 151);

scenario(ActiveNodes, InactiveNodes, 180) ->
  % End of the scenario
  stopScenario(ActiveNodes, InactiveNodes),
  stop;

scenario(ActiveNodes, InactiveNodes, Cycle) ->
  % General case
  DivisibleBy30 = Cycle rem 30 =:= 0,
  if
    (Cycle =< 90) and (DivisibleBy30) ->
      % Growing phase, start 20% of the inactive nodes
      N = round(trunc(0.2 * (length(ActiveNodes)+length(InactiveNodes)))),
      {NewActiveNodes, NewInactiveNodes} = startNodes(N, ActiveNodes, InactiveNodes),
      % Activate active nodes
      activateNodes(NewActiveNodes, Cycle),
      timer:sleep(3000),
      scenario(NewActiveNodes, NewInactiveNodes, Cycle+1);
    true ->
      % Nothing special to do, only activate active nodes
      activateNodes(ActiveNodes, Cycle),
      timer:sleep(3000),
      scenario(ActiveNodes, InactiveNodes, Cycle+1)
  end.


% Starts N nodes with the initial view, and updates the active and inactive nodes lists.
startNodes(0, ActiveNodes, InactiveNodes) ->
  {ActiveNodes, InactiveNodes};
startNodes(_, ActiveNodes, []) ->
  {ActiveNodes, []};
startNodes(N, ActiveNodes, InactiveNodes) ->
  {NodeId, NodePid} = utils:pickRandom(InactiveNodes),
  NewInactiveNodes = lists:delete({NodeId, NodePid}, InactiveNodes),
  NodePid ! {start},
  NewActiveNodes = [{NodeId, NodePid}|ActiveNodes],
  startNodes(N-1, NewActiveNodes, NewInactiveNodes).

% Activate all the active nodes, i.e. start the active thread of each node
% This function is called at every cycle.
activateNodes(ActiveNodes, Cycle) ->
  FunActivate = fun({_, Pid}) -> Pid ! {active, Cycle} end,
  lists:foreach(FunActivate, ActiveNodes).

% Crashes N nodes, and updates the active and inactive nodes lists.
crashNodes(0, ActiveNodes, InactiveNodes) ->
  {ActiveNodes, InactiveNodes};
crashNodes(_, [], InactiveNodes) ->
  {[], InactiveNodes};
crashNodes(N, ActiveNodes, InactiveNodes) ->
  {NodeId, NodePid} = utils:pickRandom(ActiveNodes),
  NewActiveNodes = lists:delete({NodeId, NodePid}, ActiveNodes),
  NodePid ! {kill},
  NewInactiveNodes = [{NodeId, NodePid}|InactiveNodes],
  crashNodes(N-1, NewActiveNodes, NewInactiveNodes).

% Restarts N nodes, with the same initial view.
restartNodes(0, ActiveNodes, InactiveNodes, _) ->
  {ActiveNodes, InactiveNodes};
restartNodes(_, ActiveNodes, [], _) ->
  {ActiveNodes, []};
restartNodes(N, ActiveNodes, InactiveNodes, InitView) ->
  {NodeId, NodePid} = utils:pickRandom(InactiveNodes),
  NewInactiveNodes = lists:delete({NodeId, NodePid}, InactiveNodes),
  NodePid ! {init, InitView},
  NodePid ! {start},
  NewActiveNodes = [{NodeId, NodePid}|ActiveNodes],
  restartNodes(N-1, NewActiveNodes, NewInactiveNodes, InitView).

% Stops the scenario, sends the message stop to all nodes
stopScenario(ActiveNodes, InactiveNodes) ->
  FunStop = fun({_, NodePid}) -> NodePid ! {stop} end,
  lists:foreach(FunStop, ActiveNodes),
  lists:foreach(FunStop, InactiveNodes).
