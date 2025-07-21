# --- variabili ---
CC      = mpicc
CFLAGS  = -O3 -Wall -Iinclude

SRCDIR  = src
BLDDIR  = build
TARGET  = bcast

# Lista dei “nomi” (senza estensione) dei sorgenti in src/
ALGS    = basic_linear chain pipeline pipeline_nb binomial

# Derived
ALG_OBJS = $(patsubst %, $(BLDDIR)/%.o, $(ALGS))
MAIN_OBJ = $(BLDDIR)/main.o

.PHONY: all clean

all: $(TARGET)

# link finale
$(TARGET): $(MAIN_OBJ) $(ALG_OBJS)
	$(CC) $(CFLAGS) -o $@ $^

# compilazione di main.c
$(MAIN_OBJ): $(SRCDIR)/main.c include/bcast.h
	@mkdir -p $(BLDDIR)
	$(CC) $(CFLAGS) -c $< -o $@

# compilazione di ciascun algoritmo
$(BLDDIR)/%.o: $(SRCDIR)/%.c include/bcast.h
	@mkdir -p $(BLDDIR)
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -rf $(BLDDIR) $(TARGET)
