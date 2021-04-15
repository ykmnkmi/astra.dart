compile:
	@cc -c -Wall -Werror -fpic native/native.c -o native/native.o
	@cc -shared native/native.o -o bin/native.so
	@rm native/native.o
	
dill:
	@dart compile kernel bin/astra.dart -o bin/astra.dill
	@dart bin/astra.dill

jit:
	@dart compile jit-snapshot bin/astra.dart -o bin/astra.jit
	@dart bin/astra.jit

aot:
	@dart compile exe bin/astra.dart -o bin/astra
	@./bin/astra

clean:
	@rm -f bin/astra.dill bin/astra.jit bin/astra
