#!/bin/bash
#SBATCH --job-name=latency_topotest
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=2
#SBATCH --time=00:12:00
#SBATCH --partition=GENOA
#SBATCH --exclusive

module load openMPI/5.0.5

echo "Running latency topology tests on AMD EPYC 9374F..."

OSUBENCH=/u/dssc/rlamberti/HPC-project/osu-micro-benchmarks-7.5.1/c/mpi/pt2pt/standard/osu_latency

# Get node hostnames
nodes=($(scontrol show hostname))
hostname1=${nodes[0]}
hostname2=${nodes[1]:-$hostname1} # fallback for single-node case

# Core pairs based on EPYC 9374F layout:
# 4 core per CCD, 2 CCD per NUMA (8 core), 4 NUMA per socket
core_pairs=(
    "0,1"     # Same CCX/CCD (core 0–3 → CCD 0) 
    "0,4"     # Same NUMA node (core 0–7 → NUMA 0, but diff CCD)
    "0,12"    # Same socket (NUMA 0 vs NUMA 1, both in socket 0)
    "0,40"    # Different socket (core 40 is in socket 1)
    "0,0"     # Different node (core 0 su hostname1 e hostname2)
)

labels=(
    "Same CCX"
    "Same NUMA (different CCD)"
    "Same Socket (different NUMA)"
    "Different Socket"
    "Different Node"
)

# Initialize CSV
echo "Label,MessageSize,Latency_us" > latency_pt2pt.csv

# Run latency tests
for i in "${!core_pairs[@]}"; do
    label="${labels[$i]}"
    echo "Running: $label [cores ${core_pairs[$i]}]"

    if [ "$i" -eq 4 ]; then
        # Inter-node test
        result=$(mpirun -np 2 --host $hostname1,$hostname2 $OSUBENCH)
    else
        result=$(mpirun -np 2 --bind-to core --cpu-list ${core_pairs[$i]} $OSUBENCH)
    fi

    # Extract results (skip first 2 comment lines)
    echo "$result" | tail -n +3 | while read size latency; do
        echo "$label,$size,$latency" >> latency_pt2pt.csv
    done
done

echo "All topology tests completed. Results saved to latency_pt2pt.csv"
