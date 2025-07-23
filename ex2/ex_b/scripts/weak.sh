#!/bin/bash
#SBATCH --job-name=weak
#SBATCH --output=results/weak_scaling_%j.out
#SBATCH --error=results/weak_scaling_%j.err
#SBATCH --time=01:59:00
#SBATCH --partition=EPYC
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=128
#SBATCH --mem=64GB

echo "=== MANDELBROT WEAK SCALING TEST ==="
echo "Data: $(date)"
echo "Nodo: $(hostname)"
echo "CPU disponibili: $(nproc)"
echo ""

# Crea directory results se non esiste
mkdir -p results

# Compila se necessario
if [ ! -f mandelbrot_omp ]; then
    echo "Compilando mandelbrot..."
    gcc -O3 -march=native -ffast-math -fopenmp -Wall -o mandelbrot_omp mandelbrot/mandelbrot.c -lm
    
    if [ $? -ne 0 ]; then
        echo "Errore nella compilazione!"
        exit 1
    fi
fi

# Parametri base per weak scaling
CORES=1
BASE_SIZE=2500  # Dimensione base per 1 thread
MAX_ITER=1000

# File di output
OUTPUT_FILE="results/omp_weak_scaling.csv"

# Thread da testare
THREAD_COUNTS=($(seq 1 128))

echo "Parametri test:"
echo "- Dimensione base: ${BASE_SIZE}x${BASE_SIZE} per 1 thread"
echo "- Max iterazioni: ${MAX_ITER}"
echo "- Thread testati: ${#THREAD_COUNTS[@]} configurazioni"
echo "- Output: ${OUTPUT_FILE}"
echo ""

# Header CSV
echo "cores,threads,width,height,time" > $OUTPUT_FILE

# Funzione per calcolare dimensione scalata
calculate_scaled_size() {
    local threads=$1
    local base=$2
    # Scala proporzionalmente alla radice quadrata per mantenere 
    # carico di lavoro per thread costante
    python3 -c "
import math
scaled = int($base * math.sqrt($threads))
print(scaled)
"
}

# Funzione per configurare environment OpenMP
configure_openmp() {
    local threads=$1
    
    export OMP_NUM_THREADS=$threads
    export OMP_PROC_BIND=close
    export OMP_PLACES=cores
    export OMP_WAIT_POLICY=active
    export OMP_DYNAMIC=false
    
    if [ $threads -ge 64 ]; then
        export OMP_PROC_BIND=spread
        export OMP_PLACES=threads
    fi
    
    if [ $threads -ge 32 ]; then
        export OMP_PROC_BIND=spread
    fi
}

# Esegui test per ogni configurazione
echo "Inizio test weak scaling..."
total_tests=${#THREAD_COUNTS[@]}
current_test=0

for THREADS in "${THREAD_COUNTS[@]}"; do
    current_test=$((current_test + 1))
    
    # Calcola dimensioni scalate
    SCALED_SIZE=$(calculate_scaled_size $THREADS $BASE_SIZE)
    
    echo "[$current_test/$total_tests] Testing $THREADS threads, size: ${SCALED_SIZE}x${SCALED_SIZE}"
    
    # Configura OpenMP
    configure_openmp $THREADS
    
    # Calcola carico di lavoro per thread
    total_work=$((SCALED_SIZE * SCALED_SIZE))
    work_per_thread=$((total_work / THREADS))
    
    echo "  Carico totale: $total_work punti"
    echo "  Carico per thread: $work_per_thread punti"
    
    # Esegui test multipli - SEZIONE CORRETTA
    TIMES=()
    for run in {1..3}; do
        echo "  Run $run/3..."
        
        # Esegui il programma e cattura sia output che exit code
        OUTPUT=$(./mandelbrot_omp $CORES $THREADS $SCALED_SIZE $SCALED_SIZE $MAX_ITER 2>&1)
        EXIT_CODE=$?
        
        if [ $EXIT_CODE -eq 0 ] && [ -n "$OUTPUT" ]; then
            TIME=$(echo "$OUTPUT" | cut -d',' -f5)
            if [[ "$TIME" =~ ^[0-9]+\.?[0-9]*$ ]]; then
                TIMES+=($TIME)
                echo "    ✓ Tempo: $TIME"
            else
                echo "    ⚠ Output invalido: '$OUTPUT'"
            fi
        else
            echo "    ⚠ Errore: exit=$EXIT_CODE, output='$OUTPUT'"
        fi
        
        sleep 1
    done
    
    # Calcola tempo medio
    if [ ${#TIMES[@]} -gt 0 ]; then
        # Converti array bash in formato Python corretto
        TIMES_STR=$(printf "%.6f," "${TIMES[@]}")
        TIMES_STR=${TIMES_STR%,}  # Rimuovi ultima virgola
        
        AVG_TIME=$(python3 -c "
times = [$TIMES_STR]
if times:
    avg = sum(times) / len(times)
    print(f'{avg:.6f}')
else:
    print('0.0')
")
        
        # Scrivi nel CSV
        echo "$CORES,$THREADS,$SCALED_SIZE,$SCALED_SIZE,$AVG_TIME" >> $OUTPUT_FILE
        echo "  ✓ Tempo medio: $AVG_TIME s (${#TIMES[@]} run validi)"
    else
        echo "  ✗ Nessun run valido per $THREADS threads"
    fi
    
    # Pausa proporzionale
    if [ $THREADS -ge 64 ]; then
        sleep 5
    elif [ $THREADS -ge 32 ]; then
        sleep 3
    else
        sleep 2
    fi
done

echo ""
echo "=== WEAK SCALING COMPLETATO ==="
echo "File risultati: $OUTPUT_FILE"
echo "Righe generate: $(wc -l < $OUTPUT_FILE)"
echo "$(date)"
