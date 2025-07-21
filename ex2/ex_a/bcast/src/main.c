#include <mpi.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "bcast.h"

int main(int argc, char **argv) {
    MPI_Init(&argc,&argv);
    int rank, size;
    MPI_Comm_rank(MPI_COMM_WORLD,&rank);
    MPI_Comm_size(MPI_COMM_WORLD,&size);

    int root  = 0, alg = 1, count = 1000000;
    for (int i = 1; i < argc; ++i) {
        if      (!strcmp(argv[i],"-r")) root  = atoi(argv[++i]);
        else if (!strcmp(argv[i],"-a")) alg   = atoi(argv[++i]);
        else if (!strcmp(argv[i],"-n")) count = atoi(argv[++i]);
    }

    int *buf = malloc(sizeof(int)*count);
    if (rank == root)
        for (int i = 0; i < count; ++i) buf[i] = i;
    else
        for (int i = 0; i < count; ++i) buf[i] = -1;

    MPI_Barrier(MPI_COMM_WORLD);
    double t0 = MPI_Wtime();

    switch (alg) {
        case 1: basic_linear_bcast(buf,count,MPI_INT,root,MPI_COMM_WORLD); break;
        case 2: chain_bcast       (buf,count,MPI_INT,root,MPI_COMM_WORLD); break;
        case 3: pipeline_bcast    (buf,count,MPI_INT,root,MPI_COMM_WORLD); break;
	case 4: pipeline_nb_bcast(buf,count,MPI_INT,root,MPI_COMM_WORLD); break;
        case 6: binomial_bcast    (buf,count,MPI_INT,root,MPI_COMM_WORLD); break;
        default: 
            if (rank==0) fprintf(stderr,"Algoritmo %d non valido\n",alg);
            MPI_Abort(MPI_COMM_WORLD,1);
    }

    MPI_Barrier(MPI_COMM_WORLD);
    double t1 = MPI_Wtime();

    if (rank == 0)
        printf("%d,%d,%d,%.6f\n", alg, size, count, t1-t0);

    free(buf);
    MPI_Finalize();
    return 0;
}
