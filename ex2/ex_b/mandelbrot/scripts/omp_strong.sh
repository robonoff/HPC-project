#!/bin/bash
#SBATCH --job-name=strong
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --output=output_omp_strong.%j.out
#SBATCH --error=error_omp_strong.%j.err
#SBATCH --cpus-per-task=128
#SBATCH --time=01:40:00
#SBATCH --partition=EPYC
#SBATCH --exclusive

# === CONFIG ===
EXE="./mandelbrot"
RESULTS_DIR="../results"
OUTPUT_CSV="${RESULTS_DIR}/omp_strong_scaling.csv"
mkdir -p "$RESULTS_DIR"

# Mandelbrot params
XL=-2.0
YL=-1.5
XR=1.0
YR=1.5
IMAX=255
N=10000  # immagine fissa

# Header CSV
echo "cores,threads,width,height,time" > "$OUTPUT_CSV"

# OpenMP env
export OMP_PLACES=cores
export OMP_PROC_BIND=close
export OMP_WAIT_POLICY=active

# === STRONG SCALING LOOP ===
for (( THREADS=1; THREADS<=128; THREADS++ )); do
    export OMP_NUM_THREADS=$THREADS
    echo "➤ THREADS = $THREADS, size = ${N}x${N}"

    output=$($EXE $N $N $XL $YL $XR $YR $IMAX 2>&1)
    time=$(echo "$output" | awk '/Execution Time:/ {print $3}')

    echo "1,$THREADS,$N,$N,$time" >> "$OUTPUT_CSV"
    sleep 1
done

echo -e "\n[INFO] Strong scaling test completed"
echo "[INFO] Results saved in: $OUTPUT_CSV"
	
