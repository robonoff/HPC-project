#ifndef MANDELBROT_H
#define MANDELBROT_H

void compute_mandelbrot(void *M, int nx, int ny,
                        double xL, double yL,
                        double dx, double dy,
                        int I_max, int is_16bit);

#endif
