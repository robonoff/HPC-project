#!/bin/bash
#SBATCH --job-name=scatf
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=64
#SBATCH --time=00:30:00
#SBATCH --partition GENOA
#SBATCH --exclusive


module load openMPI/5.0.5

OSUBENCH=/u/dssc/rlamberti/HPC-project/osu-micro-benchmarks-7.5.1/c/mpi/collective/blocking/osu_scatter

# Repetitions to get an average result
repetitions=10000

# Fixed message size
size=4

# Cycling over different algorithms
for algoritm in {0..3}
do
    OUTPUTFILE=scatter${algoritm}_fixed_core.csv
    echo "Processes, Size, Latency" > $OUTPUTFILE
    for processes in {2..128}
    do
    
        # Perform osu_scatter with current processors, fixed message size and fixed number of repetitions
        result_scatter=$(mpirun --map-by core -np $processes --mca coll_tuned_use_dynamic_rules true --mca coll_tuned_scatter_algorithm $algoritm $OSUBENCH -m $size:$size -x $repetitions -i $repetitions 2>/dev/null | awk '!/^#/ { last = $2 } END { print last }')
    
        echo "$processes, $size, $result_scatter"
        # Write results on CSV
        echo "$processes,$size,$result_scatter" >> $OUTPUTFILE
    
    done
done


