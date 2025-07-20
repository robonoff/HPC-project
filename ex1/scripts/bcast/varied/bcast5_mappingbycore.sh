#!/bin/bash
#SBATCH --job-name=bcast1
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=64
#SBATCH --time=00:15:00
#SBATCH --partition GENOA
#SBATCH --exclusive

module load openMPI/5.0.5

OSUBENCH=/u/dssc/rlamberti/HPC-project/osu-micro-benchmarks-7.5.1/c/mpi/collective/blocking/osu_bcast

echo "Nodi utilizzati: $SLURM_NODELIST"
echo "BROADCAST 1"
echo "Processes,Size,Latency" > bcast5_core_mapping_genoa.csv

# Number of repetitions to get an average result
repetitions=10000

# Cycle over processors
for processes_size in {1..7}
do
    # Set number of processors from 2^1 to 2^8
    processes=$((2**processes_size))
    # Set message size from 2^1 to 2^18
    for size_power in {1..18}
    do
        # Compute message size
        size=$((2**size_power))

        # Perform osu_bcast
        result_bcast=$(mpirun --map-by core -np $processes --mca coll_tuned_use_dynamic_rules true --mca coll_tuned_bcast_algorithm 5 $OSUBENCH -m $size:$size -x $repetitions -i $repetitions | tee /dev/stderr | awk '!/^#/ { last = $2 } END { print last }')

        echo "$processes, $size, $result_bcast"
        # Write results on CSV
        echo "$processes,$size,$result_bcast" >> bcast5_core_mapping_genoa.csv
    done
done
