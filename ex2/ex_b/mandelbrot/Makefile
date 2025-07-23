CC = gcc
CFLAGS = -O3 -fopenmp -Wall -Iinclude
LDFLAGS = -lm

SRC = src/main.c src/mandelbrot.c src/pgm_writer.c

all: mandelbrot

mandelbrot: $(SRC)
	$(CC) $(CFLAGS) -o $@ $(SRC) $(LDFLAGS)

clean:
	rm -f mandelbrot output.pgm
