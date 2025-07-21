# --- variabili ---
CC      = mpicc
CFLAGS  = -O3 -Wall -Isrc/include
SRCDIR  = src
BLDDIR  = build
TARGET  = bcast

ALGS       = basic_linear chain pipeline pipeline_nb binomial
ALG_SRCS   = $(patsubst %,algorithms/%.c,$(ALGS))
ALG_OBJS   = $(patsubst %, $(BLDDIR)/algorithms/%.o,$(ALGS))

# --- regole ---
all: $(TARGET)

$(TARGET): $(BLDDIR)/main.o $(ALG_OBJS)
	$(CC) $(CFLAGS) -o $@ $^

$(BLDDIR)/main.o: $(SRCDIR)/main.c
	mkdir -p $(BLDDIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BLDDIR)/algorithms/%.o: $(SRCDIR)/algorithms/%.c $(SRCDIR)/include/bcast.h
	mkdir -p $(BLDDIR)/algorithms
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -rf $(BLDDIR) $(TARGET)
