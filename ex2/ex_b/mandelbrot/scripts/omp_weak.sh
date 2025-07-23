#!/bin/bash
#SBATCH --job-name=weak_omp
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --output=output_omp_weak.%j.out
#SBATCH --error=error_omp_weak.%j.err
#SBATCH --cpus-per-task=128
#SBATCH --time=01:00:00
#SBATCH --partition=EPYC
#SBATCH --exclusive


# Percorsi
EXE="./mandelbrot"
RESULTS_DIR="../results"
OUTPUT_CSV="${RESULTS_DIR}/omp_weak_scaling.csv"
mkdir -p "$RESULTS_DIR"

# Parametri Mandelbrot
XL=-2.0
YL=-1.5
XR=1.0
YR=1.5
IMAX=255
C=1000000  # pixel² per thread

# Header CSV
echo "cores,threads,width,height,time" > "$OUTPUT_CSV"

# Variabili OMP
export OMP_PLACES=cores
export OMP_PROC_BIND=close
export OMP_WAIT_POLICY=active

for THREADS in {1..128}; do
    export OMP_NUM_THREADS=$THREADS
    N=$(echo "sqrt($THREADS * $C)" | bc -l | xargs printf "%.2f")

    echo "Running with $THREADS threads, image size ${N}x${N}"

    output=$($EXE ${N%.*} ${N%.*} $XL $YL $XR $YR $IMAX 2>&1)
    time=$(echo "$output" | awk '/Execution Time:/ {print $3}')

    echo "1,$THREADS,$N,$N,$time" >> "$OUTPUT_CSV"
    sleep 1
done

echo -e "\n[INFO] Weak scaling test completed"
echo "[INFO] Results saved in: $OUTPUT_CSV"
