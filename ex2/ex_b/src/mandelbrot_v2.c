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
    double x2, y2;
    int iter = 0;
    
    // Loop unrolling per performance
    for (; iter < max_iter - 3; iter += 4) {
        // Iterazione 1
        x2 = x * x; y2 = y * y;
        if (x2 + y2 > 4.0) return iter;
        y = 2.0 * x * y + y0; x = x2 - y2 + x0;
        
        // Iterazione 2
        x2 = x * x; y2 = y * y;
        if (x2 + y2 > 4.0) return iter + 1;
        y = 2.0 * x * y + y0; x = x2 - y2 + x0;
        
        // Iterazione 3
        x2 = x * x; y2 = y * y;
        if (x2 + y2 > 4.0) return iter + 2;
        y = 2.0 * x * y + y0; x = x2 - y2 + x0;
        
        // Iterazione 4
        x2 = x * x; y2 = y * y;
        if (x2 + y2 > 4.0) return iter + 3;
        y = 2.0 * x * y + y0; x = x2 - y2 + x0;
    }
    
    // Cleanup finale
    for (; iter < max_iter; iter++) {
        x2 = x * x; y2 = y * y;
        if (x2 + y2 > 4.0) break;
        y = 2.0 * x * y + y0;
        x = x2 - y2 + x0;
    }
    
    return iter;
}

// Salva immagine PGM
void save_pgm(const char* filename, int* data, int width, int height, int max_val) {
    FILE* fp = fopen(filename, "wb");
    if (!fp) return;
    
    fprintf(fp, "P2\n# Mandelbrot Set\n%d %d\n255\n", width, height);
    
    for (int j = 0; j < height; j++) {
        for (int i = 0; i < width; i++) {
            int val = (int)(255.0 * data[j * width + i] / max_val);
            fprintf(fp, "%d ", val);
        }
        fprintf(fp, "\n");
    }
    fclose(fp);
}

// Versione con OpenMP Tasks per load balancing ottimale
void compute_mandelbrot_tasks(mandel_params_t* params, int* result) {
    const double dx = (params->x_max - params->x_min) / params->width;
    const double dy = (params->y_max - params->y_min) / params->height;
    
    // Granularità adattiva per tasks
    int num_threads = omp_get_max_threads();
    int tile_height = fmax(8, params->height / (num_threads * 8));
    
    #pragma omp parallel
    {
        #pragma omp single
        {
            // Crea tasks per righe di tile_height
            for (int j_start = 0; j_start < params->height; j_start += tile_height) {
                int j_end = fmin(j_start + tile_height, params->height);
                
                #pragma omp task firstprivate(j_start, j_end)
                {
                    for (int j = j_start; j < j_end; j++) {
                        double y0 = params->y_min + j * dy;
                        for (int i = 0; i < params->width; i++) {
                            double x0 = params->x_min + i * dx;
                            result[j * params->width + i] = 
                                mandelbrot_point(x0, y0, params->max_iter);
                        }
                    }
                }
            }
            
            #pragma omp taskwait
        }
    }
}

// Versione con loop collapse per distribuzione 2D
void compute_mandelbrot_collapse(mandel_params_t* params, int* result) {
    const double dx = (params->x_max - params->x_min) / params->width;
    const double dy = (params->y_max - params->y_min) / params->height;
    
    // Collapse 2D loop per migliore distribuzione del carico
    #pragma omp parallel for collapse(2) schedule(dynamic, 1)
    for (int j = 0; j < params->height; j++) {
        for (int i = 0; i < params->width; i++) {
            double x0 = params->x_min + i * dx;
            double y0 = params->y_min + j * dy;
            result[j * params->width + i] = mandelbrot_point(x0, y0, params->max_iter);
        }
    }
}

// Versione con scheduling dinamico ottimizzato
void compute_mandelbrot_dynamic(mandel_params_t* params, int* result) {
    const double dx = (params->x_max - params->x_min) / params->width;
    const double dy = (params->y_max - params->y_min) / params->height;
    
    int num_threads = omp_get_max_threads();
    
    // Chunk size adattivo basato sul problema e thread
    int chunk_size;
    if (num_threads <= 8) {
        chunk_size = fmax(1, params->height / (num_threads * 2));
    } else if (num_threads <= 32) {
        chunk_size = fmax(1, params->height / (num_threads * 4));
    } else {
        chunk_size = fmax(1, params->height / (num_threads * 8));
    }
    
    #pragma omp parallel for schedule(dynamic, chunk_size)
    for (int j = 0; j < params->height; j++) {
        double y0 = params->y_min + j * dy;
        for (int i = 0; i < params->width; i++) {
            double x0 = params->x_min + i * dx;
            result[j * params->width + i] = mandelbrot_point(x0, y0, params->max_iter);
        }
    }
}

