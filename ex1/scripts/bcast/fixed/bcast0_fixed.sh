#!/bin/bash
#SBATCH --job-name=bcast0
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=64
#SBATCH --time=00:12:00
#SBATCH --partition=GENOA
#SBATCH --exclusive

module load openMPI/5.0.5

OSUBENCH=/u/dssc/rlamberti/HPC-project/\
osu-micro-benchmarks-7.5.1/c/mpi/collective/blocking/osu_bcast

repetitions=10000
size=4
OUT=bcast0_fixed_core.csv

echo "Processes,Size,Latency" > $OUT

for processes in {2..128}; do
  # 1) corri il benchmark, cattura solo stdout in raw
  raw=$(
    mpirun --map-by core \
           -np $processes \
           --mca coll_tuned_use_dynamic_rules false \
           --mca coll_tuned_bcast_algorithm 0 \
           $OSUBENCH -m ${size}:${size} -x $repetitions -i $repetitions \
      2>/dev/null
  )
  latency=$( printf "%s\n" "$raw" \
             | awk '!/^#/ { last=$2 } END{print last}' )

  echo "$processes,$size,$latency" >> $OUT
done
