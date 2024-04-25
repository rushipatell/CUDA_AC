#define _CRT_SECURE_NO_DEPRECATE
#include <stdio.h>
#include<stdlib.h>
#include <time.h>
#include <math.h>

int main(int argc, char **argv)
{
    int i, j, x, y, r,c2;
	clock_t start,end;
	unsigned char byte[54];
	unsigned char temp_trial[1024];
	if(argc<3)
    {
        printf("Insufficient input Argument");
        return 1;
    }

	start = clock();

	FILE* fIn = fopen(argv[1], "rb");//Input File name
	FILE* fOut = fopen(argv[2], "wb");//Output File name
	

	if (fIn == NULL)												// check if the input file has not been opened succesfully.
	{
		printf("File does not exist.\n");
	}
	end = clock();
	double walltime=(double)(((double)(end-start)* 1000)/(double)CLOCKS_PER_SEC);
    printf("Time to open input & output image is: %f miliseconds\n",walltime);

//   int counter=0;
//  int temp=getc(fIn);
    // while(temp!=EOF)
	// { 
	// 				   counter++;
	// 				   if(counter==54)printf("\n\n");
	// 				   if(counter==1078)printf("\n\n");
	// 				   if(counter<=1078&&counter>=55)

	// 				   temp=getc(fIn);
					  
			  
	// }
	//  printf("\nCounter is: %d\n",counter);
	// 		  exit(0);

    start = clock();
	for (i = 0; i < 54; i++)											//read the 54 byte header from fIn
	{
		byte[i] = getc(fIn);
	}
fwrite(byte, sizeof(unsigned char), 54, fOut);					//write the header back

	for(i=0;i<1024;i++)
	{
		temp_trial[i] = getc(fIn);
	}
	fwrite(temp_trial, sizeof(unsigned char), 1024, fOut); 


	
	  // extract image height, width and bitDepth from imageHeader
 
	
	int height = *(int*)&byte[18];
	int width = *(int*)&byte[22];
	int bitDepth = *(int*)&byte[28];					//write the header back

	int size = height*width;
	

	end = clock();
	walltime=(double)(((double)(end-start)* 1000)/(double)CLOCKS_PER_SEC);
    printf("Time to read & write header file for size : %d x %d is: %f miliseconds\n",height,width,walltime);

	printf("width: %d\n", width);
	printf("height: %d\n", height);
	//calculate image size

	unsigned char* buffer = (unsigned char*)malloc(size * sizeof(unsigned char));
	unsigned char* out = (unsigned char*)malloc(size * sizeof(unsigned char));					//to store the image data
	float* c = (float*)malloc(size * sizeof(float));
	float* c_updated = (float*)malloc(size * sizeof(float));

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
		out[i] = buffer[i];
		c[i] = ((float)(buffer[i])) / (255.0f);
		c_updated[i] = ((float)(buffer[i])) / (255.0f);
		//copy image data to out bufer
	}
	end = clock();
	walltime=(double)(((double)(end-start)* 1000)/(double)CLOCKS_PER_SEC);
    printf("Time to convert pixel values in 0-1 range for image size : %d x %d is: %f miliseconds\n",height,width,walltime);


    start = clock();
	float su, wei, div;

	for (i = 0; i < height; i++)
	{
		for (j = 0; j < width; j++)
		{

			if (c[i * width + j] == 0.0f)
			{
				div = 0;
				for (x = -1; x <= 1; x++)
				{
					for (y = -1; y <= 1; y++)
					{
						if (i + x < height && i + x >= 0 && j + y < width && j + y >= 0)
							div += c[(i + x) * width + j + y];
					}
				}

				if (div > 0.06)
				{
					c_updated[i * width + j] = 1.5;
				}
			}
		}
	}
	for (i = 0; i < height; i++)
	{
		for (j = 0; j < width; j++)
		{
			if (c_updated[i * width + j] == 1.5)
			{
				su = 0;
				wei = 0;

				for (r = -2; r <= 2; r++)
				{
					for ( c2 = -2; c2 <= 2; c2++)
					{
						if (i + r >= 0 && i + r <= height - 1 && j + c2 >= 0 && j + c2 <= width - 1 && c_updated[(i + r) * width + j + c2] != 1.5 && c_updated[(i + r) * width + j + c2] != 0)
						{
							wei += 1 / sqrt((float) ((r * r) + (c2 * c2)));
							su += (c[(i + r) * width + j + c2] / sqrt((float) ((r * r) + (c2 * c2))));
						}
					}
				}

                    if(wei!=0)
					c[i * width + j] = su / wei;
					else
					c[i * width + j] = 0;
			}

		}
	}

	end = clock();
	walltime=(double)(((double)(end-start)* 1000)/(double)CLOCKS_PER_SEC);
    printf("Time to identify black pixels and replace those with weighted average for image size : %d x %d is: %f miliseconds\n",height,width,walltime);


	start = clock();
	for (i = 0; i < size; i++)
	{
		su = c[i] * 255.0f;
		x = (int)su;
		out[i] = (unsigned char)x;
		//printf(" %d ",out[i]);
	}

	fwrite(out, sizeof(unsigned char), size, fOut);//write image data back to the file
    end = clock();
    walltime=(double)(((double)(end-start)* 1000)/(double)CLOCKS_PER_SEC);
    printf("Time to convert pixel values in range of 0-255 & write image in output for image size : %d x %d is: %f miliseconds\n",height,width,walltime);

	free(c);
    free(buffer);
    free(out);
	free(c_updated);

	fclose(fIn);
	fclose(fOut);
	return 0;
}
