typedef struct { 
	double *  A ;

	double *  B ;

	double *  C ;

	long  A_len ;

	long  B_len ;

	long  C_len ;

} muladd_struct;
void  muladd_scmc_kernel (double *  A ,double *  B ,double *  C ,long  yid_kernel ,long  __ylen_kernel );
