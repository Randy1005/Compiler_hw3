#include "common.h"

void writeCode(char *buffer);
void printCode();

codeList *code_list;
int main(){
    char *buffer = (char *)malloc(512 * sizeof(buffer));
    int idx = 6;
    sprintf(buffer, "ldc %d", idx);

    writeCode("#include <stdio.h>");
    writeCode("#include <stdlib.h>");
    writeCode("#include <string.h>");
    writeCode(buffer);
    free(buffer);
    printCode();
    return 0;
}

void writeCode(char *buffer)
{
    if(code_list == NULL){
        code_list = (codeList *)malloc(sizeof(codeList));
        code_list -> code = (char *)malloc(512 * sizeof(char));
        strcpy(code_list->code, buffer);
        code_list->nextline = NULL;
    }
    else{
        codeList *curr = code_list;
        while(curr -> nextline != NULL)
            curr = curr -> nextline;

        /*append codeList node*/
        curr -> nextline = (codeList *)malloc(sizeof(codeList));
        curr -> nextline -> code = (char *)malloc(512 * sizeof(char));
        strcpy(curr -> nextline -> code, buffer);
        curr -> nextline -> nextline = NULL;
    }
}

void printCode()
{
    codeList *curr = code_list;


    while(curr != NULL){
        printf("%s\n", curr -> code);
        curr = curr -> nextline;
    }
}
