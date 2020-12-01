- module(bootstrap_server).
- import(tree, [add/2, getNeigs/2]).
- export([listen/2]).

listen(NodeId, Struct) ->
  %io:format("Bootstrap server is listening...~n", []),
  receive
    { join, From } ->
      NewStruct = tree:add(NodeId, Struct),
      %io:format("Latest tree: ~p~n", [ NewStruct ]),
      From ! { joinOk, NodeId },
      listen(NodeId + 1, NewStruct);
    { getPeers, { From, ForNodeId } } ->
      Neigs = tree:getNeigs(ForNodeId, Struct),
      From ! { getPeersOk, { Neigs }  },
      listen(NodeId, Struct)
  end.
