#!/bin/bash

# Script wrapper per generare immagini PGM dal mandelbrot.c originale

echo "=== GENERATORE IMMAGINI MANDELBROT ==="
echo "Usando mandelbrot.c originale per scaling"
echo ""

# Controllo argomenti
if [ $# -lt 7 ] || [ $# -gt 8 ]; then
    echo "Usage: $0 n_x n_y x_L y_L x_R y_R I_max [output_name]"
    echo "Example: $0 1000 1000 -2.5 -1.25 1.0 1.25 255 classic"
    echo ""
    echo "Esempi preconfigurati:"
    echo "  $0 classic     # Set classico 2048x2048"
    echo "  $0 zoom        # Zoom dettaglio 1024x1024"
    echo "  $0 spiral      # Spirale 1600x1600"
    echo "  $0 hd          # Alta risoluzione 4096x4096"
    exit 1
fi

# Configurazioni predefinite
if [ "$1" == "classic" ]; then
    set -- 2048 2048 -2.5 -1.25 1.0 1.25 255 "classic"
elif [ "$1" == "zoom" ]; then
    set -- 1024 1024 -0.8 -0.2 -0.4 0.2 1000 "zoom_detail"
elif [ "$1" == "spiral" ]; then
    set -- 1600 1600 -0.75 -0.1 -0.73 0.1 2000 "spiral_zoom"
elif [ "$1" == "hd" ]; then
    set -- 4096 4096 -2.5 -1.25 1.0 1.25 500 "hd_report"
fi

# Parametri
N_X=$1
N_Y=$2
X_L=$3
Y_L=$4
X_R=$5
Y_R=$6
I_MAX=$7
OUTPUT_NAME=${8:-"mandelbrot"}

echo "Parametri:"
echo "  Dimensioni: ${N_X}x${N_Y}"
echo "  Piano complesso: [${X_L},${X_R}] x [${Y_L},${Y_R}]"
echo "  Max iterazioni: ${I_MAX}"
echo "  Nome output: ${OUTPUT_NAME}"
echo ""

# Verifica che mandelbrot_omp esista
if [ ! -f "mandelbrot_omp" ]; then
    echo "Compilando mandelbrot_omp..."
    make clean && make all
    if [ $? -ne 0 ]; then
        echo "Errore nella compilazione!"
        exit 1
    fi
fi

# Crea directory per immagini
mkdir -p results/images

# Calcola numero di thread ottimale per immagini (usa molti thread)
OPTIMAL_THREADS=64
if [ $(nproc) -lt 64 ]; then
    OPTIMAL_THREADS=$(nproc)
fi

echo "Eseguendo calcolo con $OPTIMAL_THREADS thread..."

# Configura OpenMP per performance ottimali
export OMP_NUM_THREADS=$OPTIMAL_THREADS
export OMP_PLACES=cores
export OMP_PROC_BIND=close

# Genera nome file temporaneo PGM
TEMP_PGM="results/images/${OUTPUT_NAME}_temp.pgm"

# Esegui mandelbrot_omp e genera PGM
echo "Avviando calcolo Mandelbrot..."
start_time=$(date +%s.%N)

# Il tuo mandelbrot.c originale genera CSV, dobbiamo intercettare e convertire
./mandelbrot_omp 1 $OPTIMAL_THREADS $N_X $N_Y $I_MAX "$TEMP_PGM" 2>/dev/null

end_time=$(date +%s.%N)
execution_time=$(echo "$end_time - $start_time" | bc -l)

# Verifica che l'immagine sia stata generata
if [ -f "$TEMP_PGM" ]; then
    # Rinomina l'immagine finale
    FINAL_PGM="results/images/mandelbrot_${OUTPUT_NAME}.pgm"
    mv "$TEMP_PGM" "$FINAL_PGM"
    
    echo "✓ Immagine generata: $FINAL_PGM"
    echo "✓ Tempo di calcolo: ${execution_time}s"
    
    # Statistiche file
    file_size=$(stat -c%s "$FINAL_PGM")
    echo "✓ Dimensione file: $file_size bytes"
    
    # Conversione PNG se ImageMagick disponibile
    if command -v convert >/dev/null 2>&1; then
        echo "Convertendo in PNG..."
        PNG_FILE="results/images/mandelbrot_${OUTPUT_NAME}.png"
        convert "$FINAL_PGM" "$PNG_FILE" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            echo "✓ PNG generato: $PNG_FILE"
        else
            echo "⚠ Conversione PNG fallita"
        fi
    else
        echo "⚠ ImageMagick non disponibile per conversione PNG"
    fi
    
    # Performance stats
    total_pixels=$((N_X * N_Y))
    mpixels_per_sec=$(echo "scale=2; $total_pixels / ($execution_time * 1000000)" | bc -l)
    echo "✓ Performance: ${mpixels_per_sec} MPixels/sec"
    
else
    echo "✗ Errore: immagine non generata"
    echo "Verificando output mandelbrot_omp..."
    ./mandelbrot_omp 1 $OPTIMAL_THREADS $N_X $N_Y $I_MAX
    exit 1
fi

echo ""
echo "=== IMMAGINE COMPLETATA ==="
echo "File PGM: $FINAL_PGM"
if [ -f "results/images/mandelbrot_${OUTPUT_NAME}.png" ]; then
    echo "File PNG: results/images/mandelbrot_${OUTPUT_NAME}.png"
fi
echo "$(date)"
