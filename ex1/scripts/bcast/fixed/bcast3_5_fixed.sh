#!/bin/bash
#SBATCH --job-name=bcf35
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=64
#SBATCH --time=00:13:00
#SBATCH --partition GENOA
#SBATCH --exclusive


module load openMPI/5.0.5


echo "Processes,Size,Latency" > bcast3_fixed_core.csv
echo "Processes,Size,Latency" > bcast5_fixed_core.csv

OSUBENCH=/u/dssc/rlamberti/HPC-project/osu-micro-benchmarks-7.5.1/c/mpi/collective/blocking/osu_bcast

# Repetitions to get an average result
repetitions=10000

# Fixed message size
size=4
#------------- BCAST 3 -----------
for processes in {2..128}
do
    # Perform osu_bcast with current processors, fixed message size and fixed number of repetitions
    result_bcast=$(mpirun --map-by core -np $processes --mca coll_tuned_use_dynamic_rules true --mca coll_tuned_bcast_algorithm 3 $OSUBENCH -m $size:$size -x $repetitions -i $repetitions 2>/dev/null | awk '!/^#/ { last = $2 } END { print last }')

    echo "$processes, $size, $result_bcast"
    # Write results on CSV
    echo "$processes,$size,$result_bcast" >> bcast3_fixed_core.csv

done

#------------- BCAST 35-----------
for processes in {2..128}
do

    # Perform osu_bcast with current processors, fixed message size and fixed number of repetitions
    result_bcast=$(mpirun --map-by core -np $processes --mca coll_tuned_use_dynamic_rules true --mca coll_tuned_bcast_algorithm 5 $OSUBENCH -m $size:${size} -x $repetitions -i $repetitions 2>/dev/null | awk '!/^#/ { last = $2 } END { print last }')

    echo "$processes, $size, $result_bcast"
    # Write results on CSV
    echo "$processes,$size,$result_bcast" >> bcast5_fixed_core.csv

done
