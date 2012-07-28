
CC = dmd


SRC_FILES = src/rwg/*.d

all: build

build:
	$(CC) -O -property -wi -odbin -ofrwg -debug -unittest $(SRC_FILES)

install: build
	install rwg /usr/local/bin
 
