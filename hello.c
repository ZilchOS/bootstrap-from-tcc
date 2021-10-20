#include <stdio.h>

int main(int argc, char** argv) {
	printf("Hello world!\n2*2=%d\n", 2*2);
	printf("Own source:\n");
	FILE* f = fopen("/seed/src/hello.c", "r");
	while (!feof(f)) {
		fputc(fgetc(f), stdout);
	}
	if (ferror(f))
		return 99;
	fclose(f);
	return 42;
}
