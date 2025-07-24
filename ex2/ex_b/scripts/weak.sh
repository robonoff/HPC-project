#!/bin/bash
#SBATCH --job-name=weak_fixed
#SBATCH --output=results/weak_scaling_%j.out
#SBATCH --error=results/weak_scaling_%j.err
#SBATCH --time=01:30:00
#SBATCH --partition=EPYC
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=128
#SBATCH --mem=128GB
#SBATCH --exclusive

echo "=== MANDELBROT WEAK SCALING FIXED ==="
echo "Data: $(date)"
echo "Nodo: $(hostname)"
echo "CPU disponibili: $(nproc)"
echo "NUMA nodes: $(lscpu | grep 'NUMA node(s)' | awk '{print $3}')"
echo ""

# Vai nella directory di lavoro
cd $SLURM_SUBMIT_DIR

# Crea directory results
mkdir -p results

# Compila versione ottimizzata
if [ ! -f mandelbrot_omp ]; then
    echo "Compilando versione ottimizzata..."
    make clean && make all
    
    if [ $? -ne 0 ]; then
        echo "Errore nella compilazione!"
        exit 1
    fi
fi

# Parametri ottimizzati per weak scaling CORRETTO
CORES=1
BASE_SIZE=1000   # Dimensione base per 1 thread (1M pixel)
MAX_ITER=400     # Iterazioni bilanciate

# File di output
OUTPUT_FILE="results/omp_weak_scaling.csv"

# Thread da testare (sequenza completa)
THREAD_COUNTS=($(seq 1 128))

echo "Parametri weak scaling CORRETTI:"
echo "- Dimensione base: ${BASE_SIZE}x${BASE_SIZE} (1M pixel per 1 thread)"
echo "- Max iterazioni: ${MAX_ITER}"
echo "- Thread testati: ${#THREAD_COUNTS[@]} configurazioni"
echo "- Formula: size = base * sqrt(threads) (lavoro/thread costante)"
echo "- Output: ${OUTPUT_FILE}"
echo ""

# Header CSV
echo "cores,threads,width,height,time" > $OUTPUT_FILE

