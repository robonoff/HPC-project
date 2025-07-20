#!/bin/bash
#SBATCH --job-name=scatterv
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=64
#SBATCH --time=00:75:00
#SBATCH --partition=GENOA
#SBATCH --exclusive

module load openMPI/5.0.5

OSUBENCH=/u/dssc/rlamberti/HPC-project/osu-micro-benchmarks-7.5.1/c/mpi/collective/blocking/osu_scatter

repetitions=10000
size=4

echo "Nodi usati: $SLURM_NODELIST"

# Loop sugli algoritmi 0,1,2,3
for alg in {0..3}; do
  OUTFILE="scatter${alg}_core_mapping.csv"
  echo "Processes,Size,Latency" > "$OUTFILE"
  echo "=== SCATTER $alg ==="

  for pow_p in {1..7}; do
    np=$((2**pow_p))      # 2,4,8,...,128
    for pow_s in {1..18}; do
      msgsz=$((2**pow_s)) # 2,4,8,...,2^18

      # Rimuovi il 2>/dev/null per vedere eventuali errori
      raw=$(
        mpirun --map-by core \
               -np $np \
               --mca coll_tuned_use_dynamic_rules true \
               --mca coll_tuned_scatter_algorithm $alg \
               $OSUBENCH \
               -m ${msgsz}:${msgsz} \
               -x $repetitions -i $repetitions
      )

      # Estrai l’ultima latenza numerica
      latency=$( printf "%s\n" "$raw" \
                | awk '!/^#/ { last=$2 } END{print last}' )

      echo "$np, $msgsz, $latency"
      echo "$np,$msgsz,$latency" >> "$OUTFILE"
    done
  done
done
