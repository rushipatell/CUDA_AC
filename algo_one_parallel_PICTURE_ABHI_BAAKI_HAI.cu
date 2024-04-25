#define _CRT_SECURE_NO_DEPRECATE
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <math.h>
#include<cuda.h>

#define CUDA_WARN(XXX) \
    do {if (XXX != cudaSuccess) printf("%s\n", cudaGetErrorString(XXX));} while (0)

#define BLOCK_ROW 32
#define BLOCK_COL 32

__global__ void kernal_process_image(float* image,float* image_updated, int height, int width, int kernel)
{
    int row = blockIdx.y*blockDim.y + threadIdx.y;
    int col = blockIdx.x*blockDim.x + threadIdx.x;



    if (row>=0 && col>=0 && row<height && col<width && image[row*width+col]==0)
    {
        float div=0, su=0, wei=0;
        int i, j;
        for(i=-1; i<=1; i++)
            for(j=-1; j<=1; j++)
                if(i + row >= 0 && i + row < height && j + col >= 0 && j + col < width)
                    div+=image[(row+i)*width+col+j];

        if(div>0.06)
        {
            int range = kernel/2;
            for(i=-range; i<=range; i++){
                for(j=-range;j<=range;j++){
                    if(row+i<0 || row+i>height || col+j<0 || col+j>width || image[(row+i)*width+col+j]==0){
                        continue;
                    }
                    wei += 1 / sqrt( (float) ((i*i) + (j*j)));
                    su += (image[(row+i)*width+col+j]/sqrt(  (float) ( (i*i) + (j*j) )      ));
                }
            }
        }
        image_updated[row*width+col]=(wei!=0)?su/wei:0;
        // printf("%d,", row*width+col);
    }
    return;
}

float* process_image(float* input_image, int height, int width)
{
    float* image;
    float* image_updated;
    clock_t start_mem,end_mem;

    start_mem = clock();
    cudaMalloc(&image, height*width*sizeof(float));
    cudaMalloc(&image_updated, height*width*sizeof(float));

    cudaMemcpy(image, input_image, height*width*sizeof(float), cudaMemcpyHostToDevice);
    cudaMemcpy(image_updated, input_image, height*width*sizeof(float), cudaMemcpyHostToDevice);
    end_mem = clock();

    double walltime=(double)(((double)(end_mem-start_mem)* 1000)/(double)CLOCKS_PER_SEC);
    printf("Time to Allocate & Copy data from Host to Device memory is: %f miliseconds\n",walltime);
    
    dim3 dimBlock(BLOCK_ROW, BLOCK_COL);
    dim3 dimGrid((height-1)/dimBlock.x + 1, (width-1)/dimBlock.y + 1);

    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);

    cudaEventRecord(start);

    kernal_process_image <<<dimBlock, dimGrid>>> (image,image_updated, height, width, 5);

    cudaEventRecord(stop);
    cudaEventSynchronize(stop);

    float elapsed_time=0;
    cudaEventElapsedTime(&elapsed_time, start, stop);

    printf("Time to identify black pixels and replace those with weighted average for image size : %d x %d is: %f miliseconds\n",height,width,elapsed_time);

    start_mem = clock();
    cudaMemcpy(input_image, image_updated, height*width*sizeof(float), cudaMemcpyDeviceToHost);
    end_mem = clock();

    walltime=(double)(((double)(end_mem-start_mem)* 1000)/(double)CLOCKS_PER_SEC);
    printf("Time to Allocate & Copy data from Device to Host memory is: %f miliseconds\n",walltime);

    cudaFree(image);
    cudaFree(image_updated);
    return input_image;
}


