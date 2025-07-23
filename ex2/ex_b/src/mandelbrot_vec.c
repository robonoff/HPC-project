/* 
 * Mandelbrot Set Ultra-Ottimizzato per Strong/Weak Scaling
 * Ottimizzazioni: SIMD, Cache-friendly, NUMA-aware, Task-based
 */

#include <stdio.h>
#include <stdlib.h>
#include <omp.h>
#include <math.h>
#include <string.h>
#include <immintrin.h>  // Per SIMD AVX

typedef struct {
    double x_min, x_max, y_min, y_max;
    int width, height, max_iter;
} mandel_params_t;

// Versione SIMD AVX per 4 punti paralleli
static inline void mandelbrot_avx(double x0_base, double y0, double dx, 
                                  int max_iter, int* results) {
    // 4 punti consecutivi con AVX
    __m256d x0_vec = _mm256_set_pd(x0_base + 3*dx, x0_base + 2*dx, 
                                   x0_base + dx, x0_base);
    __m256d y0_vec = _mm256_set1_pd(y0);
    __m256d x_vec = _mm256_setzero_pd();
    __m256d y_vec = _mm256_setzero_pd();
    __m256d four = _mm256_set1_pd(4.0);
    __m256d two = _mm256_set1_pd(2.0);
    
    int iters[4] = {0, 0, 0, 0};
    
    for (int iter = 0; iter < max_iter; iter++) {
        __m256d x2 = _mm256_mul_pd(x_vec, x_vec);
        __m256d y2 = _mm256_mul_pd(y_vec, y_vec);
        __m256d magnitude = _mm256_add_pd(x2, y2);
        
        // Check convergenza
        __m256d mask = _mm256_cmp_pd(magnitude, four, _CMP_LE_OQ);
        int mask_int = _mm256_movemask_pd(mask);
        
        if (mask_int == 0) break; // Tutti diverged
        
        // Update solo punti non diverged
        __m256d xy = _mm256_mul_pd(x_vec, y_vec);
        __m256d new_y = _mm256_add_pd(_mm256_mul_pd(two, xy), y0_vec);
        __m256d new_x = _mm256_add_pd(_mm256_sub_pd(x2, y2), x0_vec);
        
        x_vec = _mm256_blendv_pd(x_vec, new_x, mask);
        y_vec = _mm256_blendv_pd(y_vec, new_y, mask);
        
        // Update contatori
        for (int i = 0; i < 4; i++) {
            if ((mask_int & (1 << i)) && iters[i] == iter) {
                iters[i] = iter + 1;
            }
        }
    }
    
    results[0] = iters[0];
    results[1] = iters[1]; 
    results[2] = iters[2];
    results[3] = iters[3];
}

// Versione scalare ottimizzata fallback
static inline int mandelbrot_point_optimized(double x0, double y0, int max_iter) {
    double x = 0.0, y = 0.0;
    double x2, y2;
    int iter = 0;
    
    // Loop unrolling + early termination
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
    
    // Cleanup loop
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

// Versione con OpenMP Tasks per load balancing dinamico
void compute_mandelbrot_tasks(mandel_params_t* params, int* result) {
    const double dx = (params->x_max - params->x_min) / params->width;
    const double dy = (params->y_max - params->y_min) / params->height;
    
    // Task-based parallelization con granularità adattiva
    int num_threads = omp_get_max_threads();
    int tile_size = fmax(32, params->height / (num_threads * 4));
    
    #pragma omp parallel
    {
        #pragma omp single
        {
            for (int j = 0; j < params->height; j += tile_size) {
                int j_end = fmin(j + tile_size, params->height);
                
                #pragma omp task firstprivate(j, j_end)
                {
                    for (int row = j; row < j_end; row++) {
                        double y0 = params->y_min + row * dy;
                        int i = 0;
                        
                        // Usa SIMD quando possibile (multipli di 4)
                        for (; i < params->width - 3; i += 4) {
                            double x0_base = params->x_min + i * dx;
                            int avx_results[4];
                            mandelbrot_avx(x0_base, y0, dx, params->max_iter, avx_results);
                            
                            for (int k = 0; k < 4; k++) {
                                result[row * params->width + i + k] = avx_results[k];
                            }
                        }
                        
                        // Cleanup per elementi rimanenti
                        for (; i < params->width; i++) {
                            double x0 = params->x_min + i * dx;
                            result[row * params->width + i] = 
                                mandelbrot_point_optimized(x0, y0, params->max_iter);
                        }
                    }
                }
            }
        }
    }
}

// Versione standard ottimizzata con scheduling adattivo
void compute_mandelbrot_standard(mandel_params_t* params, int* result) {
    const double dx = (params->x_max - params->x_min) / params->width;
    const double dy = (params->y_max - params->y_min) / params->height;
    
    int num_threads = omp_get_max_threads();
    
    // Scheduling adattivo basato su numero thread e dimensione problema
    if (num_threads <= 16) {
        // Per pochi thread: chunk grandi, dynamic scheduling
        int chunk_size = fmax(1, params->height / (num_threads * 2));
        #pragma omp parallel for schedule(dynamic, chunk_size)
        for (int j = 0; j < params->height; j++) {
            double y0 = params->y_min + j * dy;
            for (int i = 0; i < params->width; i++) {
                double x0 = params->x_min + i * dx;
                result[j * params->width + i] = 
                    mandelbrot_point_optimized(x0, y0, params->max_iter);
            }
        }
    } else if (num_threads <= 64) {
        // Per thread medi: guided scheduling
        #pragma omp parallel for schedule(guided, 16)
        for (int j = 0; j < params->height; j++) {
            double y0 = params->y_min + j * dy;
            for (int i = 0; i < params->width; i++) {
                double x0 = params->x_min + i * dx;
                result[j * params->width + i] = 
                    mandelbrot_point_optimized(x0, y0, params->max_iter);
            }
        }
    } else {
        // Per molti thread: task-based approach
        compute_mandelbrot_tasks(params, result);
        return;
    }
}

// Funzione principale di calcolo
double compute_mandelbrot(mandel_params_t* params, int num_threads, const char* output_file) {
    // Alloca memoria allineata per SIMD
    size_t total_size = params->width * params->height * sizeof(int);
    int* result = (int*)aligned_alloc(32, total_size);
    if (!result) {
        fprintf(stderr, "Errore allocazione memoria\n");
        return -1.0;
    }
    
    // Configura OpenMP per performance ottimali
    omp_set_num_threads(num_threads);
    omp_set_dynamic(0);  // Disabilita thread dinamici
    
    // Set affinity per NUMA performance
    if (num_threads >= 32) {
        omp_set_proc_bind(omp_proc_bind_spread);
    } else {
        omp_set_proc_bind(omp_proc_bind_close);
    }
    
    double start_time = omp_get_wtime();
    
    // Usa algoritmo ottimale basato sul numero di thread
    if (num_threads >= 64 && params->width >= 1000) {
        compute_mandelbrot_tasks(params, result);
    } else {
        compute_mandelbrot_standard(params, result);
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
    
    // Parametri Mandelbrot ottimizzati
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
