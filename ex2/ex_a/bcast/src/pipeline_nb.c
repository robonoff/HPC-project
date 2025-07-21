#include "bcast.h"
#include <mpi.h>

void pipeline_nb_bcast(void *buf, int count, MPI_Datatype type,
                       int root, MPI_Comm comm) {
  int rank,size; MPI_Comm_rank(comm,&rank); MPI_Comm_size(comm,&size);
  int rel = (rank - root + size) % size;
  int left  = (rel==0        ? MPI_PROC_NULL : (root + rel - 1)%size);
  int right = (rel==size-1 ? MPI_PROC_NULL : (root + rel + 1)%size);

  MPI_Aint typesz; MPI_Type_size(type,(int*)&typesz);
  int nseg = size;
  int base = count/nseg, extra = count%nseg;

  MPI_Request *reqs = malloc(2*nseg*sizeof(MPI_Request));
  int nreq = 0;

  for(int seg=0; seg<nseg; seg++){
    int segc   = base + (seg<extra);
    MPI_Aint off= (MPI_Aint)seg*base + (seg<extra ? seg : extra);
    char *b    = (char*)buf + off*typesz;

    if(rel!=0) {
      MPI_Irecv(b,segc,type,left,seg,comm,&reqs[nreq++]);
    }
    if(right!=MPI_PROC_NULL) {
      MPI_Isend(b,segc,type,right,seg,comm,&reqs[nreq++]);
    }
  }
  MPI_Waitall(nreq, reqs, MPI_STATUSES_IGNORE);
  free(reqs);
}
