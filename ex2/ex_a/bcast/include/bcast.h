#ifndef BCAST_H
#define BCAST_H

#include <mpi.h>

/* firma di tutte le funzioni di broadcast */
void basic_linear_bcast(void *buf, int count, MPI_Datatype type,
                        int root, MPI_Comm comm);
void chain_bcast(void *buf, int count, MPI_Datatype type,
                 int root, MPI_Comm comm);
void pipeline_bcast(void *buf, int count, MPI_Datatype type,
                    int root, MPI_Comm comm);
void pipeline_nb_bcast(void *buf, int count, MPI_Datatype type,
                       int root, MPI_Comm comm);
void binomial_bcast(void *buf, int count, MPI_Datatype type,
                    int root, MPI_Comm comm);

#endif /* BCAST_H */
