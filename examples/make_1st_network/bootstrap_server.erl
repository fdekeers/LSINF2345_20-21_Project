- module(bootstrap_server).
- import(tree, [add/2, getNeigs/2]).
- export([listen/2]).

listen(NodeId, Tree) ->
  io:format("Bootstrap server is listening...~n", []),
  receive
    { join, From } ->
      NewTree = tree:add(NodeId, Tree),
      io:format("Latest tree: ~p~n", [ NewTree ]),
      From ! { joinOk, NodeId },
      listen(NodeId + 1, NewTree);
    { getPeers, { From, ForNodeId } } ->
      Neigs = tree:getNeigs(ForNodeId, Tree),
      From ! { getPeersOk, { Neigs }  },
      listen(NodeId, Tree)
  end.
