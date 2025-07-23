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
    
    #pragma omp parallel for collapse(2) schedule(dynamic, 16)
    for (int j = 0; j < ny; j++) {
        for (int i = 0; i < nx; i++) {
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