// Versione con guided scheduling per bilanciamento
void compute_mandelbrot_guided(mandel_params_t* params, int* result) {
    const double dx = (params->x_max - params->x_min) / params->width;
    const double dy = (params->y_max - params->y_min) / params->height;
    
    #pragma omp parallel for schedule(guided, 4)
    for (int j = 0; j < params->height; j++) {
        double y0 = params->y_min + j * dy;
        for (int i = 0; i < params->width; i++) {
            double x0 = params->x_min + i * dx;
            result[j * params->width + i] = mandelbrot_point(x0, y0, params->max_iter);
        }
    }
}

// Versione con work-stealing (per molti thread)
void compute_mandelbrot_worksharing(mandel_params_t* params, int* result) {
    const double dx = (params->x_max - params->x_min) / params->width;
    const double dy = (params->y_max - params->y_min) / params->height;
    
    // Usa un approccio work-stealing con atomic counters
    int total_work = params->height;
    int work_index = 0;
    
    #pragma omp parallel
    {
        int local_j;
        while (1) {
            #pragma omp atomic capture
            local_j = work_index++;
            
            if (local_j >= total_work) break;
            
            double y0 = params->y_min + local_j * dy;
            for (int i = 0; i < params->width; i++) {
                double x0 = params->x_min + i * dx;
                result[local_j * params->width + i] = 
                    mandelbrot_point(x0, y0, params->max_iter);
            }
        }
    }
}

// Funzione principale con selezione algoritmo ottimale
double compute_mandelbrot(mandel_params_t* params, int num_threads, const char* output_file) {
    // Alloca memoria
    int* result = malloc(params->width * params->height * sizeof(int));
    if (!result) {
        fprintf(stderr, "Errore allocazione memoria\n");
        return -1.0;
    }
    
    // Configura OpenMP per performance ottimali
    omp_set_num_threads(num_threads);
    omp_set_dynamic(0);  // Thread fissi
    
    // Configura affinity NUMA-aware
    if (num_threads >= 64) {
        omp_set_proc_bind(omp_proc_bind_spread);
    } else if (num_threads >= 16) {
        omp_set_proc_bind(omp_proc_bind_close);
    } else {
        omp_set_proc_bind(omp_proc_bind_close);
    }
    
    double start_time = omp_get_wtime();
    
    // Selezione algoritmo basata su numero thread e dimensione problema
    if (num_threads >= 64 && params->height >= 1000) {
        // Molti thread + problema grande: Task-based
        compute_mandelbrot_tasks(params, result);
    } else if (num_threads >= 32) {
        // Thread medi: Guided scheduling
        compute_mandelbrot_guided(params, result);
    } else if (num_threads >= 8 && params->height >= 500) {
        // Thread medi + problema medio: Collapse 2D
        compute_mandelbrot_collapse(params, result);
    } else if (num_threads >= 4) {
        // Pochi thread: Dynamic scheduling
        compute_mandelbrot_dynamic(params, result);
    } else {
        // Pochissimi thread: Worksharing
        compute_mandelbrot_worksharing(params, result);
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
        return 1;
    }
    
    int cores = atoi(argv[1]);
    int threads = atoi(argv[2]);
    int width = atoi(argv[3]);
    int height = atoi(argv[4]);
    int max_iter = atoi(argv[5]);
    const char* output_file = (argc == 7) ? argv[6] : NULL;
    
    mandel_params_t params = {
        .x_min = -2.5, .x_max = 1.0,
        .y_min = -1.25, .y_max = 1.25,
        .width = width,
        .height = height,
        .max_iter = max_iter
    };
    
    double exec_time = compute_mandelbrot(&params, threads, output_file);
    
    if (exec_time > 0) {
        printf("%d,%d,%d,%d,%.6f\n", cores, threads, width, height, exec_time);
        fflush(stdout);
    } else {
        fprintf(stderr, "Errore durante l'esecuzione\n");
        return 1;
    }
    
    return 0;
}
