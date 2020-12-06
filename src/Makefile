all: run

compile: clean
	@erlc tree.erl
	@erlc linked_list.erl
	@erlc bootstrap_server.erl
	@erlc utils.erl
	@erlc node.erl
	@erlc project.erl

run: compile
	# Run project with healer policy (H=4 and S=3)
	@erl -noshell -run project main 20 tree 7 rand pushpull 4 3 -s init stop > ../graphs/healer.data
	# Run project with swapper policy (H=0 and S=4)
	@erl -noshell -run project main 20 tree 7 rand pushpull 3 4 -s init stop > ../graphs/swapper.data

.PHONY: clean

clean:
	@rm -f *.beam