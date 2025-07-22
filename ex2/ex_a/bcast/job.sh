#!/bin/bash
#SBATCH --job-name=bcG
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=64      # 1 task per core, 128 core per nodo
#SBATCH --time=01:59:59
#SBATCH --partition=GENOA
#SBATCH --output=scaling_%j.out
#SBATCH --error=scaling_%j.err

module load openMPI/5.0.5
export MPI_INIT_THREAD_REQUIRED=multiple
export SLURM_SUBMIT_DIR=$(pwd)

cd $SLURM_SUBMIT_DIR
make clean && make all

# binding esplicito per minimizzare jitter
SRUN_OPTS="--mpi=pmix --cpu-bind=cores --distribution=block:cyclic"

# algoritmi: 1=basic, 2=chain, 3=pipeline, 4=pipeline_nb, 6=binomial, 5=RMA
ALGS="1 2 3 4 6 "

# valori di P fino al massimo allocabile (2 nodi × 64 tasks = 128)
P_VALUES="1 2 4 8 16 32 64 128"

for MODE in strong weak; do
  OUT=${MODE}_scaling.csv
  echo "alg,P,count,time" > $OUT

  for ALG in $ALGS; do
    for P in $P_VALUES; do
      # problema fisso per strong, proporzionale a P per weak
      if [ "$MODE" = "strong" ]; then
        N=1000000
      else
        N=$((100000 * P))
      fi

      # lancia P rank (P deve essere ≤ 256)
      LINE=$( srun $SRUN_OPTS -n $P ./bcast -a $ALG -n $N )
      echo $LINE >> $OUT
    done
  done
done

echo "Done: generated strong_scaling.csv & weak_scaling.csv"
