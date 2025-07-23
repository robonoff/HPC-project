#!/bin/bash
#SBATCH --job-name=mandelbrot_omp_weak
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --output=output_omp_weak.%j.out
#SBATCH --error=error_omp_weak.%j.err
#SBATCH --cpus-per-task=128
#SBATCH --time=01:46:00
#SBATCH --partition=EPYC
#SBATCH --exclusive

EXE="./mandelbrot"
RESULTS_DIR="../results"
OUTPUT_CSV="${RESULTS_DIR}/weak_scaling_omp.csv"

mkdir -p "$RESULTS_DIR"

# Mandelbrot fixed parameters
XL=-2.0
YL=-1.5
XR=1.0
YR=1.5
IMAX=255
C=1000000  # pixel² per thread

# Header
echo "Threads,Size,ComputeTime,Speedup,Efficiency" > "$OUTPUT_CSV"

export OMP_PLACES=cores
export OMP_PROC_BIND=close
export OMP_WAIT_POLICY=active

BASELINE=0

for THREADS in 1 2 4 8 16 32 64 128; do
    export OMP_NUM_THREADS=$THREADS
    N=$(echo "sqrt($THREADS * $C)" | bc -l | xargs printf "%.0f")
    
    echo "Running with $THREADS threads, image size ${N}x${N}"
    
    output=$(./$EXE $N $N $XL $YL $XR $YR $IMAX 2>&1)
    time=$(echo "$output" | awk '/Execution Time:/ {print $3}')
    
    if [ "$THREADS" -eq 1 ]; then
        BASELINE=$time
        speedup=1.0
        efficiency=100.0
    else
        speedup=$(echo "$BASELINE / $time" | bc -l)
        efficiency=$(echo "$speedup / $THREADS * 100" | bc -l)
    fi

    echo "$THREADS,$N,$time,$speedup,$efficiency" >> "$OUTPUT_CSV"
    sleep 1
done

echo -e "\n[INFO] Weak scaling test completed"
echo "[INFO] Results: $OUTPUT_CSV"