int main(int argc, char **argv)
{
    int i, j, x;
	clock_t start,end;
	unsigned char byte[54];

    if(argc<3)
    {
        printf("Insufficient input Argument");
        return 1;
    }

	start = clock();

	FILE* fIn = fopen(argv[1], "rb");//Input File name
	FILE* fOut = fopen(argv[2], "wb");//Output File name


	if (fIn == NULL)											// check if the input file has not been opened succesfully.
	{
		printf("File does not exist.\n");
	}

	end = clock();
	double walltime=(double)(((double)(end-start)* 1000)/(double)CLOCKS_PER_SEC);
    printf("Time to open input & output image is: %f miliseconds\n",walltime);


    start = clock();
	for (i = 0; i < 54; i++)											//read the 54 byte header from fIn
	{
		byte[i] = getc(fIn);
	}

    unsigned int width = *(int*)&byte[18];
	unsigned int height = *(int*)&byte[22];
	fwrite(byte, sizeof(unsigned char), 54, fOut);					//write the header back


    unsigned char temp_trial[1024];
    for(i=0;i<1024;i++)
	{
		temp_trial[i] = getc(fIn);
	}
	fwrite(temp_trial, sizeof(unsigned char), 1024, fOut); 



	end = clock();
	walltime=(double)(((double)(end-start)* 1000)/(double)CLOCKS_PER_SEC);
    printf("Time to read & write header file for size : %d x %d is: %f miliseconds\n",height,width,walltime);

	printf("width: %d\n", width);
	printf("height: %d\n", height);

    int size = height*width;

	unsigned char* buffer = (unsigned char*)malloc(size * sizeof(unsigned char));
	unsigned char* out = (unsigned char*)malloc(size * sizeof(unsigned char));
	float* c = (float*)malloc(size * sizeof(float));

	start = clock();
	for (i = 0; i < height; i++)
	{
		for (j = 0; j < width; j++)
		{
			buffer[i * width + j] = getc(fIn);
		}
	}

    end = clock();
	walltime=(double)(((double)(end-start)* 1000)/(double)CLOCKS_PER_SEC);
    printf("Time to read image file into buffer for size : %d x %d is: %f miliseconds\n",height,width,walltime);


    start = clock();
	for (i = 0; i < size; i++)
	{
		c[i] = ((float)(buffer[i])) / (255.0f);
	}
	end = clock();
	walltime=(double)(((double)(end-start)* 1000)/(double)CLOCKS_PER_SEC);
    printf("Time to convert pixel values in 0-1 range for image size : %d x %d is: %f miliseconds\n",height,width,walltime);

   float* image;
    float* image_updated;
    clock_t start_mem,end_mem;

    start_mem = clock();
    cudaMalloc(&image, height*width*sizeof(float));
    cudaMalloc(&image_updated, height*width*sizeof(float));

    cudaMemcpy(image, c, height*width*sizeof(float), cudaMemcpyHostToDevice);
    cudaMemcpy(image_updated, c, height*width*sizeof(float), cudaMemcpyHostToDevice);
    end_mem = clock();

    double walltime=(double)(((double)(end_mem-start_mem)* 1000)/(double)CLOCKS_PER_SEC);
    printf("Time to Allocate & Copy data from Host to Device memory is: %f miliseconds\n",walltime);
    
    dim3 dimBlock(BLOCK_ROW, BLOCK_COL);
    dim3 dimGrid((height-1)/dimBlock.x + 1, (width-1)/dimBlock.y + 1);

    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);

    cudaEventRecord(start);

    kernal_process_image <<<dimBlock, dimGrid>>> (image,image_updated, height, width, 5);

    cudaEventRecord(stop);
    cudaEventSynchronize(stop);

    float elapsed_time=0;
    cudaEventElapsedTime(&elapsed_time, start, stop);

    printf("Time to identify black pixels and replace those with weighted average for image size : %d x %d is: %f miliseconds\n",height,width,elapsed_time);

    start_mem = clock();
    cudaMemcpy(c, image_updated, height*width*sizeof(float), cudaMemcpyDeviceToHost);
    end_mem = clock();

    walltime=(double)(((double)(end_mem-start_mem)* 1000)/(double)CLOCKS_PER_SEC);
    printf("Time to Allocate & Copy data from Device to Host memory is: %f miliseconds\n",walltime);

    cudaFree(image);
    cudaFree(image_updated);



	start = clock();
	for (i = 0; i < size; i++)
	{
		x = (int)(c[i]*255.0f);
		out[i] = (unsigned char)x;
	}

	fwrite(out, sizeof(unsigned char), size, fOut);           //write image data back to the file
    end = clock();
    walltime=(double)(((double)(end-start)* 1000)/(double)CLOCKS_PER_SEC);
    printf("Time to convert pixel values in range of 0-255 & write image in output for image size : %d x %d is: %f miliseconds\n",height,width,walltime);

	fclose(fIn);
	fclose(fOut);

    free(c);
    free(buffer);
    free(out);
	return 0;
}
