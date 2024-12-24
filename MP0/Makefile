WB = ${WB_DIR}
NVCC = nvcc
CXX = g++-10
CC = gcc-10

template.o: template.cu
	$(NVCC) --std=c++11 -ccbin=$(CXX) -rdc=true -I $(WB) -c template.cu -o template.o

solution: template.o
	$(NVCC) --std=c++11 -ccbin=$(CXX) -o solution template.o $(WB)/lib/libwb.so
