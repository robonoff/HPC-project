#include "bcast.h"
#include <mpi.h>

void binomial_bcast(void *buf, int count, MPI_Datatype type,
                    int root, MPI_Comm comm) {
    int rank, size;
    MPI_Comm_rank(comm,&rank);
    MPI_Comm_size(comm,&size);
    int rel = (rank - root + size) % size;
    for (int mask = 1; mask < size; mask <<= 1) {
        if (rel < mask) {
            int dst = rel + mask;
            if (dst < size) {
                int dst_rank = (dst + root) % size;
                MPI_Send(buf, count, type, dst_rank, 0, comm);
            }
        }
        else if (rel < 2*mask) {
            int src = rel - mask;
            int src_rank = (src + root) % size;
            MPI_Recv(buf, count, type, src_rank, 0, comm, MPI_STATUS_IGNORE);
        }
    }
}
