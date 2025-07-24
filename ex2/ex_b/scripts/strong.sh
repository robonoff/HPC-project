#!/bin/bash
#SBATCH --job-name=strong_fixed
#SBATCH --output=results/strong_scaling_%j.out
#SBATCH --error=results/strong_scaling_%j.err
#SBATCH --time=01:30:00
#SBATCH --partition=EPYC
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=128
#SBATCH --mem=64GB
#SBATCH --exclusive

echo "=== MANDELBROT STRONG SCALING FIXED ==="
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

# Parametri ottimizzati per strong scaling
CORES=1
WIDTH=8000      # Problema grande per evidenziare scaling
HEIGHT=8000     
MAX_ITER=500    # Bilanciamento compute/overhead

# File di output
OUTPUT_FILE="results/omp_strong_scaling.csv"

# Thread da testare (sequenza completa)
THREAD_COUNTS=($(seq 1 128))

echo "Parametri strong scaling ottimizzati:"
echo "- Dimensioni fisse: ${WIDTH}x${HEIGHT}"
echo "- Max iterazioni: ${MAX_ITER}"
echo "- Thread testati: ${#THREAD_COUNTS[@]} configurazioni"
echo "- Soglie ottimizzate: 8/32/96 per minimizzare salti"
echo "- Output: ${OUTPUT_FILE}"
echo ""

# Header CSV
echo "cores,threads,width,height,time" > $OUTPUT_FILE

# Configurazione ambiente ottimizzata
configure_environment() {
    local threads=$1
    
    export OMP_NUM_THREADS=$threads
    export OMP_WAIT_POLICY=passive
    export OMP_DYNAMIC=false
    export OMP_NESTED=false
    
    # NUMA placement per AMD EPYC 7H12 (ottimizzato)
    if [ $threads -ge 96 ]; then
        # 96+ thread: Spread per NUMA-aware tasks
        export OMP_PLACES=cores
        export OMP_PROC_BIND=spread
    elif [ $threads -ge 32 ]; then
        # 32-95 thread: Close per guided scheduling
        export OMP_PLACES=cores
        export OMP_PROC_BIND=close
    elif [ $threads -ge 16 ]; then
        # 16-31 thread: Close per dynamic
        export OMP_PLACES=cores
        export OMP_PROC_BIND=close
    else
        # 1-15 thread: Close per static
        export OMP_PLACES=cores
        export OMP_PROC_BIND=close
    fi
}

# Funzione per warm-up
warmup_cache() {
    echo "  Cache warm-up..."
    OMP_NUM_THREADS=1 ./mandelbrot_omp 1 1 1000 1000 100 >/dev/null 2>&1
}

