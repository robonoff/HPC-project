#include "bcast.h"
#include <mpi.h>

void chain_bcast(void *buf, int count, MPI_Datatype type,
                 int root, MPI_Comm comm) {
    int rank, size;
    MPI_Comm_rank(comm,&rank);
    MPI_Comm_size(comm,&size);
    int rel = (rank - root + size) % size;
    int src = (rel == 0 ? MPI_PROC_NULL : (root + rel - 1) % size);
    int dst = (rel == size-1 ? MPI_PROC_NULL : (root + rel + 1) % size);
    if (src != MPI_PROC_NULL)
        MPI_Recv(buf, count, type, src, 0, comm, MPI_STATUS_IGNORE);
    if (dst != MPI_PROC_NULL)
        MPI_Send(buf, count, type, dst, 0, comm);
}
