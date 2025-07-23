#include "../include/common.h"
#include "../include/mandelbrot.h"

static inline int iterate(double cx, double cy, int I_max) {
    double zx = 0.0, zy = 0.0;
    int n = 0;
    while (zx * zx + zy * zy < 4.0 && n < I_max) {
        double xt = zx * zx - zy * zy + cx;
        zy = 2.0 * zx * zy + cy;
        zx = xt;
        ++n;
    }
    return n;
}

void compute_mandelbrot(void *M, int nx, int ny,
                        double xL, double yL,
                        double dx, double dy,
                        int I_max, int is_16bit) {

    #pragma omp parallel
    {
        #pragma omp single
        {
            #pragma omp taskgroup
            {
                for (int jj = 0; jj < ny; jj += 32) {
                    for (int ii = 0; ii < nx; ii += 32) {
                        int i0 = ii, j0 = jj;
                        int i1 = (ii + 32 < nx) ? ii + 32 : nx;
                        int j1 = (jj + 32 < ny) ? jj + 32 : ny;

                        #pragma omp task firstprivate(i0, i1, j0, j1) shared(M)
                        for (int j = j0; j < j1; j++) {
                            #pragma omp taskloop grainsize(4) nogroup
                            for (int i = i0; i < i1; i++) {
                                double cx = xL + i * dx;
                                double cy = yL + j * dy;
                                int val = iterate(cx, cy, I_max);
                                if (is_16bit)
                                    ((ushort*)M)[j * nx + i] = (val == I_max) ? 0 : val;
                                else
                                    ((byte*)M)[j * nx + i] = (val == I_max) ? 0 : val;
                            }
                        }
                    }
                }
            }
        }
    }
}
