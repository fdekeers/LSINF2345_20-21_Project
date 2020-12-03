- module(bootstrap_server).
- import(tree, [add/2, getNeigs/2]).
- import(linkList, [search/3]).
- import(lists, [reverse/1]).
- export([listenT/2, listenL/2, start/0]).

start() ->
  L_PID = spawn(bootstrap_server, listenL, [0, []]),
  L_PID ! {join, self()},
  L_PID ! {join, self()},
  L_PID ! {getPeers, {self(), 0}},
  T_PID = spawn(bootstrap_server, listenT, [0 , {}]),
  T_PID ! {join, self()},
  T_PID ! {join, self()},
  T_PID ! {getPeers, {self(), 0}}.

listenT(NodeId, Tree) ->
  %io:format("Bootstrap server is listening...~n", []),
  receive
    { join, From } ->
      NewTree = tree:add(NodeId, Tree),
      %io:format("Latest tree: ~p~n", [ NewTree ]),
      From ! { joinOk, NodeId },
      listenT(NodeId + 1, NewTree);
    { getPeers, { From, ForNodeId } } ->
      Neigs = tree:getNeigs(ForNodeId, Tree),
      %io: format("Neighbors are ~p~n", [Neigs]),
      From ! { getPeersOk, { Neigs }  },
      listenT(NodeId, Tree)
  end.

listenL(NodeId, H) ->
  %io:format("Bootstrap server is listening...~n", []),
  receive
    { join, From } ->
        %io: format("Latest list is ~p~n", [[NodeId]++H]),
        From ! { joinOk, NodeId },
        listenL(NodeId + 1 , [NodeId]++H);
    { getPeers, { From, ForNodeId } } ->
        Neigs = [linkList:search(H, ForNodeId, false), linkList:search(reverse(H), ForNodeId, false)],
        %io: format("Neighbors are ~p~n", [Neigs]),
        From ! {getPeersOk, { Neigs } },
        listenL(NodeId, H)
  end.
