all: run graphs

compile: clean
	@erlc tree.erl
	@erlc linked_list.erl
	@erlc bootstrap_server.erl
	@erlc utils.erl
	@erlc node.erl
	@erlc project.erl

run: compile
	# Run project with healer policy (H=4 and S=3)
	@erl -noshell -run project main 128 tree 7 rand pushpull 3 4 -s init stop > ../results/healer.data
	# Run project with swapper policy (H=3 and S=4)
	@erl -noshell -run project main 128 tree 7 rand pushpull 3 4 -s init stop > ../results/swapper.data

graphs:
	@python3 compute_indegree.py

test: compile
	# Unit tests for binary tree
	@erl -noshell -run bootstrap_server testT -s init stop
	# Unit tests for double linked list
	@erl -noshell -run bootstrap_server testL -s init stop

.PHONY: clean

clean:
	@rm -f *.beam
