#!/bin/bash
#SBATCH --job-name=strong
#SBATCH --output=results/strong_scaling_%j.out
#SBATCH --error=results/strong_scaling_%j.err
#SBATCH --time=01:59:00
#SBATCH --partition=EPYC
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=128
#SBATCH --mem=64GB

echo "=== MANDELBROT STRONG SCALING TEST ==="
echo "Data: $(date)"
echo "Nodo: $(hostname)"
echo "CPU disponibili: $(nproc)"
echo ""

# Crea directory results se non esiste
mkdir -p results

# Carica moduli se necessario (adatta al tuo sistema)
# module load gcc/11.2.0

# Compila il programma
echo "Compilando mandelbrot..."
gcc -O3 -march=native -ffast-math -fopenmp -Wall -o mandelbrot_omp mandelbrot/mandelbrot.c -lm

if [ $? -ne 0 ]; then
    echo "Errore nella compilazione!"
    exit 1
fi

# Parametri fissi per strong scaling
CORES=1
WIDTH=10000
HEIGHT=10000
MAX_ITER=1000

# File di output
OUTPUT_FILE="results/omp_strong_scaling.csv"

# Thread da testare (1 a 128)
THREAD_COUNTS=($(seq 1 128))

echo "Parametri test:"
echo "- Dimensioni: ${WIDTH}x${HEIGHT}"
echo "- Max iterazioni: ${MAX_ITER}"
echo "- Thread testati: ${#THREAD_COUNTS[@]} configurazioni"
echo "- Output: ${OUTPUT_FILE}"
echo ""

# Header CSV
echo "cores,threads,width,height,time" > $OUTPUT_FILE

# Funzione per configurare environment OpenMP
configure_openmp() {
    local threads=$1
    
    # Environment OpenMP base
    export OMP_NUM_THREADS=$threads
    export OMP_WAIT_POLICY=passive
    export OMP_DYNAMIC=false
    
    # Configurazione NUMA-aware per AMD EPYC
    if [ $threads -le 16 ]; then
        # Usa solo primo nodo NUMA
        export OMP_PROC_BIND=close
        export OMP_PLACES=cores
        export GOMP_CPU_AFFINITY="0-15"
    elif [ $threads -le 32 ]; then
        # Usa primi due nodi NUMA
        export OMP_PROC_BIND=close
        export OMP_PLACES=cores
        export GOMP_CPU_AFFINITY="0-31"
    elif [ $threads -le 64 ]; then
        # Usa primi 4 nodi NUMA
        export OMP_PROC_BIND=spread
        export OMP_PLACES=cores
        unset GOMP_CPU_AFFINITY
    else
        # Usa tutti i nodi NUMA
        export OMP_PROC_BIND=spread
        export OMP_PLACES=cores
        unset GOMP_CPU_AFFINITY
    fi
}

# Esegui test per ogni configurazione di thread
echo "Inizio test strong scaling..."
total_tests=${#THREAD_COUNTS[@]}
current_test=0

for THREADS in "${THREAD_COUNTS[@]}"; do
    current_test=$((current_test + 1))
    echo "[$current_test/$total_tests] Testing $THREADS threads..."
    
    # Configura environment OpenMP
    configure_openmp $THREADS
    
    echo "  OMP_NUM_THREADS: $OMP_NUM_THREADS"
    echo "  OMP_PROC_BIND: $OMP_PROC_BIND"
    
    # Esegui test multipli per maggiore accuratezza - SEZIONE CORRETTA
    TIMES=()
    for run in {1..3}; do
        echo "  Run $run/3..."
        
        # Esegui il programma e cattura sia output che exit code
        OUTPUT=$(./mandelbrot_omp $CORES $THREADS $WIDTH $HEIGHT $MAX_ITER 2>&1)
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
    
    # Calcola tempo medio se abbiamo almeno un risultato valido - CORREZIONE PYTHON
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
        
        # Scrivi risultato nel CSV
        echo "$CORES,$THREADS,$WIDTH,$HEIGHT,$AVG_TIME" >> $OUTPUT_FILE
        echo "  ✓ Tempo medio: $AVG_TIME s (${#TIMES[@]} run validi)"
    else
        echo "  ✗ Nessun run valido per $THREADS threads"
    fi
    
    # Pausa proporzionale per evitare overhead
    if [ $THREADS -ge 64 ]; then
        sleep 3
    else
        sleep 2
    fi
done

echo ""
echo "=== STRONG SCALING COMPLETATO ==="
echo "File risultati: $OUTPUT_FILE"
echo "Righe generate: $(wc -l < $OUTPUT_FILE)"
echo "$(date)"
