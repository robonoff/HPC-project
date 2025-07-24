# Makefile ottimizzato per Mandelbrot OpenMP
CC = gcc
CFLAGS = -O3 -march=native -ffast-math -fopenmp -Wall -Wextra -funroll-loops
LDFLAGS = -lm -fopenmp

# File sorgente e target
SOURCE = src/mandelbrot.c
TARGET = mandelbrot_omp

.PHONY: all clean test help info

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
		echo "Thread $$t:"; \
		OMP_NUM_THREADS=$$t ./$(TARGET) 1 $$t 1000 1000 100; \
	done

# Test scaling rapido
test_scaling: $(TARGET)
	@echo "=== TEST SCALING RAPIDO ==="
	@mkdir -p results
	@echo "cores,threads,width,height,time" > results/test_scaling.csv
	@for t in 1 2 4 8 16 32; do \
		echo "Testing $$t threads..."; \
		OMP_NUM_THREADS=$$t ./$(TARGET) 1 $$t 2000 2000 300 >> results/test_scaling.csv; \
	done
	@echo "✓ Risultati salvati in results/test_scaling.csv"

# Test NUMA (per verificare distribuzione su nodi)
test_numa: $(TARGET)
	@echo "=== TEST NUMA (16, 64, 128 threads) ==="
	@for t in 16 64 128; do \
		echo "Testing $$t threads (NUMA test):"; \
		OMP_NUM_THREADS=$$t ./$(TARGET) 1 $$t 2000 2000 300; \
	done

# Genera immagine PGM
image: $(TARGET)
	@echo "=== GENERAZIONE IMMAGINE ==="
	@mkdir -p results
	OMP_NUM_THREADS=16 ./$(TARGET) 1 16 2048 2048 1000 results/mandelbrot.pgm
	@echo "✓ Immagine salvata: results/mandelbrot.pgm"

# Info sistema
info:
	@echo "=== INFO SISTEMA ==="
	@echo "Compilatore: $(CC) $(shell $(CC) --version | head -1)"
	@echo "CPU cores: $(shell nproc)"
	@echo "NUMA nodes: $(shell lscpu | grep 'NUMA node(s)' | awk '{print $$3}')"
	@echo "OpenMP support: $(shell $(CC) -fopenmp -dM -E - < /dev/null 2>/dev/null | grep -c _OPENMP)"

# Pulizia
clean:
	rm -f $(TARGET)
	@echo "✓ File puliti"

clean_all: clean
	rm -rf results/test_*.csv results/*.pgm
	@echo "✓ Tutti i file di test puliti"
