#include "bcast.h"
#include <mpi.h>

void pipeline_bcast(void *buf, int count, MPI_Datatype type,
                    int root, MPI_Comm comm) {
    int rank, size;
    MPI_Comm_rank(comm,&rank);
    MPI_Comm_size(comm,&size);
    int rel = (rank - root + size) % size;
    int left  = (rel == 0        ? MPI_PROC_NULL : (root + rel - 1) % size);
    int right = (rel == size-1 ? MPI_PROC_NULL : (root + rel + 1) % size);

    MPI_Aint typesz;
    MPI_Type_size(type, (int*)&typesz);
    int nseg   = size;
    int base   = count / nseg;
    int extra  = count % nseg;

    for (int seg = 0; seg < nseg; ++seg) {
        int segc = base + (seg < extra ? 1 : 0);
        MPI_Aint offset = (MPI_Aint)seg * base + (seg < extra ? seg : extra);
        char *b = (char*)buf + offset * typesz;

        if (rel == 0) {
            MPI_Send(b, segc, type, right, seg, comm);
        } else {
            MPI_Recv(b, segc, type, left, seg, comm, MPI_STATUS_IGNORE);
            if (right != MPI_PROC_NULL)
                MPI_Send(b, segc, type, right, seg, comm);
        }
    }
}