# Test strong scaling ottimizzato
echo "Inizio strong scaling con soglie ottimizzate..."
total_tests=${#THREAD_COUNTS[@]}
current_test=0

for THREADS in "${THREAD_COUNTS[@]}"; do
    current_test=$((current_test + 1))
    
    echo "[$current_test/$total_tests] Testing $THREADS threads (${WIDTH}x${HEIGHT})"
    
    # Mostra quale algoritmo verrà usato
    if [ $THREADS -ge 96 ]; then
        echo "  Algoritmo: NUMA-aware tasks"
    elif [ $THREADS -ge 32 ]; then
        echo "  Algoritmo: Guided scheduling"
    elif [ $THREADS -ge 8 ]; then
        echo "  Algoritmo: Dynamic scheduling"
    else
        echo "  Algoritmo: Static scheduling"
    fi
    
    # Configura ambiente
    configure_environment $THREADS
    
    # Warm-up per stabilizzare performance
    if [ $((current_test % 10)) -eq 1 ]; then  # Warm-up ogni 10 test
        warmup_cache
    fi
    
    # Test multipli per accuratezza
    TIMES=()
    for run in {1..3}; do  # 3 run per velocizzare
        echo "  Run $run/3..."
        
        # Sincronizza filesystem
        sync 2>/dev/null || true
        
        OUTPUT=$(./mandelbrot_omp $CORES $THREADS $WIDTH $HEIGHT $MAX_ITER 2>&1)
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
        
        sleep 1
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
        echo "$CORES,$THREADS,$WIDTH,$HEIGHT,$MEDIAN_TIME" >> $OUTPUT_FILE
        echo "  ✓ Tempo mediano: $MEDIAN_TIME s (${#TIMES[@]} run validi)"
        
        # Calcola speedup e efficienza in tempo reale
        if [ $current_test -eq 1 ]; then
            BASELINE_TIME=$MEDIAN_TIME
        fi
        
        if [ ! -z "$BASELINE_TIME" ] && [ ! -z "$MEDIAN_TIME" ]; then
            SPEEDUP=$(python3 -c "
baseline = $BASELINE_TIME
current = $MEDIAN_TIME  
if baseline > 0 and current > 0:
    speedup = baseline / current
    print(f'{speedup:.2f}')
else:
    print('0.0')
")
            EFFICIENCY=$(python3 -c "
baseline = $BASELINE_TIME
current = $MEDIAN_TIME
threads = $THREADS
if baseline > 0 and current > 0 and threads > 0:
    speedup = baseline / current
    efficiency = (speedup / threads) * 100
    print(f'{efficiency:.1f}')
else:
    print('0.0')
")
            echo "    Speedup: ${SPEEDUP}x, Efficienza: ${EFFICIENCY}%"
        fi
        
    else
        echo "  ✗ Troppi pochi run validi ($THREADS threads)"
    fi
    
    # Pausa adattiva
    if [ $THREADS -ge 96 ]; then
        sleep 3
    elif [ $THREADS -ge 32 ]; then
        sleep 2
    else
        sleep 1
    fi
done

echo ""
echo "=== STRONG SCALING COMPLETATO ==="
echo "File risultati: $OUTPUT_FILE"
echo "Righe generate: $(wc -l < $OUTPUT_FILE)"

# Analisi finale dettagliata
if [ -f "$OUTPUT_FILE" ]; then
    echo ""
    echo "=== SUMMARY STRONG SCALING ==="
    
    FIRST_TIME=$(sed -n '2p' $OUTPUT_FILE | cut -d',' -f5)
    LAST_TIME=$(tail -n1 $OUTPUT_FILE | cut -d',' -f5)  
    LAST_THREADS=$(tail -n1 $OUTPUT_FILE | cut -d',' -f2)
    
    if [ ! -z "$FIRST_TIME" ] && [ ! -z "$LAST_TIME" ]; then
        MAX_SPEEDUP=$(python3 -c "
baseline = $FIRST_TIME
final = $LAST_TIME
if baseline > 0 and final > 0:
    speedup = baseline / final
    print(f'{speedup:.1f}')
else:
    print('0.0')
")
        FINAL_EFFICIENCY=$(python3 -c "
baseline = $FIRST_TIME
final = $LAST_TIME  
threads = $LAST_THREADS
if baseline > 0 and final > 0 and threads > 0:
    speedup = baseline / final
    efficiency = (speedup / threads) * 100
    print(f'{efficiency:.1f}')
else:
    print('0.0')
")
        
        echo "Tempo baseline (1 thread): ${FIRST_TIME}s"
        echo "Tempo finale ($LAST_THREADS thread): ${LAST_TIME}s"
        echo "Speedup massimo: ${MAX_SPEEDUP}x con $LAST_THREADS threads"
        echo "Efficienza finale: ${FINAL_EFFICIENCY}%"
        
        if (( $(echo "$FINAL_EFFICIENCY > 85" | bc -l) )); then
            echo "🎉 EXCELLENT strong scaling! Target 85% superato!"
        elif (( $(echo "$FINAL_EFFICIENCY > 75" | bc -l) )); then
            echo "✅ GOOD strong scaling!"
        else
            echo "⚠ Strong scaling needs improvement"
        fi
    fi
    
    # Analisi transizioni algoritmi
    echo ""
    echo "=== ANALISI TRANSIZIONI ALGORITMI ==="
    
    # Transizione 7->8 (static->dynamic)
    TIME_7=$(sed -n '8p' $OUTPUT_FILE | cut -d',' -f5 2>/dev/null)
    TIME_8=$(sed -n '9p' $OUTPUT_FILE | cut -d',' -f5 2>/dev/null)
    if [ ! -z "$TIME_7" ] && [ ! -z "$TIME_8" ]; then
        JUMP_8=$(python3 -c "
t7 = $TIME_7
t8 = $TIME_8
if t7 > 0 and t8 > 0:
    jump = ((t7 - t8) / t7) * 100
    print(f'{jump:.1f}')
else:
    print('0.0')
")
        echo "Transizione 7→8 thread (static→dynamic): ${JUMP_8}% miglioramento"
    fi
    
    # Transizione 31->32 (dynamic->guided)
    TIME_31=$(sed -n '32p' $OUTPUT_FILE | cut -d',' -f5 2>/dev/null)
    TIME_32=$(sed -n '33p' $OUTPUT_FILE | cut -d',' -f5 2>/dev/null)
    if [ ! -z "$TIME_31" ] && [ ! -z "$TIME_32" ]; then
        JUMP_32=$(python3 -c "
t31 = $TIME_31  
t32 = $TIME_32
if t31 > 0 and t32 > 0:
    jump = ((t31 - t32) / t31) * 100
    print(f'{jump:.1f}')
else:
    print('0.0')
")
        echo "Transizione 31→32 thread (dynamic→guided): ${JUMP_32}% miglioramento"
    fi
    
    # Transizione 95->96 (guided->NUMA-tasks)
    TIME_95=$(sed -n '96p' $OUTPUT_FILE | cut -d',' -f5 2>/dev/null)
    TIME_96=$(sed -n '97p' $OUTPUT_FILE | cut -d',' -f5 2>/dev/null) 
    if [ ! -z "$TIME_95" ] && [ ! -z "$TIME_96" ]; then
        JUMP_96=$(python3 -c "
t95 = $TIME_95
t96 = $TIME_96  
if t95 > 0 and t96 > 0:
    jump = ((t95 - t96) / t95) * 100
    print(f'{jump:.1f}')
else:
    print('0.0')
")
        echo "Transizione 95→96 thread (guided→NUMA-tasks): ${JUMP_96}% miglioramento"
        
        if (( $(echo "$JUMP_96 < 0" | bc -l) )); then
            echo "  ⚠ Transizione negativa - NUMA-tasks ha overhead!"
        else
            echo "  ✅ Transizione positiva - NUMA-tasks efficace!"
        fi
    fi
fi

echo ""
echo "=== GENERAZIONE IMMAGINE ==="
echo "Generando immagine con configurazione ottimale..."

# Trova thread count con migliore efficienza
BEST_THREADS=$(python3 -c "
import csv
best_eff = 0
best_threads = 64

try:
    with open('$OUTPUT_FILE', 'r') as f:
        reader = csv.DictReader(f)
        data = list(reader)
    
    if len(data) >= 2:
        baseline = float(data[0]['time'])
        
        for row in data:
            threads = int(row['threads'])
            time = float(row['time'])
            if baseline > 0 and time > 0:
                speedup = baseline / time
                efficiency = (speedup / threads) * 100
                if efficiency > best_eff:
                    best_eff = efficiency
                    best_threads = threads
except:
    pass

print(best_threads)
")

echo "Generando immagine con $BEST_THREADS threads (efficienza ottimale)..."

configure_environment $BEST_THREADS
./mandelbrot_omp 1 $BEST_THREADS 2048 2048 1000 results/mandelbrot_strong.pgm

if [ -f "results/mandelbrot_strong.pgm" ]; then
    echo "✓ Immagine salvata: results/mandelbrot_strong.pgm"
    echo "  Risoluzione: 2048x2048, Thread: $BEST_THREADS, Iterazioni: 1000"
    
    if command -v convert >/dev/null 2>&1; then
        convert results/mandelbrot_strong.pgm results/mandelbrot_strong.png 2>/dev/null && \
        echo "✓ PNG: results/mandelbrot_strong.png"
    fi
fi

echo ""
echo "$(date)"
