CC      ?= cc
CFLAGS  ?= -std=c11 -Wall -Wextra -O2 -g
SRC     := $(wildcard src/*.c)
BIN     := build/server

all: $(BIN)

$(BIN): $(SRC)
	@mkdir -p build
	$(CC) $(CFLAGS) -o $@ $(SRC)

run: $(BIN)
	./$(BIN) 8080

clean:
	rm -rf build

.PHONY: all run clean