# Formula CORRETTA per weak scaling
calculate_weak_size() {
    local threads=$1
    local base=$2
    
    # WEAK SCALING REALE: mantieni work per thread costante
    # Work per thread = base^2 = costante
    # Per N thread: total_work = N * base^2
    # Quindi: size = base * sqrt(N)
    python3 -c "
import math
# Formula matematicamente corretta per weak scaling
size = int($base * math.sqrt($threads))

# Assicura multiplo di 8 per cache alignment
size = ((size + 7) // 8) * 8

# Limita dimensioni per memoria disponibile (max ~16K per 128 thread)
max_size = 16000
if size > max_size:
    size = max_size

print(size)
"
}

# Configurazione ambiente ottimizzata
configure_environment() {
    local threads=$1
    
    export OMP_NUM_THREADS=$threads
    export OMP_WAIT_POLICY=passive
    export OMP_DYNAMIC=false
    export OMP_NESTED=false
    
    # NUMA placement per AMD EPYC 7H12
    if [ $threads -ge 96 ]; then
        export OMP_PLACES=cores
        export OMP_PROC_BIND=spread
    elif [ $threads -ge 32 ]; then
        export OMP_PLACES=cores
        export OMP_PROC_BIND=close
    else
        export OMP_PLACES=cores
        export OMP_PROC_BIND=close
    fi
}

# Test weak scaling corretto
echo "Inizio weak scaling con formula corretta..."
total_tests=${#THREAD_COUNTS[@]}
current_test=0

for THREADS in "${THREAD_COUNTS[@]}"; do
    current_test=$((current_test + 1))
    
    # Calcola dimensioni con formula CORRETTA
    SCALED_SIZE=$(calculate_weak_size $THREADS $BASE_SIZE)
    
    echo "[$current_test/$total_tests] Testing $THREADS threads, size: ${SCALED_SIZE}x${SCALED_SIZE}"
    
    # Verifica memoria richiesta
    MEMORY_MB=$((SCALED_SIZE * SCALED_SIZE * 4 / 1024 / 1024))
    echo "  Memoria richiesta: ${MEMORY_MB} MB"
    
    # Verifica limite memoria
    if [ $MEMORY_MB -gt 80000 ]; then  # Limite 80GB per sicurezza
        echo "  ⚠ Memoria troppo alta, saltando..."
        continue
    fi
    
    # Configura ambiente
    configure_environment $THREADS
    
    # Calcola lavoro per thread (dovrebbe essere ~costante)
    total_work=$((SCALED_SIZE * SCALED_SIZE))
    work_per_thread=$((total_work / THREADS))
    baseline_work=$((BASE_SIZE * BASE_SIZE))
    
    echo "  Work per thread: $work_per_thread punti (baseline: $baseline_work)"
    
    # Test multipli per accuratezza
    TIMES=()
    for run in {1..3}; do  # 3 run per weak scaling
        echo "  Run $run/3..."
        
        # Sincronizza filesystem
        sync 2>/dev/null || true
        
        OUTPUT=$(./mandelbrot_omp $CORES $THREADS $SCALED_SIZE $SCALED_SIZE $MAX_ITER 2>&1)
        EXIT_CODE=$?
        
        if [ $EXIT_CODE -eq 0 ] && [ -n "$OUTPUT" ]; then
            TIME=$(echo "$OUTPUT" | cut -d',' -f5)
            if [[ "$TIME" =~ ^[0-9]+\.?[0-9]*$ ]] && (( $(echo "$TIME > 0" | bc -l) )); then
                TIMES+=($TIME)
                echo "    ✓ Tempo: $TIME s"
            else
                echo "    ⚠ Tempo invalido: '$TIME'"
            fi
        else
            echo "    ⚠ Errore: exit=$EXIT_CODE"
        fi
        
        sleep 2
    done
    
    # Calcola mediana
    if [ ${#TIMES[@]} -ge 2 ]; then
        TIMES_STR=$(printf "%.6f," "${TIMES[@]}")
        TIMES_STR=${TIMES_STR%,}
        
        MEDIAN_TIME=$(python3 -c "
import statistics
times = [$TIMES_STR]
if len(times) >= 1:
    median = statistics.median(times)
    print(f'{median:.6f}')
else:
    print('0.0')
")
        
        # Salva nel CSV
        echo "$CORES,$THREADS,$SCALED_SIZE,$SCALED_SIZE,$MEDIAN_TIME" >> $OUTPUT_FILE
        echo "  ✓ Tempo mediano: $MEDIAN_TIME s (${#TIMES[@]} run validi)"
        
        # Calcola efficienza weak scaling
        if [ $current_test -eq 1 ]; then
            BASELINE_TIME=$MEDIAN_TIME
        fi
        
        if [ ! -z "$BASELINE_TIME" ] && [ ! -z "$MEDIAN_TIME" ]; then
            WEAK_EFFICIENCY=$(python3 -c "
baseline = $BASELINE_TIME
current = $MEDIAN_TIME
if baseline > 0 and current > 0:
    efficiency = (baseline / current) * 100
    print(f'{efficiency:.1f}')
else:
    print('0.0')
")
            echo "    Efficienza weak: ${WEAK_EFFICIENCY}%"
        fi
        
    else
        echo "  ✗ Troppi pochi run validi ($THREADS threads)"
    fi
    
    # Pausa adattiva
    if [ $THREADS -ge 96 ]; then
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

# Analisi finale
if [ -f "$OUTPUT_FILE" ]; then
    echo ""
    echo "=== SUMMARY WEAK SCALING ==="
    
    FIRST_TIME=$(sed -n '2p' $OUTPUT_FILE | cut -d',' -f5)
    LAST_TIME=$(tail -n1 $OUTPUT_FILE | cut -d',' -f5)
    LAST_THREADS=$(tail -n1 $OUTPUT_FILE | cut -d',' -f2)
    
    if [ ! -z "$FIRST_TIME" ] && [ ! -z "$LAST_TIME" ]; then
        FINAL_EFFICIENCY=$(python3 -c "
baseline = $FIRST_TIME  
final = $LAST_TIME
if baseline > 0 and final > 0:
    eff = (baseline / final) * 100
    print(f'{eff:.1f}')
else:
    print('0.0')
")
        
        echo "Tempo baseline (1 thread): ${FIRST_TIME}s"
        echo "Tempo finale ($LAST_THREADS thread): ${LAST_TIME}s" 
        echo "Efficienza weak finale: ${FINAL_EFFICIENCY}%"
        
        if (( $(echo "$FINAL_EFFICIENCY > 85" | bc -l) )); then
            echo "🎉 EXCELLENT weak scaling! Target 85% superato!"
        elif (( $(echo "$FINAL_EFFICIENCY > 75" | bc -l) )); then
            echo "✅ GOOD weak scaling!"
        else
            echo "⚠ Weak scaling needs improvement"
        fi
    fi
    
    # Verifica formula corretta
    echo ""
    echo "=== VERIFICA FORMULA ==="
    LINE_64=$(sed -n '65p' $OUTPUT_FILE)  # Thread 64
    if [ ! -z "$LINE_64" ]; then
        SIZE_64=$(echo "$LINE_64" | cut -d',' -f3)
        EXPECTED_64=$(python3 -c "import math; print(int(1000 * math.sqrt(64)))")
        echo "Thread 64: size=$SIZE_64, expected=$EXPECTED_64"
        
        if [ "$SIZE_64" -eq "$EXPECTED_64" ] || [ $((SIZE_64 - EXPECTED_64)) -lt 8 ]; then
            echo "✅ Formula weak scaling corretta!"
        else
            echo "⚠ Formula potrebbe avere problemi"
        fi
    fi
fi

echo ""
echo "$(date)"
