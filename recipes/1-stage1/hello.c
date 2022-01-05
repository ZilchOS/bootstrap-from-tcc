#include <stdio.h>

#ifndef RECIPES_STAGE1
#define RECIPES_STAGE1 "/recipes/1-stage1"
#endif
#define SOURCE_PATH RECIPES_STAGE1"/hello.c"

int main(int argc, char** argv) {
	printf("Hello world!\n2*2=%d\n", 2*2);

	printf("Own source (%s):\n", SOURCE_PATH);
	FILE* f = fopen(SOURCE_PATH, "r");
	while (!feof(f)) {
		fputc(fgetc(f), stdout);
	}
	if (ferror(f))
		return 99;
	fclose(f);

	return 42;
}
