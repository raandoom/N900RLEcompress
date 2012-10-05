#include <sys/stat.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define max_group_count 0x7F

// count groups
int countGroups (int count)
{
    int group = count / max_group_count;
    if(group * max_group_count != count) group++; // need +1 group
    return group;
}

// count repeat elements
int countRepeat (int elements, unsigned char* r_mem)
{
    int count = 1;  // there is minimum 2 elements are repeat already
    if (elements == 2)  // check if this is the last 2 elements
    {
        count++;
        return count;
    }
    while (*(unsigned short*) &r_mem[0] == *(unsigned short*) &r_mem[2])    // compare first 2 elements
    {
        if ((elements - count) == 1)  // check if this is the last 2 elements
        {
            count++;
            return count;
        }
        r_mem = r_mem + 2;
        count++;
    }
    return count;
}

// count different elements
int countDiffer (int elements, unsigned char* r_mem)
{
    int count = 1;  // there is minimum 1 elements are different already
    if (elements == 2)  // check if this is the last 2 elements
    {
        count++;
        return count;
    }
    while ( *(unsigned short*) &r_mem[2] != *(unsigned short*) &r_mem[4])
        // compare 2nd and 3rd elements, if they are the same - it is the end of different elements
    {
        if ((elements - count) == 1)
        {
            return (count + 2);
        }
        r_mem = r_mem + 2;
        count++;
    }
    return count;
}

// write one group with different elements
void writeDifferGroup (int count, unsigned char* r_mem, unsigned char* w_mem)
{
    w_mem[0] = count;
    w_mem = w_mem + 1;
    while (count > 0)
    {
        w_mem[0] = r_mem[1];
        w_mem[1] = r_mem[0];
        w_mem = w_mem + 2;
        r_mem = r_mem + 2;
        count--;
    }
    return;
}

// compress from r_mem to w_mem
int compressRLE (unsigned int elements, unsigned char *r_mem, unsigned char *w_mem)
{
    unsigned char *begin = w_mem;   // remember begin for return size
    int count;
    int group;

    while (elements != 0)   // when elements = 0, it is the end of r_mem
    {
        if (elements == 1)  // if this is the last 1 elements
        {
            w_mem[0] = 1;
            w_mem[1] = r_mem[1];
            w_mem[2] = r_mem[0];
            w_mem = w_mem + 3;
            w_mem[0] = 0;
            w_mem++;
            return (w_mem - begin);
        }
        if (*(unsigned short*) &r_mem[0] == *(unsigned short*) &r_mem[2])   // if first 2 elements are the same
        {
            count = countRepeat(elements, r_mem);  // count repeat elements
            group = 1;  // this is minimum 1 group with repeat elements
            if (count > max_group_count)    // if there is more than 0x7F elements
            {
                group = countGroups(count);    // how many groups we need to write
                int t_group = group;
                while (t_group != 1)    // dont write the last group
                {
                    w_mem[0] = max_group_count + 0x80;    // 0x80 is the mask for group with repeat elements
                    w_mem[1] = r_mem[1];
                    w_mem[2] = r_mem[0];
                    w_mem = w_mem + 3;
                    t_group--;
                }
            }
            w_mem[0] = (count - (group - 1) * max_group_count + 0x80);  // get and write count of elements in the last group
            w_mem[1] = r_mem[1];
            w_mem[2] = r_mem[0];
            w_mem = w_mem + 3;
            r_mem = r_mem + count * 2;
        }
        else    // if first 2 elements are different
        {
            count = countDiffer(elements, r_mem);  // count different elements
            group = countGroups(count); // count groups of different elements
            if (count > max_group_count)    // if there is more than 0x7F elements
            {
                int t_group = group;
                while (t_group != 1)    // write group by group, but not the last 1 group
                {
                    writeDifferGroup(max_group_count, r_mem, w_mem);
                    t_group--;
                }
                w_mem = w_mem + (group - 1) * max_group_count;
                r_mem = r_mem + count * 2;
                writeDifferGroup((count - (group - 1) * max_group_count), r_mem, w_mem);    // write the last 1 group
                w_mem = w_mem + (count - (group - 1) * max_group_count) * 2 + 1;
                r_mem = r_mem + (count - (group - 1) * max_group_count) * 2;
            }
            else    // if there is less than 0x7F elements
            {
                writeDifferGroup(count, r_mem, w_mem);  // write this group
                r_mem = r_mem + count * 2;
                w_mem = w_mem + count * 2 + 1;
            }
        }
        elements = elements - count;
    }
    w_mem[0] = 0;
    w_mem++;
    return (w_mem - begin);
}


