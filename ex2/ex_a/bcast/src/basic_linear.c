#include "bcast.h"
#include <mpi.h>

void basic_linear_bcast(void *buf, int count, MPI_Datatype type,
                        int root, MPI_Comm comm) {
    int rank, size;
    MPI_Comm_rank(comm,&rank);
    MPI_Comm_size(comm,&size);
    if (rank == root) {
        for (int dst = 0; dst < size; ++dst) {
            if (dst == root) continue;
            MPI_Send(buf, count, type, dst, 0, comm);
        }
    } else {
        MPI_Recv(buf, count, type, root, 0, comm, MPI_STATUS_IGNORE);
    }
}
