#include "../include/common.h"
#include "../include/pgm_writer.h"

void write_pgm_image(const char *filename, void *data, int width, int height, int max_val) {
    FILE *f = fopen(filename, "wb");
    if (!f) {
        perror("fopen");
        exit(EXIT_FAILURE);
    }

    fprintf(f, "P5\n%d %d\n%d\n", width, height, max_val);
    size_t total = width * height;

    if (max_val < 256)
        fwrite(data, sizeof(byte), total, f);
    else
        fwrite(data, sizeof(ushort), total, f);

    fclose(f);
}
