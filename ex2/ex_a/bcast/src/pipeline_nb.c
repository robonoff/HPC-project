#include "bcast.h"
#include <mpi.h>
#include <stdlib.h>

void pipeline_nb_bcast(void *buf, int count, MPI_Datatype type,
                       int root, MPI_Comm comm) {
    int rank, size;
    MPI_Comm_rank(comm,&rank);
    MPI_Comm_size(comm,&size);

    int rel   = (rank - root + size) % size;
    int left  = (rel==0        ? MPI_PROC_NULL : (root+rel-1)%size);
    int right = (rel==size-1   ? MPI_PROC_NULL : (root+rel+1)%size);

    // ottengo dimensione del tipo in byte
    int typesz_int;
    MPI_Type_size(type, &typesz_int);
    MPI_Aint typesz = (MPI_Aint) typesz_int;

    int nseg  = size;
    int base  = count / nseg;
    int extra = count % nseg;

    // Al massimo servono 2*nseg request
    MPI_Request *reqs = malloc(2 * nseg * sizeof *reqs);
    int nreq = 0;

    for (int seg = 0; seg < nseg; ++seg) {
        int segc   = base + (seg < extra ? 1 : 0);
        MPI_Aint off = (MPI_Aint)seg * base + (seg < extra ? seg : extra);

        char *b = (char*)buf + off * typesz;

        if (rel != 0) {
            MPI_Irecv(b, segc, type, left,  seg, comm, &reqs[nreq++]);
        }
        if (right != MPI_PROC_NULL) {
            MPI_Isend(b, segc, type, right, seg, comm, &reqs[nreq++]);
        }
    }

    MPI_Waitall(nreq, reqs, MPI_STATUSES_IGNORE);
    free(reqs);
}
