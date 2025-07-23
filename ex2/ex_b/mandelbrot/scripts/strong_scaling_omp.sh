#!/bin/bash
#SBATCH --job-name=mandelbrot_omp_strong
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --output=output_omp_strong.%j.out
#SBATCH --error=error_omp_strong.%j.err
#SBATCH --cpus-per-task=128
#SBATCH --time=01:45:00
#SBATCH --partition=EPYC
#SBATCH --exclusive


# Crea directory risultati
RESULTS_DIR="../results"
OUTPUT_CSV="${RESULTS_DIR}/strong_scaling_omp.csv"
mkdir -p "$RESULTS_DIR"

# Parametri Mandelbrot fissi
XL=-2.0
YL=-1.5
XR=1.0
YR=1.5
IMAX=255
N=10000

EXE="./mandelbrot"

# Controlla che l’eseguibile esista
if [ ! -f "$EXE" ]; then
    echo "Error: Executable $EXE not found!"
    exit 1
fi

# Header CSV
echo "Threads,Size,ComputeTime,Speedup,Efficiency" > "$OUTPUT_CSV"

# Variabili OpenMP
export OMP_PLACES=cores
export OMP_PROC_BIND=close
export OMP_WAIT_POLICY=active

BASELINE=0

# Loop su potenze di due fino a 128
for THREADS in 1 2 4 8 16 32 64 128; do
    export OMP_NUM_THREADS=$THREADS
    echo "Running with $THREADS threads, image size ${N}x${N}"

    # Esegui e cattura l'output
    output=$($EXE $N $N $XL $YL $XR $YR $IMAX 2>&1)
    compute_time=$(echo "$output" | awk '/Execution Time:/ {print $3}')

    # Calcolo speedup / efficienza
    if [ "$THREADS" -eq 1 ]; then
        BASELINE=$compute_time
        speedup=1.0
        efficiency=100.0
    else
        speedup=$(echo "$BASELINE / $compute_time" | bc -l)
        efficiency=$(echo "$speedup / $THREADS * 100" | bc -l)
    fi

    echo "$THREADS,$N,$compute_time,$speedup,$efficiency" >> "$OUTPUT_CSV"
    sleep 2
done

# Report finale
echo -e "\nJob Statistics for Job ID $SLURM_JOB_ID:"
sacct -j $SLURM_JOB_ID --format=JobID,JobName,Partition,MaxRSS,MaxVMSize,Elapsed,State

echo -e "\nScaling Results Summary:"
echo "========================="
echo "Results saved in: $OUTPUT_CSV"
echo "Number of tests completed: $(( $(wc -l < $OUTPUT_CSV) - 1 ))"
echo "Fixed image size: ${N}x${N}"
echo "Maximum number of threads: $THREADS"
