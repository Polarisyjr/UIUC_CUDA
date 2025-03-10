
#include <wb.h>

#define wbCheck(stmt)                                                     \
  do {                                                                    \
    cudaError_t err = stmt;                                               \
    if (err != cudaSuccess) {                                             \
      wbLog(ERROR, "Failed to run stmt ", #stmt);                         \
      wbLog(ERROR, "Got CUDA error ...  ", cudaGetErrorString(err));      \
      return -1;                                                          \
    }                                                                     \
  } while (0)

// Compute C = A * B
__global__ void matrixMultiplyShared(float *A, float *B, float *C,
                                     int numARows, int numAColumns,
                                     int numBRows, int numBColumns,
                                     int numCRows, int numCColumns) {
  //@@ Insert code to implement matrix multiplication here
  //@@ You have to use shared memory for this MP
  const int TILE = 16;
  __shared__ float Asub[TILE][TILE];
  __shared__ float Bsub[TILE][TILE];

  int row = blockIdx.y * blockDim.y + threadIdx.y;
  int col = blockIdx.x * blockDim.x + threadIdx.x;

  float value = 0.0;
  for (int i = 0; i < (numAColumns + TILE - 1) / TILE; ++i) {
    // load
    if (row < numARows && (i * TILE + threadIdx.x) < numAColumns) {
      Asub[threadIdx.y][threadIdx.x] = A[row * numAColumns + i * TILE + threadIdx.x];
    }else {
      Asub[threadIdx.y][threadIdx.x] = 0.0;
    }
    if (col < numBColumns && (i * TILE + threadIdx.y) < numBRows) {
      Bsub[threadIdx.y][threadIdx.x] = B[(i * TILE + threadIdx.y) * numBColumns + col];
    }else{
      Bsub[threadIdx.y][threadIdx.x] = 0.0;
    }
    __syncthreads();
    // compute
    for (int k = 0; k < TILE; ++k) {
      value += Asub[threadIdx.y][k] * Bsub[k][threadIdx.x];
    }
    __syncthreads();
  }

  if (row < numCRows && col < numCColumns) {
    C[row * numCColumns + col] = value;
  }
}

int main(int argc, char **argv) {
  wbArg_t args;
  float *hostA; // The A matrix
  float *hostB; // The B matrix
  float *hostC; // The output C matrix
  float *deviceA;
  float *deviceB;
  float *deviceC;
  int numARows;    // number of rows in the matrix A
  int numAColumns; // number of columns in the matrix A
  int numBRows;    // number of rows in the matrix B
  int numBColumns; // number of columns in the matrix B
  int numCRows;    // number of rows in the matrix C (you have to set this)
  int numCColumns; // number of columns in the matrix C (you have to set
                   // this)

  args = wbArg_read(argc, argv);

  wbTime_start(Generic, "Importing data and creating memory on host");
  hostA = (float *)wbImport(wbArg_getInputFile(args, 0), &numARows,
                            &numAColumns);
  hostB = (float *)wbImport(wbArg_getInputFile(args, 1), &numBRows,
                            &numBColumns);
  //@@ Set numCRows and numCColumns
  numCRows = 0;
  numCColumns = 0;
  numCRows = numARows;
  numCColumns = numBColumns;
  //@@ Allocate the hostC matrix
  hostC = (float *)malloc(numCRows * numCColumns * sizeof(float));
  //@@ End Allocate the hostC matrix
  wbTime_stop(Generic, "Importing data and creating memory on host");

  wbLog(TRACE, "The dimensions of A are ", numARows, " x ", numAColumns);
  wbLog(TRACE, "The dimensions of B are ", numBRows, " x ", numBColumns);

  wbTime_start(GPU, "Allocating GPU memory.");
  //@@ Allocate GPU memory here
  wbCheck(cudaMalloc((void **)&deviceA, numARows * numAColumns * sizeof(float)));
  wbCheck(cudaMalloc((void **)&deviceB, numBRows * numBColumns * sizeof(float)));
  wbCheck(cudaMalloc((void **)&deviceC, numCRows * numCColumns * sizeof(float)));
  //@@ End Allocate GPU memory here
  wbTime_stop(GPU, "Allocating GPU memory.");

  wbTime_start(GPU, "Copying input memory to the GPU.");
  //@@ Copy memory to the GPU here
  wbCheck(cudaMemcpy(deviceA, hostA, numARows * numAColumns * sizeof(float), cudaMemcpyHostToDevice));
  wbCheck(cudaMemcpy(deviceB, hostB, numBRows * numBColumns * sizeof(float), cudaMemcpyHostToDevice));
  wbCheck(cudaMemcpy(deviceC, hostC, numCRows * numCColumns * sizeof(float), cudaMemcpyHostToDevice));
  //@@ End Copy memory to the GPU here
  wbTime_stop(GPU, "Copying input memory to the GPU.");

  //@@ Initialize the grid and block dimensions here
  dim3 blockDim(16,16);
  dim3 gridDim((numCColumns + blockDim.x - 1) / blockDim.x,
                (numCRows + blockDim.y - 1) / blockDim.y); 
  //@@ End Initialize the grid and block dimensions here
  wbTime_start(Compute, "Performing CUDA computation");
  //@@ Launch the GPU Kernel here
  matrixMultiplyShared<<<gridDim, blockDim>>>(deviceA, deviceB, deviceC,
                                      numARows, numAColumns, numBRows,
                                      numBColumns, numCRows, numCColumns);
  //@@ End Launch the GPU Kernel here   
  cudaDeviceSynchronize();
  wbTime_stop(Compute, "Performing CUDA computation");

  wbTime_start(Copy, "Copying output memory to the CPU");
  //@@ Copy the GPU memory back to the CPU here
  wbCheck(cudaMemcpy(hostC, deviceC, numCRows * numCColumns * sizeof(float), cudaMemcpyDeviceToHost));
  //@@ End Copy the GPU memory back to the CPU here
  wbTime_stop(Copy, "Copying output memory to the CPU");

  wbTime_start(GPU, "Freeing GPU Memory");
  //@@ Free the GPU memory here
  wbCheck(cudaFree(deviceA));
  wbCheck(cudaFree(deviceB));
  wbCheck(cudaFree(deviceC));
  //@@ End Free the GPU memory here
  wbTime_stop(GPU, "Freeing GPU Memory");

  wbSolution(args, hostC, numCRows, numCColumns);

  free(hostA);
  free(hostB);
  free(hostC);

  return 0;
}
