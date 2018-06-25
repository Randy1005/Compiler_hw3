#include <stdio.h>
#include <stdlib.h>

void writeCode(FILE *fp, char *code){
    fp = fopen("Computer.j", "a");
    if (fp == NULL)
        printf("error opening file.\n");
    else
        fprintf(fp, "%s\n", code);

    fclose(fp);
}

int main(){
    FILE *fp;
    writeCode(fp, "#include <stdio.h>");
    return 0;
}
