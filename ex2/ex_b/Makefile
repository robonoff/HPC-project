# Makefile semplice per Mandelbrot OpenMP
CC = gcc
CFLAGS = -O3 -march=native -ffast-math -fopenmp -Wall -Wextra
LDFLAGS = -lm

# File sorgente e target
SOURCE = mandelbrot/mandelbrot.c
TARGET = mandelbrot_omp

.PHONY: all clean help

# Target principale
all: $(TARGET)

# Compilazione
$(TARGET): $(SOURCE)
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)
	@echo "✓ Compilazione completata: $(TARGET)"

# Test rapido per verificare che funzioni
test: $(TARGET)
	@echo "=== TEST RAPIDO ==="
	@echo "Testing 1, 2, 4 threads..."
	@for t in 1 2 4; do \
		echo "Thread $t:"; \
		OMP_NUM_THREADS=$t ./$(TARGET) 1 $t 1000 1000 100; \
	done

# Pulizia
clean:
	rm -f $(TARGET)
	@echo "✓ File puliti"
