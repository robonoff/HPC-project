#include <stdio.h>
#include <stdlib.h>
#include <omp.h>
#include <math.h>

typedef struct {
    double x_min, x_max, y_min, y_max;
    int width, height, max_iter;
} mandel_params_t;

// Funzione Mandelbrot ottimizzata per cache locality
static inline int mandelbrot_point(double x0, double y0, int max_iter) {
    double x = 0.0, y = 0.0;
    double x2, y2;
    
    for (int iter = 0; iter < max_iter; iter++) {
        x2 = x * x;
        y2 = y * y;
        
        if (x2 + y2 > 4.0) {
            return iter;
        }
        
        y = 2.0 * x * y + y0;
        x = x2 - y2 + x0;
    }
    
    return max_iter;
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

// Implementazione NUMA-aware con OpenMP Tasks
double compute_mandelbrot(mandel_params_t* params, int num_threads, const char* output_file) {
    const double dx = (params->x_max - params->x_min) / params->width;
    const double dy = (params->y_max - params->y_min) / params->height;
    
    // Alloca memoria
    int* result = malloc(params->width * params->height * sizeof(int));
    if (!result) {
        fprintf(stderr, "Errore allocazione memoria\n");
        return -1.0;
    }
    
    // Configura OpenMP per AMD EPYC
    omp_set_num_threads(num_threads);
    omp_set_dynamic(0);
    
    // NUMA-aware affinity per AMD EPYC
    if (num_threads >= 64) {
        // Distribuisci su entrambi i socket
        omp_set_proc_bind(omp_proc_bind_spread);
    } else if (num_threads >= 16) {
        // Usa nodi NUMA completi  
        omp_set_proc_bind(omp_proc_bind_close);
    } else {
        // Core vicini
        omp_set_proc_bind(omp_proc_bind_close);
    }
    
    double start_time = omp_get_wtime();
    
    // Granularità ottimizzata per 8 nodi NUMA
    int tile_height;
    if (num_threads >= 64) {
        // Per molti thread: tile piccoli per load balancing
        tile_height = fmax(4, params->height / (num_threads * 2));
    } else if (num_threads >= 16) {
        // Per thread medi: tile medi
        tile_height = fmax(8, params->height / num_threads);
    } else {
        // Per pochi thread: tile grandi
        tile_height = fmax(16, params->height / (num_threads / 2));
    }
    
    // Parallelizzazione con Tasks per load balancing ottimale
    #pragma omp parallel
    {
        #pragma omp single
        {
            // Crea tasks per blocchi di righe
            for (int j_start = 0; j_start < params->height; j_start += tile_height) {
                int j_end = (j_start + tile_height < params->height) ? 
                           j_start + tile_height : params->height;
                
                #pragma omp task firstprivate(j_start, j_end)
                {
                    // Ogni task processa un blocco di righe
                    for (int j = j_start; j < j_end; j++) {
                        double y0 = params->y_min + j * dy;
                        
                        // Loop interno ottimizzato per cache
                        for (int i = 0; i < params->width; i++) {
                            double x0 = params->x_min + i * dx;
                            result[j * params->width + i] = 
                                mandelbrot_point(x0, y0, params->max_iter);
                        }
                    }
                }
            }
            
            // Aspetta tutti i tasks
            #pragma omp taskwait
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
