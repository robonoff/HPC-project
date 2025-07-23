#!/bin/bash
#SBATCH --job-name=forzanapoli
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=128
#SBATCH --time=01:59:59
#SBATCH --partition=EPYC
#SBATCH --output=scaling_%j.out
#SBATCH --error=scaling_%j.err

module load openMPI/5.0.5
export MPI_INIT_THREAD_REQUIRED=multiple
export SLURM_SUBMIT_DIR=$(pwd)
cd $SLURM_SUBMIT_DIR

make clean && make all

# crea la cartella csv3 per i CSV
mkdir -p csv3

# srun options
SRUN_OPTS="--mpi=pmix --cpu-bind=cores --distribution=block:cyclic"

# algoritmi
ALGS="1 2 3 4 6"

# valori di P
P_VALUES="2 4 8 16 32 64 128 256"

# taglie per strong scaling (count per process)
STRONG_N_VALUES=(1 2 4 8 16 32 64 128 256 512 \
                 1024 2048 4096 8192 16384 32768 \
                 65536 131072 262144 524288 1048576 2097152 4194304)

# weak: carico costante per rank 1mb
COUNT_PER_RANK=1048576

for ALG in $ALGS; do
  for P in $P_VALUES; do
    # --- STRONG scaling per (ALG,P) ---
    OUT_STRONG=csv2/${ALG}_strong_P${P}.csv
    echo "P,count,time" > $OUT_STRONG
    
    for N in "${STRONG_N_VALUES[@]}"; do
      if [ "$P" -eq 1 ]; then
        RAW=$( ./bcast -a $ALG -n $N )
      else
        RAW=$( srun $SRUN_OPTS -n $P ./bcast -a $ALG -n $N )
      fi
      TIME=${RAW##*,}
      echo "${P},${N},${TIME}" >> $OUT_STRONG
    done
    
    # --- WEAK scaling per (ALG,P) ---
    OUT_WEAK=csv2/${ALG}_weak_P${P}.csv
    echo "P,count,time" > $OUT_WEAK
    
    # count totale = COUNT_PER_RANK * P
    N=$(( COUNT_PER_RANK * P ))
    if [ "$P" -eq 1 ]; then
      RAW=$( ./bcast -a $ALG -n $N )
    else
      RAW=$( srun $SRUN_OPTS -n $P ./bcast -a $ALG -n $N )
    fi
    TIME=${RAW##*,}
    echo "${P},${N},${TIME}" >> $OUT_WEAK
  done
done

echo "Done: tutti i CSV sono in ./csv3/"
