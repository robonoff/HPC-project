/* 
 * Mandelbrot Set Ultra-Ottimizzato per AMD EPYC 7H12 (128 cores, 8 NUMA nodes)
 * Ottimizzazioni: Soglie corrette, Multi-algorithm, Cache-aware, NUMA-optimized
 */

#include <stdio.h>
#include <stdlib.h>
#include <omp.h>
#include <math.h>
#include <string.h>
#include <immintrin.h>

typedef struct {
    double x_min, x_max, y_min, y_max;
    int width, height, max_iter;
} mandel_params_t;

// Funzione Mandelbrot con loop unrolling ottimizzato
static inline int mandelbrot_point_optimized(double x0, double y0, int max_iter) {
    double x = 0.0, y = 0.0;
    double x2, y2;
    int iter = 0;
    
    // Loop unrolling 4x (bilanciamento performance/overhead)
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

// Versione guided ultra-ottimizzata (BEST per 32-95 thread)
void compute_mandelbrot_guided_optimized(mandel_params_t* params, int* result) {
    const double dx = (params->x_max - params->x_min) / params->width;
    const double dy = (params->y_max - params->y_min) / params->height;
    
    int num_threads = omp_get_max_threads();
    
    // Chunk size ottimizzato per guided scheduling
    int chunk_size;
    if (num_threads >= 64) {
        chunk_size = fmax(2, params->height / (num_threads * 8));
    } else if (num_threads >= 32) {
        chunk_size = fmax(4, params->height / (num_threads * 4));
    } else {
        chunk_size = fmax(8, params->height / (num_threads * 2));
    }
    
    #pragma omp parallel for schedule(guided, chunk_size)
    for (int j = 0; j < params->height; j++) {
        double y0 = params->y_min + j * dy;
        
        // Prefetch ottimizzato
        if (j + 1 < params->height) {
            __builtin_prefetch(&result[(j + 1) * params->width], 1, 2);
        }
        
        for (int i = 0; i < params->width; i++) {
            double x0 = params->x_min + i * dx;
            result[j * params->width + i] = 
                mandelbrot_point_optimized(x0, y0, params->max_iter);
        }
    }
}

// Versione NUMA-aware con tasks ottimizzati (BEST per 96+ thread)
void compute_mandelbrot_numa_tasks(mandel_params_t* params, int* result) {
    const double dx = (params->x_max - params->x_min) / params->width;
    const double dy = (params->y_max - params->y_min) / params->height;
    
    int num_threads = omp_get_max_threads();
    
    // Granularità più grossa per ridurre overhead task
    int tile_height;
    if (num_threads >= 112) {
        // 112-128 thread: tile medi per balance load/overhead
        tile_height = fmax(8, params->height / (num_threads * 2));
    } else if (num_threads >= 96) {
        // 96-111 thread: tile leggermente più grandi
        tile_height = fmax(12, params->height / (num_threads * 1.5));
    } else {
        // Fallback per <96 thread
        tile_height = fmax(16, params->height / num_threads);
    }
    
    #pragma omp parallel
    {
        #pragma omp single
        {
            for (int j_start = 0; j_start < params->height; j_start += tile_height) {
                int j_end = fmin(j_start + tile_height, params->height);
                
                #pragma omp task firstprivate(j_start, j_end)
                {
                    for (int j = j_start; j < j_end; j++) {
                        double y0 = params->y_min + j * dy;
                        
                        // Prefetch intelligente
                        if (j + 1 < j_end) {
                            __builtin_prefetch(&result[(j + 1) * params->width], 1, 3);
                        }
                        
                        for (int i = 0; i < params->width; i++) {
                            double x0 = params->x_min + i * dx;
                            result[j * params->width + i] = 
                                mandelbrot_point_optimized(x0, y0, params->max_iter);
                        }
                    }
                }
            }
            #pragma omp taskwait
        }
    }
}

// Versione dynamic ottimizzata (BEST per 8-31 thread)
void compute_mandelbrot_dynamic_optimized(mandel_params_t* params, int* result) {
    const double dx = (params->x_max - params->x_min) / params->width;
    const double dy = (params->y_max - params->y_min) / params->height;
    
    int num_threads = omp_get_max_threads();
    
    // Chunk size adattivo per dynamic
    int chunk_size;
    if (num_threads >= 16) {
        chunk_size = fmax(4, params->height / (num_threads * 3));
    } else {
        chunk_size = fmax(8, params->height / (num_threads * 2));
    }
    
    #pragma omp parallel for schedule(dynamic, chunk_size)
    for (int j = 0; j < params->height; j++) {
        double y0 = params->y_min + j * dy;
        
        for (int i = 0; i < params->width; i++) {
            double x0 = params->x_min + i * dx;
            result[j * params->width + i] = 
                mandelbrot_point_optimized(x0, y0, params->max_iter);
        }
    }
}

// Versione static per pochi thread (BEST per 1-7 thread)
void compute_mandelbrot_static_optimized(mandel_params_t* params, int* result) {
    const double dx = (params->x_max - params->x_min) / params->width;
    const double dy = (params->y_max - params->y_min) / params->height;
    
    int num_threads = omp_get_max_threads();
    int chunk_size = fmax(1, params->height / num_threads);
    
    #pragma omp parallel for schedule(static, chunk_size)
    for (int j = 0; j < params->height; j++) {
        double y0 = params->y_min + j * dy;
        
        for (int i = 0; i < params->width; i++) {
            double x0 = params->x_min + i * dx;
            result[j * params->width + i] = 
                mandelbrot_point_optimized(x0, y0, params->max_iter);
        }
    }
}

// Funzione principale con soglie PERFETTAMENTE ottimizzate per AMD EPYC
double compute_mandelbrot(mandel_params_t* params, int num_threads, const char* output_file) {
    // Alloca memoria allineata
    size_t total_size = params->width * params->height * sizeof(int);
    int* result = aligned_alloc(64, total_size);
    if (!result) {
        fprintf(stderr, "Errore allocazione memoria\n");
        return -1.0;
    }
    
    // Configura OpenMP
    omp_set_num_threads(num_threads);
    omp_set_dynamic(0);
    omp_set_nested(0);
    
    double start_time = omp_get_wtime();
    
    // SOGLIE OTTIMIZZATE per massima efficienza
    if (num_threads >= 96) {
        // 96-128 thread: NUMA-aware tasks (overhead giustificato)
        compute_mandelbrot_numa_tasks(params, result);
    } else if (num_threads >= 32) {
        // 32-95 thread: Guided scheduling (SWEET SPOT!)
        compute_mandelbrot_guided_optimized(params, result);
    } else if (num_threads >= 8) {
        // 8-31 thread: Dynamic scheduling (load balancing)
        compute_mandelbrot_dynamic_optimized(params, result);
    } else {
        // 1-7 thread: Static scheduling (minimal overhead)
        compute_mandelbrot_static_optimized(params, result);
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
