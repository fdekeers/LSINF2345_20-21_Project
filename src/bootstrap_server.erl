- module(bootstrap_server).
- import(tree, [add/2, getNeigs/2]).
- import(linked_list, [search/3]).
- import(lists, [reverse/1]).
- import(timer, [sleep/1]).
- export([listenT/2, listenL/2, testL/0, testT/0]).


%%% SERVER FUNCTIONS %%%

listenT(NodeId, Tree) ->
  %io:format("Bootstrap tree server is listening...~p~n", [Tree]),
  receive
    { join, From } ->
      NewTree = tree:add(NodeId, Tree),
      From ! { joinOk, NodeId },
      listenT(NodeId + 1, NewTree);
    { getPeers, { From, ForNodeId } } ->
      Neigs = tree:getNeigs(ForNodeId, Tree),
      %io: format("Neighbors are ~p~n", [Neigs]),
      From ! { getPeersOk, { Neigs }  },
      listenT(NodeId, Tree)
  end.

listenL(NodeId, H) ->
  %io:format("Bootstrap list server is listening...~p~n", [H]),
  receive
    { join, From } ->
        From ! { joinOk, NodeId },
        listenL(NodeId + 1 , [NodeId]++H);
    { getPeers, { From, ForNodeId } } ->
        Neigs = [linked_list:search(H, ForNodeId, false), linked_list:search(reverse(H), ForNodeId, false)],
        %io: format("Neighbors are ~p~n", [Neigs]),
        From ! {getPeersOk, { Neigs } },
        listenL(NodeId, H)
  end.


%%% UNIT TESTS %%%

testL() ->
  L_PID = spawn(bootstrap_server, listenL, [0, []]),
  L_PID ! {join, self()},
  receive
    {joinOk, NodeID0} ->
      io:format("~p added to list (expected 0), test passed: ~p ~n", [NodeID0, NodeID0 =:= 0])
  end,
  timer:sleep(1000),

  L_PID ! {join, self()},
  receive
    {joinOk, NodeID1} ->
      io:format("~p added to list (expected 1), test passed: ~p ~n", [NodeID1, NodeID1 =:= 1])
  end,
  timer:sleep(1000),

  L_PID ! {getPeers, {self(), 0}},
  receive
    {getPeersOk, {PeerID0}} ->
      io:format("~p are the Neighbors of 0 (expected [nil,1]), test passed: ~p ~n", [PeerID0, PeerID0 =:= [nil,1]])
  end,
  timer:sleep(1000),

  L_PID ! {getPeers, {self(), 1}},
  receive
    {getPeersOk, {PeerID1}} ->
      io:format("~p are the Neighbors of 1 (expected [0,nil]), test passed: ~p ~n", [PeerID1, PeerID1 =:= [0,nil]])
  end,
  timer:sleep(1000),

  L_PID ! {join, self()},
  receive
    {joinOk, NodeID2} ->
      io:format("~p added to list (expected 2), test passed: ~p ~n", [NodeID2, NodeID2 =:= 2])
  end,
  timer:sleep(1000),

  L_PID ! {join, self()},
  receive
    {joinOk, NodeID3} ->
      io:format("~p added to list (expected 3), test passed: ~p ~n", [NodeID3, NodeID3 =:= 3])
  end,
  timer:sleep(1000),

  L_PID ! {getPeers, {self(), 0}},
  receive
    {getPeersOk, {PeerID0b}} ->
      io:format("~p are the Neighbors of 0 (expected [nil,1]), test passed: ~p ~n", [PeerID0b, PeerID0b =:= [nil,1]])
  end,
  timer:sleep(1000),

  L_PID ! {getPeers, {self(), 1}},
  receive
    {getPeersOk, {PeerID1b}} ->
      io:format("~p are the Neighbors of 1 (expected [0,2]), test passed: ~p ~n", [PeerID1b, PeerID1b =:= [0,2]])
  end,
  timer:sleep(1000),

  L_PID ! {getPeers, {self(), 2}},
  receive
    {getPeersOk, {PeerID2}} ->
      io:format("~p are the Neighbors of 2 (expected [1,3]), test passed: ~p ~n", [PeerID2, PeerID2 =:= [1,3]])
  end,
  timer:sleep(1000),

  L_PID ! {getPeers, {self(), 3}},
  receive
    {getPeersOk, {PeerID3}} ->
      io:format("~p are the Neighbors of 3 (expected [2,nil]), test passed: ~p ~n", [PeerID3, PeerID3 =:= [2,nil]])
  end,
  io:format("End of list tests ~n", []).

testT() ->

  T_PID = spawn(bootstrap_server, listenT, [0 , {}]),
  T_PID ! {join, self()},
  receive
    {joinOk, NodeID0T} ->
      io:format("~p added to tree (expected 0), test passed: ~p ~n", [NodeID0T, NodeID0T =:= 0])
  end,
  timer:sleep(1000),

  T_PID ! {join, self()},
  receive
    {joinOk, NodeID1T} ->
      io:format("~p added to tree (expected 1), test passed: ~p ~n", [NodeID1T, NodeID1T =:= 1])
  end,
  timer:sleep(1000),

  T_PID ! {getPeers, {self(), 0}},
  receive
    {getPeersOk, {PeerID0T}} ->
      io:format("~p are the Neighbors of 0 (expected [1]), test passed: ~p ~n", [PeerID0T, PeerID0T =:= [1]])
  end,
  timer:sleep(1000),

  T_PID ! {getPeers, {self(), 1}},
  receive
    {getPeersOk, {PeerID1T}} ->
      io:format("~p are the Neighbors of 1 (expected [0]), test passed: ~p ~n", [PeerID1T, PeerID1T =:= [0]])
  end,
  timer:sleep(1000),

  T_PID ! {join, self()},
  receive
    {joinOk, NodeID2T} ->
      io:format("~p added to tree (expected 2), test passed: ~p ~n", [NodeID2T, NodeID2T =:= 2])
  end,
  timer:sleep(1000),

  T_PID ! {join, self()},
  receive
    {joinOk, NodeID3T} ->
      io:format("~p added to tree (expected 3), test passed: ~p ~n", [NodeID3T, NodeID3T =:= 3])
  end,
  timer:sleep(1000),

  T_PID ! {getPeers, {self(), 0}},
  receive
    {getPeersOk, {PeerID0Tb}} ->
      io:format("~p are the Neighbors of 0 (expected [1,2]), test passed: ~p ~n", [PeerID0Tb, PeerID0Tb =:= [1,2]])
  end,
  timer:sleep(1000),

  T_PID ! {getPeers, {self(), 1}},
  receive
    {getPeersOk, {PeerID1Tb}} ->
      io:format("~p are the Neighbors of 1 (expected [0,3]), test passed: ~p ~n", [PeerID1Tb, PeerID1Tb =:= [0,3]])
  end,
  timer:sleep(1000),

  T_PID ! {getPeers, {self(), 2}},
  receive
    {getPeersOk, {PeerID2T}} ->
      io:format("~p are the Neighbors of 2 (expected [0]), test passed: ~p ~n", [PeerID2T, PeerID2T =:= [0]])
  end,
  timer:sleep(1000),

  T_PID ! {getPeers, {self(), 3}},
  receive
    {getPeersOk, {PeerID3T}} ->
      io:format("~p are the Neighbors of 3 (expected [1]), test passed: ~p ~n", [PeerID3T, PeerID3T =:= [1]])
  end,

  io:format("End of tree tests ~n", []).
