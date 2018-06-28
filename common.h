#ifndef _COMMON_H_
#define _COMMON_H_

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

typedef enum { VOID_t, INT_t, FLOAT_t ,STRING_t } SEMTYPE;
typedef enum { ADD_t, SUB_t, MUL_t, DIV_t, MOD_t, LT_t, LE_t, EQ_t, GE_t, GT_t, NE_t, AND_t, OR_t, NOT_t, NONE_t, ASGN_t, ADDASGN_t, SUBASGN_t, MULASGN_t, DIVASGN_t, MODASGN_t, PRINTLN_t, PRINT_t } OPERATOR;

/* data_type structure to store integer, double values, and whether a variable is assigned value yet*/
typedef struct data_type {
    int iValue;
    double fValue;
    int assigned;
} DType;

/*linked list structure for hash table*/
typedef struct Node {
    int index;
    char *id;
    DType data;
    SEMTYPE type;
    int reg_num;
    struct Node *next;
} node;

typedef struct rule_type {
    int i_val, reg;
    double f_val;
    char* id;
    char* string;
    SEMTYPE type;
} RULE_TYPE;

/*to avoid 'constant' and 'declaration' conflicting*/
/*or else output duplicate 'ldc'*/
int VAR_flag;

/*for storing code*/
typedef struct CodeList{
    char *code;
    struct CodeList *nextline;
} codeList;


#endif
