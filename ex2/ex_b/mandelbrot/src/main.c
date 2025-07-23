#include "../include/common.h"
#include "../include/pgm_writer.h"
#include "../include/mandelbrot.h"

int main(int argc, char **argv) {
    if (argc != 8) {
        fprintf(stderr, "Usage: %s nx ny xL yL xR yR I_max\n", argv[0]);
        exit(EXIT_FAILURE);
    }

    int nx = atoi(argv[1]);
    int ny = atoi(argv[2]);
    double xL = atof(argv[3]);
    double yL = atof(argv[4]);
    double xR = atof(argv[5]);
    double yR = atof(argv[6]);
    int I_max = atoi(argv[7]);
    int is_16bit = I_max >= 256;

    void *M = malloc(nx * ny * (is_16bit ? sizeof(ushort) : sizeof(byte)));
    if (!M) { perror("malloc"); exit(EXIT_FAILURE); }

    double dx = (xR - xL) / nx;
    double dy = (yR - yL) / ny;

    double t_start = omp_get_wtime();
    compute_mandelbrot(M, nx, ny, xL, yL, dx, dy, I_max, is_16bit);
    double t_end = omp_get_wtime();

    printf("Execution Time: %.3f s\n", t_end - t_start);
    write_pgm_image("output.pgm", M, nx, ny, I_max);

    free(M);
    return 0;
}
