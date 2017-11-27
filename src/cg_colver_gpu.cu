/*Contains implementation for gpu_cg_solver functions.*/


#include "cg_colver_gpu.h"
#include "ckernels.h"

extern "C"
{
#include "gpu_utils.h"
#include "utils.h"

#include <cuda_runtime.h>
#include <cusparse_v2.h>
#include <cublas_v2.h>

#define threadsPerBlock 256

#define FREE_DEVICE_STACK \
	cudaFree(d_r);\
	cudaFree(d_helper);\
	cudaFree(d_x);\
	cudaFree(d_rhs);\
	cudaFree(d_d);\
	cudaFree(d_Ax);\
	cudaFree(d_q);\
	cudaFree(d_val);\
	cudaFree(d_I);\
	cudaFree(d_J);\
	cudaFree(d_beta);\
	cudaFree(d_alfa);\
	cudaFree(d_alpha_zero);\
	cudaFree(d_dot);\
	cudaFree(d_norm);\
	cudaFree(d_dot_zero);\
	cudaFree(d_dot_old);\
	cudaFree(d_dTq);


int gpu_conjugate_gradient_solver(Matrix *matrix, double *x_vec, double *rhs, double *res_vec, GPU_data gpu_data){
	/*Single GPU CG solver using cublas*/

	double *h_dot, *h_dot_zero;
	int *d_I = NULL, *d_J = NULL;
	const double tol = 1e-2f;
	double *d_alfa, *d_beta, *d_alpha_zero;
	double *d_Ax, *d_x, *d_d, *d_q, *d_rhs, *d_r, *d_helper, *d_norm, *d_dot, *d_dot_zero, *d_dot_old, *d_dTq, *d_val;
	int k, max_iter;

	k = 0;
	h_dot = 0;
	h_dot_zero = 0;
	max_iter = 200;

	size_t size = matrix->size * sizeof(double);

	cusparseHandle_t cusparseHandle = 0;
	cublasHandle_t cublasHandle = 0;
	cusparseMatDescr_t descr = 0;

	cusparseSetMatType(descr, CUSPARSE_MATRIX_TYPE_GENERAL);
	cusparseSetMatIndexBase(descr, CUSPARSE_INDEX_BASE_ZERO);

	cudaMalloc((void **)&d_r, size);
	cudaMalloc((void **)&d_helper, size);
	cudaMalloc((void **)&d_x, size);
	cudaMalloc((void **)&d_rhs,	size);
	cudaMalloc((void **)&d_d, size);
	cudaMalloc((void **)&d_Ax, size);
	cudaMalloc((void **)&d_q, size);

	cudaMalloc((void **)&d_val, matrix->non_zero * sizeof(double));
	cudaMalloc((void **)&d_J, matrix->non_zero * sizeof(double));
	cudaMalloc((void **)&d_I, (matrix->size + 1) * sizeof(int));

	cudaMalloc((void **)&d_beta, sizeof(double));
	cudaMalloc((void **)&d_alfa, sizeof(double));
	cudaMalloc((void **)&d_alpha_zero, sizeof(double));
	cudaMalloc((void **)&d_dot, sizeof(double));
	cudaMalloc((void **)&d_dot_zero, sizeof(double));
	cudaMalloc((void **)&d_norm, sizeof(double));

	cudaMemcpy(d_val, matrix->val, matrix->non_zero * sizeof(double), cudaMemcpyHostToDevice);
	cudaMemcpy(d_J, matrix->J_row, matrix->non_zero * sizeof(int), cudaMemcpyHostToDevice);
	cudaMemcpy(d_I, matrix->I_column, (matrix->size + 1) * sizeof(int), cudaMemcpyHostToDevice);

	cudaMemcpy(d_x, x_vec, size, cudaMemcpyHostToDevice);
	cudaMemcpy(d_rhs, rhs, size, cudaMemcpyHostToDevice);

	int blocksPerGrid = ((matrix->size + threadsPerBlock -1) / threadsPerBlock );
	while (blocksPerGrid % threadsPerBlock != 0){
		blocksPerGrid++;
	}
	double alpha = 1.0;
	double beta = 0.0;

	const double one = 1.0;
	const double minus_one = -1.0;
	/*Calculate Ax matrix*/
	cusparseDcsrmv(cusparseHandle, CUSPARSE_OPERATION_NON_TRANSPOSE, matrix->size, matrix->size, matrix->non_zero,
					  &alpha, descr, d_val, d_J, d_I, d_x, &beta, d_Ax);
	/*Calculate rhs=rhs-Ax matrix*/
	cublasDaxpy(cublasHandle, matrix->size, &minus_one, d_Ax, 1, d_rhs, 1);
	/*CG: Copy updated rhs (residuum) to d vector*/
	cublasDcopy(cublasHandle, matrix->size, d_d, 1, d_rhs, 1);
	/*CG: calculate dot r'*r, assign it to dot_new */
	cublasDdot(cublasHandle, matrix->size, d_rhs, 1, d_rhs, 1, d_dot);
	/*assign dot_new to dot_zero*/
	d_dot_zero = d_dot;
	cudaMemcpy(h_dot, d_dot,  sizeof(double), cudaMemcpyDeviceToHost);
	cudaMemcpy(h_dot_zero, d_dot_zero,  sizeof(double), cudaMemcpyDeviceToHost);
	while ((*h_dot >  tol * tol * *h_dot_zero) && (k < max_iter)) {
		/*Calculate q=A*d vector*/
		cusparseDcsrmv(cusparseHandle, CUSPARSE_OPERATION_NON_TRANSPOSE, matrix->size, matrix->size, matrix->non_zero,
						  &alpha, descr, d_val, d_J, d_I, d_x, &beta, d_Ax);
		/*Calculate alpha:*/
		cublasDdot(cublasHandle, matrix->size, d_d, 1, d_q, 1, d_dTq);
		sDdiv<<<1, gpu_data.devices[0].warp_size>>>(d_alfa, d_dot, d_dTq);
		/*Calculate x=x+alpha*d*/
		cublasDaxpy(cublasHandle, matrix->size, d_alfa, d_x, 1, d_d, 1);
		/*Calculate r=r-alpha*q*/
		axpy<<<blocksPerGrid, threadsPerBlock>>>(matrix->size, -1, d_q, d_rhs);
		/*Assign dot_old = dot_new*/
		cublasDcopy(cublasHandle, 1, d_dot_old, 1, d_dot, 1);
		/*CG:Assign dot_new = r'*r*/
		cublasDdot(cublasHandle, matrix->size, d_rhs, 1, d_rhs, 1, d_dot);
		sDdiv<<<1, gpu_data.devices[0].warp_size>>>(d_beta, d_dot, d_dot_old);
		/*Scale beta*d*/
		cublasDscal(cublasHandle, matrix->size, d_beta, d_d, 1);
		/*CG:Calculate d=r+beta*d*/
		cublasDaxpy(cublasHandle, matrix->size, &one, d_rhs, 1, d_d, 1);
		k++;
	}
	cusparseDestroy(cusparseHandle);
	cudaDeviceReset();
	FREE_DEVICE_STACK
	return k;
}
}