# General

- first of all, congratulations for your good work!
- your sources are easy to read and provide comments that allows one to follow the logic in your algorithms
- the erl sources are also of excellent quality because it is relatively easy to understand by merely reading the code
- there is a brief explanation about the results without further details about how nodes behave during the different phases,
- it is clear that there is a lack of argumentation that explain the behavior of curves, you explain why might be the reason with no further details. Here one example, the observed variance of in-degree when nodes recover reflects that the in-degree is not equally balanced among all nodes in the network (as shown before nodes crash); or even simpler, there are partitions where one observe that certain clusters contain more nodes than others

# Execution
- issues:
  1. I had a hard time to find a compatibility with erlang/otp 19, it is important to report the version you use (see changes in code)
  1. once the execution finishes, the plots cannot be created (see log below)
  ```bash
  $ make
# Run project with healer policy (H=4 and S=3)
# Run project with swapper policy (H=3 and S=4)
  File "compute_indegree.py", line 29
    plt.title(f"In-degree of all the nodes for the {policy} policy")
                                                                  ^
SyntaxError: invalid syntax
Makefile:18: recipe for target 'graphs' failed
make: *** [graphs] Error 1
  ```
  1. how do you explain that the standard deviation of in-degree is bigger than one in cycle 0 ? most likely, there is an error in the computation of the in-degree; this is also confirmed with the high variance observed before nodes crashed
  1. it appears that you didn't follow the rule of having a single node in the view of other nodes that come back to the network after they crashed. One can verify so by merely observing the large variation of descriptors within views of recovered nodes.
  # Grade
  | Bootstrap network (20%) | PS service implementation (50%) | Experimental scenario (30%) | Grade in % | Points (up to 5) |
  |---|---|---|---|---|
  |20|	50|	15|	85|	4.25|