int main (int argc, char *argv[])
{
    char info[] =   "### RLE Compress by RaANdOoM v.1.2\n"
            "# Usage: \"logo_compress.elf file [-h]\"\n"
            "# Use '-h' if your file is 16-bit image with header\n"
            "# Put file for compress near this elf and run elf\n"
            "# Compressed file will be in file 'file.out'\n"
            "###\n";

    printf("%s", info);

    if (argc < 2)
    {
        printf("Please read about usage :) Elf need a name of file that must be compressed.\n");
        return 0;
    }

    unsigned char* read_mem;
    unsigned char* write_mem;
    FILE *read_fp;
    FILE *write_fp;
    struct stat buf;
    unsigned int src_size;
    unsigned int out_size;

    char key_header[] = "-h";
    unsigned int size_header = 0;

    char prefix[] = "./";
    char *read_path = (char *)malloc(strlen(prefix) + strlen(argv[1]) + 1); //FREE read_path !!!
    strcpy(read_path, prefix);
    strncat(read_path, argv[1], strlen(prefix) + strlen(argv[1]));

    char postfix[] = ".out";
    char *write_path = (char *)malloc(strlen(read_path) + strlen(postfix) + 1); //FREE write_path !!!
    strcpy(write_path, read_path);
    strncat(write_path, postfix, strlen(read_path) + strlen(postfix));

    if ((stat(read_path, &buf)) != 0)
    {
        printf("Error: There is no file for uncompress!\n");
        free(read_path);
        free(write_path);
        return 0;
    }

    if (buf.st_size == 0)
    {
        printf("Error: Size of '%s' is %d bytes\n", argv[1], (unsigned int) buf.st_size);
        free(read_path);
        free(write_path);
        return 0;
    }

    printf("Size of '%s' is %d bytes.\n", argv[1], (unsigned int) buf.st_size);

    read_mem = (unsigned char*) malloc(buf.st_size);
    if (read_mem == 0)
    {
        printf("Memory allocating error (for read).\n");
        free(read_path);
        free(write_path);
        return 0;
    }

    read_fp = fopen(read_path, "rb");
    if  (read_fp == 0)
    {
        printf("Error: 'fopen' return error value (for read).\n");
        free(read_mem);
        free(read_path);
        free(write_path);
        return 0;
    }

    if (fread(read_mem, 1, buf.st_size, read_fp) != (unsigned int) buf.st_size)
    {
        printf("Error in 'fread'.\n");
        free(read_mem);
        free(read_path);
        free(write_path);
        return 0;
    }
    fclose(read_fp);

    src_size = buf.st_size;

    if (argc == 3)
    {
        if (strcmp(argv[2], key_header) == 0)
        {
            size_header = *(unsigned int*)&read_mem[10];
            src_size = src_size - size_header;
        }
    }

    write_mem = (unsigned char*) malloc((countGroups(src_size/2)) + src_size);
    if (write_mem == 0)
    {
        printf("Memory allocating error (for write).\n");
        free(read_mem);
        free(read_path);
        free(write_path);
        return 0;
    }

    out_size = compressRLE(src_size/2, read_mem + size_header, write_mem);

    write_fp = fopen(write_path, "wb");
    if  (write_fp == 0)
    {
        printf("Error: 'fopen' return error value (for write).\n");
        printf("Can't create %s%s!\n", argv[1], postfix);
        free(write_mem);
        free(read_mem);
        free(read_path);
        free(write_path);
        return 0;
    }
    fwrite(write_mem, 1, out_size, write_fp);
    fclose(write_fp);
    printf("All ok! Compressed file '%s%s' created!\n", argv[1], postfix);
    free(write_mem);
    free(read_mem);
    free(read_path);
    free(write_path);

    printf("Compressed size = %d bytes = 0x%x\n", out_size, out_size);
    return 0;
}
