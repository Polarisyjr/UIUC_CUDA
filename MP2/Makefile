WB = ${WB_DIR}
NVCC = nvcc
CXX = g++-10
CC = gcc-10

template.o: template.cu
	$(NVCC) --std=c++11 -ccbin=$(CXX) -rdc=true -I $(WB) -c template.cu -o template.o

template: template.o
	$(NVCC) --std=c++11 -ccbin=$(CXX) -o template template.o $(WB)/lib/libwb.so

run: template
	bash run_datasets

build: template run

clean:
	rm -f template.o template
