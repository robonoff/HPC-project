/* 
 * Mandelbrot Set con OpenMP ottimizzato per 128 core
 * Genera output PGM e dati CSV per scaling analysis
 * 
 * File: src/mandelbrot.c
 */

#include <stdio.h>
#include <stdlib.h>
#include <omp.h>
#include <math.h>
#include <string.h>

typedef struct {
    double x_min, x_max, y_min, y_max;
    int width, height, max_iter;
} mandel_params_t;

// Funzione Mandelbrot ottimizzata
static inline int mandelbrot_point(double x0, double y0, int max_iter) {
    double x = 0.0, y = 0.0;
    double x2 = 0.0, y2 = 0.0;
    int iter = 0;
    
    // Ottimizzazione: evita calcoli ridondanti
    while (x2 + y2 <= 4.0 && iter < max_iter) {
        y = 2.0 * x * y + y0;
        x = x2 - y2 + x0;
        x2 = x * x;
        y2 = y * y;
        iter++;
    }
    return iter;
}

// Salva immagine in formato PGM
void save_pgm(const char* filename, int* data, int width, int height, int max_val) {
    FILE* fp = fopen(filename, "wb");
    if (!fp) {
        fprintf(stderr, "Errore: impossibile creare %s\n", filename);
        return;
    }
    
    // Header PGM
    fprintf(fp, "P2\n");
    fprintf(fp, "# Mandelbrot Set\n");
    fprintf(fp, "%d %d\n", width, height);
    fprintf(fp, "255\n");
    
    // Dati immagine
    for (int j = 0; j < height; j++) {
        for (int i = 0; i < width; i++) {
            int val = (int)(255.0 * data[j * width + i] / max_val);
            fprintf(fp, "%d ", val);
        }
        fprintf(fp, "\n");
    }
    
    fclose(fp);
}

// Calcolo Mandelbrot parallelizzato ottimizzato
double compute_mandelbrot(mandel_params_t* params, int num_threads, const char* output_file) {
    const double dx = (params->x_max - params->x_min) / params->width;
    const double dy = (params->y_max - params->y_min) / params->height;
    
    // Alloca memoria per risultati
    int* result = malloc(params->width * params->height * sizeof(int));
    if (!result) {
        fprintf(stderr, "Errore allocazione memoria\n");
        return -1.0;
    }
    
    // Configura OpenMP
    omp_set_num_threads(num_threads);
    
    // Chunk size ottimizzato per diversi thread count
    int chunk_size;
    
    if (num_threads <= 8) {
        chunk_size = fmax(1, params->height / (num_threads * 2));
    } else if (num_threads <= 32) {
        chunk_size = fmax(1, params->height / (num_threads * 4));
    } else if (num_threads <= 64) {
        chunk_size = fmax(1, params->height / (num_threads * 8));
    } else {
        // Per 64+ thread, chunk molto piccoli
        chunk_size = fmax(1, params->height / (num_threads * 16));
    }
    
    double start_time = omp_get_wtime();
    
    // Parallelizzazione ottimizzata basata sul numero di thread
    if (num_threads >= 64) {
        // Per molti thread: guided scheduling per migliore bilanciamento
        #pragma omp parallel for schedule(guided, chunk_size)
        for (int j = 0; j < params->height; j++) {
            for (int i = 0; i < params->width; i++) {
                double x0 = params->x_min + i * dx;
                double y0 = params->y_min + j * dy;
                result[j * params->width + i] = mandelbrot_point(x0, y0, params->max_iter);
            }
        }
    } else {
        // Per pochi thread: dynamic scheduling
        #pragma omp parallel for schedule(dynamic, chunk_size)
        for (int j = 0; j < params->height; j++) {
            for (int i = 0; i < params->width; i++) {
                double x0 = params->x_min + i * dx;
                double y0 = params->y_min + j * dy;
                result[j * params->width + i] = mandelbrot_point(x0, y0, params->max_iter);
            }
        }
    }
    
    double end_time = omp_get_wtime();
    double execution_time = end_time - start_time;
    
    // Salva immagine se richiesto
    if (output_file) {
        save_pgm(output_file, result, params->width, params->height, params->max_iter);
    }
    
    free(result);
    return execution_time;
}

int main(int argc, char* argv[]) {
    if (argc != 6 && argc != 7) {
        fprintf(stderr, "Uso: %s <cores> <threads> <width> <height> <max_iter> [output.pgm]\n", argv[0]);
        fprintf(stderr, "Per benchmark: %s 1 <threads> <width> <height> <max_iter>\n", argv[0]);
        fprintf(stderr, "Per immagine:  %s 1 <threads> <width> <height> <max_iter> output.pgm\n", argv[0]);
        return 1;
    }
    
    int cores = atoi(argv[1]);
    int threads = atoi(argv[2]);
    int width = atoi(argv[3]);
    int height = atoi(argv[4]);
    int max_iter = atoi(argv[5]);
    const char* output_file = (argc == 7) ? argv[6] : NULL;
    
    // Parametri Mandelbrot set classico
    mandel_params_t params = {
        .x_min = -2.5, .x_max = 1.0,
        .y_min = -1.25, .y_max = 1.25,
        .width = width,
        .height = height,
        .max_iter = max_iter
    };
    
    // Esegui calcolo
    double exec_time = compute_mandelbrot(&params, threads, output_file);
    
    if (exec_time > 0) {
        // Output formato CSV per benchmark
        printf("%d,%d,%d,%d,%.6f\n", cores, threads, width, height, exec_time);
        fflush(stdout);
        
        if (output_file) {
            fprintf(stderr, "Immagine salvata: %s\n", output_file);
            fprintf(stderr, "Tempo esecuzione: %.6f secondi\n", exec_time);
        }
    } else {
        fprintf(stderr, "Errore durante l'esecuzione\n");
        return 1;
    }
    
    return 0;
}
