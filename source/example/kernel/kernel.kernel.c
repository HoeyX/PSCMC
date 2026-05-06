#include <omp.h> 
#include <math.h>
void  muladd_scmc_kernel (double *  A ,double *  B ,double *  C ,long  scmc_internal_g_idy ,long  scmc_internal_g_ylen ){
	const long  pscmc_compute_unit_id = 	omp_get_thread_num (  )
 ;

	const long  pscmc_num_compute_units = 	omp_get_num_threads (  )
 ;

	const long  __idx = 0 ;

	const long  __idy = scmc_internal_g_idy ;

	const long  __xlen = 1 ;

	const long  __ylen = scmc_internal_g_ylen ;

	const long  __global_idx = 	(  __idx + 	(  __idy * __xlen )
 )
 ;

((A)[__global_idx] = 	(  (A)[__global_idx] + 	(  (B)[__global_idx] * (C)[__global_idx] )
 )
);
}
