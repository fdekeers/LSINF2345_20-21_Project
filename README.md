# LSINF2345 Project: The Peer Sampling Service (Group E)

We are the group E, composed of:
- BOGAERT Jérémie ()
- DE KEERSMAEKER François (7367-1600)

This report will present our work for the project for the course LSINF2345 -
Languages and Algorithms for Distributed Applications,
which covers the peer sampling service in a network of nodes.\
The contents of this report are the following:
- Deployment of a bootstrap network, with the help of a specific data structure;
- Peer sampling service implementation;
- Evaluation of the service with an experimental scenario.


## Deployment of the bootstrap network

Before starting the peer sampling service, a first network of nodes has to be deployed.
To represent this first network, we can use 2 data structures: a binary tree, or a double linked list.
All the nodes will be added to the data structure before starting the service.
In this way, all the nodes have a non empty view when they start the service,
and can directly exchange with their peers.\

To implement these data structures in practice, we use an Erlang node that will act as a server.
Every node in the structure is simply represented by an increasing ID,
assigned by the server when the node is added to the structure.
To enable interaction, the server allows the reception of two messages, sent by a node:
- join, that adds the node to the data structure, and responds to it with its ID;
- getPeers(NodeId), that gets and responds with the neighbors of the node
corresponding to the node ID sent along the message.


## Peer sampling service implementation

## Evaluation with experimental scenario
