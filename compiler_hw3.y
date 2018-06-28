/*	Definition section */
%{
#include "common.h" //Extern variables that communicate with lex

extern int yylineno;
extern int yylex();

/*display enum text*/
static char *SEM_str[] = {"VOID_t", "INT_t", "FLOAT_t", "STRING_t"};
static char *OP_str[] = {"ADD_t", "SUB_t", "MUL_t", "DIV_t", "MOD_t", "LT_t", "LE_t", "EQ_t", "GE_t", "GT_t", "NE_t", "AND_t", "OR_t", "NOT_t", "NONE_t", "ASGN_t", "ADDASGN_t", "SUBASGN_t", "MULASGN_t", "DIVASGN_t", "MODASGN_t"};

FILE *file;

void yyerror(const char* error);

/* symbol table function */
void create_symbol();
void insert_symbol(char *id, SEMTYPE type, DType data, int reg_num);
int lookup_symbol(char *id);
void dump_symbol();

/*write code to codeList*/
void writeCode(char *buffer);

/*print code to screen: for debugging*/
void printCode();

/*if no error occured, generate the code stored in code_list*/
void genCode(FILE *fp);

/*generate basic setup code*/
void genHeader();
void genFooter();

/*generate varible definition code*/
void defVar(char *id, SEMTYPE type, double val);

/*arithmetic casting*/
void arithmeticCast(SEMTYPE from, SEMTYPE to, OPERATOR op);

/*relational casting*/
void relaCast(SEMTYPE from, SEMTYPE to, OPERATOR op);

/*get ID type*/
SEMTYPE get_idType(char *id);

/*assign value to id (purpose: update symbol table)*/
void assign_id(char *id, double val);

/*get id value*/
double get_idVal(char *id);

/*for generating labels & EXITs*/
char *genEXIT();
char *getEXIT(int exitbNum);
char *genLabel();
char *getLabel(int labelNum);

/*count variables*/
int varCount = 0;

/*flag to indicate float32 ID occurrence*/
// int float32_occur;

int symTableSize = 10; //the hashing key will be 0 ~ 9
int idx = 0; //for assigning index to entries (not actual keys)

/*for symbol table*/
node *symTable[10];

/*for counting labels & EXITs*/
int labelCount = 0;
int exitCount = 0;

/*for storing code as linked list*/
codeList *code_list = NULL;

/*
error flag
constFlag, idFlag (for print_func)
*/
int ERR = 0;
int constFlag = 0;
int idFlag = 0;

%}

%union {
    RULE_TYPE rule_type;
    int intVal;
}

/* Token definition */
%token INC DEC
%token MTE LTE EQ NE
%token <rule_type> ADDASGN SUBASGN MULASGN DIVASGN MODASGN
%token AND OR NOT
%token PRINT PRINTLN
%token IF ELSE FOR
%token VAR
%token QUOTA
%token NEWLINE

%token <rule_type> I_CONST
%token <rule_type> F_CONST
%token <rule_type> VOID INT FLOAT STRING ID

%type <rule_type> initializer expr equality_expr relational_expr
%type <rule_type> additive_expr multiplicative_expr prefix_expr postfix_expr
%type <rule_type> primary_expr constant
%type <rule_type> type



%type <intVal> add_op mul_op print_func_op assignment_op equality_op relational_op

%type <intVal> _if


%start program

%right ')' ELSE

/* Grammar section */
%%


program: program stat
    |
;

stat: declaration
    | compound_stat
    | expression_stat
    | print_func
    | selection_stat
;



declaration: VAR ID type '=' initializer NEWLINE
            {
                //printf("ID = %s\n", $2.id);
                defVar($2.id, $3.type, $5.f_val);
                VAR_flag = 0;
            }
    | VAR ID type NEWLINE
    {
        //printf("ID = %s\n", $2.id);
        defVar($2.id, $3.type, 0);
        VAR_flag = 0;
    }
;

type: INT   {$$ = $1; /*printf("$$ = %s\n", SEM_str[$$.type]);*/ }
    | FLOAT {$$ = $1; /*printf("$$ = %s\n", SEM_str[$$.type]);*/ }
    | VOID  {$$ = $1; /*printf("$$ = %s\n", SEM_str[$$.type]);*/ }
;

initializer: equality_expr
;

compound_stat: '{' '}'
    | '{' block_item_list '}'
;

block_item_list: block_item
    | block_item_list block_item
;

block_item: stat
;

else_stmt: ELSE stat
    |
;

_if: IF
{
    $$ = labelCount;
    labelCount++;
}
;

selection_stat: _if '(' expr ')'
{
    char *buffer = (char *)malloc(512 * sizeof(char));
    sprintf(buffer, " Label_%d", $1);
    writeCode(buffer);
}
stat
{
    char *buffer = (char *)malloc(512 * sizeof(char));
    sprintf(buffer, "\tgoto EXIT_%d", $1);
    writeCode(buffer);
    sprintf(buffer, "Label_%d:", $1);
    writeCode(buffer);
}
else_stmt
{
    char *buffer = (char *)malloc(512 * sizeof(char));
    sprintf(buffer, "EXIT_%d:", $1);
    writeCode(buffer);
}
;

expression_stat: expr NEWLINE
    | NEWLINE
;

expr: equality_expr {$$ = $1;}
    | ID '=' expr
    {
        assign_id($1.id, $3.f_val);

        if(get_idType($1.id) == INT_t){
            arithmeticCast($3.type, get_idType($1.id), ASGN_t);

            char *buffer = (char *)malloc(512 * sizeof(char));
            sprintf(buffer, "\tistore %d", lookup_symbol($1.id));
            writeCode(buffer);
            free(buffer);
        }
        else if(get_idType($1.id) == FLOAT_t){
            arithmeticCast($3.type, get_idType($1.id), ASGN_t);

            char *buffer = (char *)malloc(512 * sizeof(char));
            sprintf(buffer, "\tfstore %d", lookup_symbol($1.id));
            writeCode(buffer);
            free(buffer);
        }

    }
    | prefix_expr assignment_op expr
    {
        // printf("assign op = %s\n", OP_str[$2]);
        if($2 == ADDASGN_t){
            /*update symbol table*/
            assign_id($1.id, get_idVal($1.id) + $3.f_val);

            /*generate code*/
            arithmeticCast($3.type, $1.type, ADD_t);
            if($1.type == INT_t){
                char *buffer = (char *)malloc(512 * sizeof(char));
                sprintf(buffer, "\tistore %d", lookup_symbol($1.id));
                writeCode(buffer);
                free(buffer);
            }
            else if($1.type == FLOAT_t){
                char *buffer = (char *)malloc(512 * sizeof(char));
                sprintf(buffer, "\tfstore %d", lookup_symbol($1.id));
                writeCode(buffer);
                free(buffer);
            }

        }
        else if($2 == SUBASGN_t){
            /*update symbol table*/
            assign_id($1.id, get_idVal($1.id) - $3.f_val);

            /*generate code*/
            arithmeticCast($3.type, $1.type, SUB_t);
            if($1.type == INT_t){
                char *buffer = (char *)malloc(512 * sizeof(char));
                sprintf(buffer, "\tistore %d", lookup_symbol($1.id));
                writeCode(buffer);
                free(buffer);
            }
            else if($1.type == FLOAT_t){
                char *buffer = (char *)malloc(512 * sizeof(char));
                sprintf(buffer, "\tfstore %d", lookup_symbol($1.id));
                writeCode(buffer);
                free(buffer);
            }

        }
        else if($2 == MULASGN_t){
            /*update symbol table*/
            assign_id($1.id, get_idVal($1.id) * $3.f_val);

            /*generate code*/
            arithmeticCast($3.type, $1.type, MUL_t);
            if($1.type == INT_t){
                char *buffer = (char *)malloc(512 * sizeof(char));
                sprintf(buffer, "\tistore %d", lookup_symbol($1.id));
                writeCode(buffer);
                free(buffer);
            }
            else if($1.type == FLOAT_t){
                char *buffer = (char *)malloc(512 * sizeof(char));
                sprintf(buffer, "\tfstore %d", lookup_symbol($1.id));
                writeCode(buffer);
                free(buffer);
            }
        }
        else if($2 == DIVASGN_t){
            if($3.f_val == 0){
                printf("<<ERROR>> Divide By Zero. [line %d]\n", yylineno);
                ERR = 1;
            }
            else{
                /*update symbol table*/
                assign_id($1.id, get_idVal($1.id) / $3.f_val);

                /*generate code*/
                arithmeticCast($3.type, $1.type, DIV_t);
                if($1.type == INT_t){
                    char *buffer = (char *)malloc(512 * sizeof(char));
                    sprintf(buffer, "\tistore %d", lookup_symbol($1.id));
                    writeCode(buffer);
                    free(buffer);
                }
                else if($1.type == FLOAT_t){
                    char *buffer = (char *)malloc(512 * sizeof(char));
                    sprintf(buffer, "\tfstore %d", lookup_symbol($1.id));
                    writeCode(buffer);
                    free(buffer);
                }
            }
        }
        else if($2 == MODASGN_t){
            if($3.f_val == 0){
                printf("<<ERROR>> MOD By Zero. [line %d]\n", yylineno);
                ERR = 1;
            }
            else if($3.type == FLOAT_t){
                printf("<<ERROR>> MOD involving float32 type. [line %d]\n", yylineno);
                ERR = 1;
            }
            else{
                /*update symbol table*/
                assign_id($1.id, (int)get_idVal($1.id) % (int)$3.f_val);

                /*generate code*/
                arithmeticCast($3.type, $1.type, MOD_t);
                if($1.type == INT_t){
                    char *buffer = (char *)malloc(512 * sizeof(char));
                    sprintf(buffer, "\tistore %d", lookup_symbol($1.id));
                    writeCode(buffer);
                    free(buffer);
                }
                else if($1.type == FLOAT_t){
                    char *buffer = (char *)malloc(512 * sizeof(char));
                    sprintf(buffer, "\tfstore %d", lookup_symbol($1.id));
                    writeCode(buffer);
                    free(buffer);
                }

            }

        }

    }
;

assignment_op: ADDASGN  {$$ = ADDASGN_t;}
    | SUBASGN   {$$ = SUBASGN_t;}
    | MULASGN   {$$ = MULASGN_t;}
    | DIVASGN   {$$ = DIVASGN_t;}
    | MODASGN   {$$ = MODASGN_t;}
;

equality_expr: relational_expr
    | equality_expr equality_op relational_expr
    {
        if($2 == EQ_t){
            relaCast($1.type, $3.type, EQ_t); //test equality
            char *buffer = (char *)malloc(512 * sizeof(char));
            writeCode("ifne");
            free(buffer);

            $$.type = $2;
        }
        else if($2 == NE_t){
            relaCast($1.type, $3.type, NE_t); //test equality
            char *buffer = (char *)malloc(512 * sizeof(char));
            writeCode("ifeq");
            free(buffer);

            $$.type = $2;
        }
    }
;

equality_op: EQ {$$ = EQ_t;}
    | NE    {$$ = NE_t;}
;

relational_expr: additive_expr
    | relational_expr relational_op additive_expr
    {
        if($2 == LT_t){
            relaCast($1.type, $3.type, LT_t);
            writeCode("ifge");

            $$.type = $2;

        }
        else if($2 == GT_t){
            relaCast($1.type, $3.type, GT_t);
            writeCode("ifle");

            $$.type = $2;
        }
        else if($2 == LE_t){
            relaCast($1.type, $3.type, LE_t);
            writeCode("ifgt");

            $$.type = $2;

        }
        else if($2 == GE_t){
            relaCast($1.type, $3.type, GE_t);
            writeCode("iflt");

            $$.type = $2;

        }

    }
;

relational_op: '<'  {$$ = LT_t;}
    | '>'   {$$ = GT_t;}
    | LTE   {$$ = LE_t;}
    | MTE   {$$ = GE_t;}
;

additive_expr: multiplicative_expr  {$$ = $1;}
    | additive_expr add_op multiplicative_expr
    {

        arithmeticCast($1.type, $3.type, $2); //write code

        /*return values*/
        if($2 == ADD_t)
            $$.f_val = $1.f_val + $3.f_val;
        else if($2 == SUB_t)
            $$.f_val = $1.f_val - $3.f_val;
    }
;

add_op: '+' {$$ = ADD_t;}
    | '-'   {$$ = SUB_t;}
;

multiplicative_expr: prefix_expr    {$$ = $1;}
    | multiplicative_expr mul_op prefix_expr
    {
        if($3.f_val == 0 && $2 == DIV_t){ //error: divide by 0
            printf("<<ERROR>> Divide By Zero. [line %d]\n", yylineno);
            ERR = 1;
        }

        if($3.f_val == 0 && $2 == MOD_t){ //error: mod by 0
            printf("<<ERROR>> MOD By Zero. [line %d]\n", yylineno);
            ERR = 1;
        }

        if($2 == MOD_t && ($1.type == FLOAT_t || $3.type == FLOAT_t)){
            printf("<<ERROR>> MOD Involving float32. [line %d]\n", yylineno);
            ERR = 1;
        }

        arithmeticCast($1.type, $3.type, $2); // write code

        /*return values*/
        if($2 == MUL_t){
            $$.f_val = $1.f_val * $3.f_val;
        }
        else if($2 == DIV_t){
            $$.f_val = $1.f_val / $3.f_val;
        }
        else if($2 == MOD_t){
            $$.f_val = (int)$1.f_val % (int)$3.f_val;
        }


    }
;

mul_op: '*' {$$ = MUL_t;}
    | '/'   {$$ = DIV_t;}
    | '%'   {$$ = MOD_t;}
;

prefix_expr: postfix_expr
    | INC prefix_expr
    {
        assign_id($2.id, get_idVal($2.id) + 1.0);
        writeCode("\tldc 1");
        arithmeticCast($2.type, $2.type, ADD_t);

        if($2.type == INT_t){
            char *buffer = (char *)malloc(512 * sizeof(char));
            sprintf(buffer, "\tistore %d", lookup_symbol($2.id));
            writeCode(buffer);
            free(buffer);
        }
        else if($2.type == FLOAT_t){
            char *buffer = (char *)malloc(512 * sizeof(char));
            sprintf(buffer, "\tfstore %d", lookup_symbol($2.id));
            writeCode(buffer);
            free(buffer);
        }
    }
    | DEC prefix_expr
    {
        assign_id($2.id, get_idVal($2.id) - 1.0);
        writeCode("\tldc 1");
        arithmeticCast($2.type, $2.type, SUB_t);

        if($2.type == INT_t){
            char *buffer = (char *)malloc(512 * sizeof(char));
            sprintf(buffer, "\tistore %d", lookup_symbol($2.id));
            writeCode(buffer);
            free(buffer);
        }
        else if($2.type == FLOAT_t){
            char *buffer = (char *)malloc(512 * sizeof(char));
            sprintf(buffer, "\tfstore %d", lookup_symbol($2.id));
            writeCode(buffer);
            free(buffer);
        }
    }
;

postfix_expr: primary_expr
    | postfix_expr INC
    {
        assign_id($1.id, get_idVal($1.id) + 1.0);
        writeCode("\tldc 1");
        arithmeticCast($1.type, $1.type, ADD_t);

        if($1.type == INT_t){
            char *buffer = (char *)malloc(512 * sizeof(char));
            sprintf(buffer, "\tistore %d", lookup_symbol($1.id));
            writeCode(buffer);
            free(buffer);
        }
        else if($1.type == FLOAT_t){
            char *buffer = (char *)malloc(512 * sizeof(char));
            sprintf(buffer, "\tfstore %d", lookup_symbol($1.id));
            writeCode(buffer);
            free(buffer);
        }
    }
    | postfix_expr DEC
    {
        assign_id($1.id, get_idVal($1.id) - 1.0);
        writeCode("\tldc 1");
        arithmeticCast($1.type, $1.type, SUB_t);

        if($1.type == INT_t){
            char *buffer = (char *)malloc(512 * sizeof(char));
            sprintf(buffer, "\tistore %d", lookup_symbol($1.id));
            writeCode(buffer);
            free(buffer);
        }
        else if($1.type == FLOAT_t){
            char *buffer = (char *)malloc(512 * sizeof(char));
            sprintf(buffer, "\tfstore %d", lookup_symbol($1.id));
            writeCode(buffer);
            free(buffer);
        }
    }
;

primary_expr: ID
            {
                if(lookup_symbol($1.id) == -1){ //error: ID not in symbol table
                    printf("<<ERROR>> Variable \"%s\" Undeclared. [line %d]", $1.id, yylineno);
                    ERR = 1;
                }
                else{
                    idFlag = 1;
                    if(get_idType($1.id) == INT_t){
                        char *buffer = (char *)malloc(512 * sizeof(char));
                        sprintf(buffer, "\tiload %d", lookup_symbol($1.id));
                        writeCode(buffer);
                        free(buffer);
                    }
                    else if(get_idType($1.id) == FLOAT_t){
                        char *buffer = (char *)malloc(512 * sizeof(char));
                        sprintf(buffer, "\tfload %d", lookup_symbol($1.id));
                        writeCode(buffer);
                        free(buffer);
                        // float32_occur = 1;
                    }

                    $$.type = get_idType($1.id);
                }
            }
    | constant
    {
        if(!VAR_flag){
            constFlag = 1;
            char *buffer = (char *)malloc(512 * sizeof(char));
            if($1.type == INT_t){
                $1.type = INT_t;
                sprintf(buffer, "\tldc %d", (int)$1.f_val);
            }
            else if($1.type == FLOAT_t){
                $1.type = FLOAT_t;
                sprintf(buffer, "\tldc %.6lf", $1.f_val);
                // float32_occur = 1;
            }
            writeCode(buffer);
            free(buffer);
            $$ = $1;
        }
    }
    | '(' expr ')'  {$$ = $2;}
;

constant: I_CONST
        {
            $1.type = INT_t;
            $$ = $1;
        }
    | F_CONST
    {
        $1.type = FLOAT_t;
        $$ = $1;
    }
;

print_func: print_func_op '(' equality_expr ')' NEWLINE
            {
                if($1 == PRINT_t){
                    if(get_idType($3.id) == INT_t && idFlag){
                        writeCode("\tgetstatic java/lang/System/out Ljava/io/PrintStream;");
                        writeCode("\tswap");
                        writeCode("\tinvokevirtual java/io/PrintStream/print(I)V");
                    }
                    else if(get_idType($3.id) == FLOAT_t && idFlag){
                        writeCode("\tgetstatic java/lang/System/out Ljava/io/PrintStream;");
                        writeCode("\tswap");
                        writeCode("\tinvokevirtual java/io/PrintStream/print(F)V");
                    }
                    else if(constFlag && $3.type == INT_t){
                        writeCode("\tgetstatic java/lang/System/out Ljava/io/PrintStream;");
                        writeCode("\tswap");
                        writeCode("\tinvokevirtual java/io/PrintStream/print(I)V");
                    }
                    else if(constFlag && $3.type == FLOAT_t){
                        writeCode("\tgetstatic java/lang/System/out Ljava/io/PrintStream;");
                        writeCode("\tswap");
                        writeCode("\tinvokevirtual java/io/PrintStream/print(F)V");
                    }

                    idFlag = 0;
                    constFlag = 0;

                }
                else if($1 == PRINTLN_t){
                    if(get_idType($3.id) == INT_t && idFlag){
                        writeCode("\tgetstatic java/lang/System/out Ljava/io/PrintStream;");
                        writeCode("\tswap");
                        writeCode("\tinvokevirtual java/io/PrintStream/println(I)V");
                    }
                    else if(get_idType($3.id) == FLOAT_t && idFlag){
                        writeCode("\tgetstatic java/lang/System/out Ljava/io/PrintStream;");
                        writeCode("\tswap");
                        writeCode("\tinvokevirtual java/io/PrintStream/println(F)V");
                    }
                     else if(constFlag && $3.type == INT_t){
                        writeCode("\tgetstatic java/lang/System/out Ljava/io/PrintStream;");
                        writeCode("\tswap");
                        writeCode("\tinvokevirtual java/io/PrintStream/println(I)V");
                    }
                    else if(constFlag && $3.type == FLOAT_t){
                        writeCode("\tgetstatic java/lang/System/out Ljava/io/PrintStream;");
                        writeCode("\tswap");
                        writeCode("\tinvokevirtual java/io/PrintStream/println(F)V");
                    }

                    idFlag = 0;
                    constFlag = 0;
                }
            }
    | print_func_op '(' QUOTA STRING QUOTA ')' NEWLINE
    {
        if($1 == PRINT_t){
            // ldc STRING
            char *buffer = (char *)malloc(512 * sizeof(char));
            sprintf(buffer, "\tldc \"%s\"", $4.string);
            writeCode(buffer);
            free(buffer);

            writeCode("\tgetstatic java/lang/System/out Ljava/io/PrintStream;");
            writeCode("\tswap");
            writeCode("\tinvokevirtual java/io/PrintStream/print(Ljava/lang/String;)V");
        }
        else if($1 == PRINTLN_t){
            // ldc STRING
            char *buffer = (char *)malloc(512 * sizeof(char));
            sprintf(buffer, "\tldc \"%s\"", $4.string);
            writeCode(buffer);
            free(buffer);

            writeCode("\tgetstatic java/lang/System/out Ljava/io/PrintStream;");
            writeCode("\tswap");
            writeCode("\tinvokevirtual java/io/PrintStream/println(Ljava/lang/String;)V");
        }
    }
;

print_func_op: PRINT    {$$ = PRINT_t;}
    | PRINTLN   {$$ = PRINTLN_t;}
;

%%

/* C code section */
int main(int argc, char** argv)
{
    yylineno = 0;

    genHeader(); //header code
    yyparse();
    genFooter(); //footer code

    // printCode();
    if(!ERR)
        genCode(file);

    dump_symbol();

    return 0;
}

void yyerror (char const *s) {
  fflush(stdout);
  fprintf(stderr, "%s\n", s);
}


/*hashing function*/
int strToKey(char *id)
{
    int cValue, s = 0;
    for(int i=0; i<strlen(id); i++){
        cValue = id[i];
        s += cValue;
    }

    return s; //this gives us the sum of all the ascii value
}

/*create symbol table*/
void create_symbol()
{
    printf("Create Symbol Table.\n");
    for(int i=0; i<symTableSize; i++)
        symTable[i] = NULL;
}

/*insert entry*/
void insert_symbol(char *id, SEMTYPE type, DType data, int reg_num)
{
    int ascii, key;
    node *tmp, *tmp2;
    tmp = (node *)malloc(sizeof(node));
    tmp -> next = NULL;

    /*assign ID, index, type, and data*/
    tmp -> id = (char *)malloc(256 * sizeof(char));
    strcpy(tmp -> id, id);
    tmp -> index = idx;
    tmp -> type = type;
    tmp -> data = data;
    tmp -> reg_num = reg_num;

    /*decide key from hashing function*/
    ascii = strToKey(id);
    key = ascii % symTableSize;

    /*insert into symbol_table*/
    if(symTable[key] == NULL){ //no entry inserted yet
        symTable[key] = tmp;
        idx++; //index increment
        varCount++;
        printf("insert a symbol: %s \n", tmp -> id);
    }
    else{ //already occupied, then append to it
        tmp2 = symTable[key];
        while(tmp2 -> next != NULL)
            tmp2 = tmp2 -> next;

        tmp2 -> next = tmp;
        idx++; //index increment
        varCount++;
        printf("insert a symbol: %s \n", tmp -> id);
    }
}

/*lookup entry, return index if exist*/
int lookup_symbol(char *id)
{
    node *tmp;
    int ascii = strToKey(id);
    int key = ascii % symTableSize;

    /*look up symTable*/
    if(symTable[key] == NULL){
        return -1; //no ID inserted yet
    }
    else{
        tmp = symTable[key];
        while(tmp != NULL){
            if(!strcmp(tmp -> id, id)){
                return tmp -> index;
            }
            tmp = tmp -> next;
        }

        return -1; //if ID is not found
    }
}

/*show table*/
void dump_symbol()
{
    printf("\n");
    if(varCount != 0){
        printf("The Symbol Table Dumps:\n");
        printf("index\tID\ttype\tData\tlocals\n");

        node *tmp;
        for(int idx = 0; idx<varCount; idx++){
            for(int i=0; i<symTableSize; i++){
                tmp = symTable[i];

                if(tmp == NULL)
                    continue;

                while(tmp != NULL){
                    if(tmp -> index == idx){
                        printf("%d\t%s\t", tmp -> index, tmp -> id);

                        if(tmp -> type == INT_t){ // int type
                            if(tmp -> data.assigned) //if it's been assigned value
                                printf("int\t%d\t", tmp -> data.iValue);
                            else
                                printf("int\t%s\t", "unassigned");

                        }
                        else if(tmp -> type == FLOAT_t){ // float32 type
                            if(tmp -> data.assigned) //if it's been assigned value
                                printf("float32\t%.4lf\t", tmp -> data.fValue);
                            else
                                printf("float32\t%s\t", "unassigned");
                        }

                        printf("%d\n", tmp -> reg_num);


                        break;
                    }
                    else{
                        if(tmp -> next == NULL)
                            break;
                        tmp = tmp -> next;
                    }
                }
            }
        }
    }
    else{
        printf("Symbol Table Empty.\n");
    }
}

void genCode(FILE *fp){
    codeList *tmp;
    fp = fopen("Computer.j", "w");
    if (fp == NULL)
        printf("error opening file.\n");
    else{
        tmp = code_list;
        while(tmp != NULL){
            if(tmp -> code[0] == 'i' && tmp -> code[1] == 'f'){
                fprintf(fp, "%s", tmp -> code);
                tmp = tmp -> nextline;
            }
            else{
                fprintf(fp, "%s\n", tmp -> code);
                tmp = tmp -> nextline;
            }
        }
    }
    fclose(fp);
}

void writeCode(char *buffer)
{
    if(code_list == NULL){
        code_list = (codeList *)malloc(sizeof(codeList));
        code_list -> code = (char *)malloc(512 * sizeof(char));
        strcpy(code_list -> code, buffer);
        code_list -> nextline = NULL;
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


void genHeader()
{
    writeCode(".class public main");
    writeCode(".super java/lang/Object");
    writeCode(".method public static main([Ljava/lang/String;)V");
    writeCode(".limit stack 10");
    writeCode(".limit locals 10");
}

void genFooter()
{
    writeCode("return");
    writeCode(".end method");
}

void defVar(char *id, SEMTYPE type, double val)
{
    if(lookup_symbol(id) != -1){
        printf("<<ERROR>> Variable \"%s\" Redefined. [line %d]\n", id, yylineno);
        ERR = 1;
    }
    else{
        if(type == INT_t){ //int type
            /*write code to file*/
            char *buffer = (char *)malloc(512 * sizeof(char));
            sprintf(buffer, "\tldc %d", (int)val); //ldc (value)
            writeCode(buffer);
            sprintf(buffer, "\tistore %d", idx); //istore (stkcnt)
            writeCode(buffer);
            free(buffer);

            /*symbol table update*/
            DType tmpData;
            tmpData.iValue = (int)val;
            tmpData.assigned = 1;
            insert_symbol(id, INT_t, tmpData, idx);
        }
        else if(type == FLOAT_t){ //float32
            /*write code to file*/
            char *buffer = (char *)malloc(512 * sizeof(char));
            sprintf(buffer, "\tldc %.6lf", val); //ldc (value)
            writeCode(buffer);
            sprintf(buffer, "\tfstore %d", idx); //fstore (stkcnt)
            writeCode(buffer);
            free(buffer);

            /*symbol table update*/
            DType tmpData;
            tmpData.fValue = val;
            tmpData.assigned = 1;
            insert_symbol(id, FLOAT_t, tmpData, idx);
        }
    }

}


void arithmeticCast(SEMTYPE from, SEMTYPE to, OPERATOR op)
{
    if(from == to){ //if no need to cast, just perform arithmetic op
        if(from == INT_t){
            if(op == ADD_t){
                writeCode("\tiadd");
            }
            else if(op == SUB_t){
                writeCode("\tisub");
            }
            else if(op == MUL_t){
                writeCode("\timul");
            }
            else if(op == DIV_t){
                writeCode("\tidiv");
            }
            else if(op == MOD_t){
                writeCode("\tirem");
            }
        }
        else if(from == FLOAT_t){
            if(op == ADD_t){
                writeCode("\tfadd");
            }
            else if(op == SUB_t){
                writeCode("\tfsub");
            }
            else if(op == MUL_t){
                writeCode("\tfmul");
            }
            else if(op == DIV_t){
                writeCode("\tfdiv");
            }
            else if(op == MOD_t){ //error: mod involving float32
                printf("<<ERROR>> MOD involving float32 type. [line %d]\n", yylineno);
                ERR = 1;
            }
        }
    }
    else{ //TODO: casting
        /*
        if(from == INT_t && to == FLOAT_t){
            writeCode("\ti2f");
        }
        else if(from == FLOAT_t && to == INT_t){
            writeCode("\tf2i");
        }
        */
    }
}


void assign_id(char *id, double val)
{
    int ascii, key;
    node *tmp;
    tmp = (node *)malloc(sizeof(node));
    tmp -> next = NULL;
    ascii = strToKey(id);
    key = ascii % symTableSize;

    /*start searching*/
    tmp = symTable[key];
    while(tmp != NULL){
        if(!strcmp(tmp -> id, id)){
            // assign value to table
            if(tmp -> type == INT_t){ //int
                tmp -> data.assigned = 1;
                tmp -> data.iValue = (int)val;
            }
            else if(tmp -> type == FLOAT_t){ //float32
                tmp -> data.assigned = 1;
                tmp -> data.fValue = val;
            }
        }
        tmp = tmp -> next;
    }
}

/*to get id value*/
double get_idVal(char *id){
    int ascii, key;
    node *tmp;
    tmp = (node *)malloc(sizeof(node));
    tmp -> next = NULL;

    ascii = strToKey(id);
    key = ascii % symTableSize;

    /*start searching*/
    tmp = symTable[key];
    while(tmp != NULL){
        if(!strcmp(tmp -> id, id)){
            if(tmp -> type == INT_t){ //int type
                return (double)(tmp -> data.iValue);
            }
            else if(tmp -> type == FLOAT_t){ //float32 type
                return tmp -> data.fValue;
            }
        }
        tmp = tmp -> next;
    }
}

/*to get id type*/
SEMTYPE get_idType(char *id){
    int ascii, key;
    node *tmp;
    tmp = (node *)malloc(sizeof(node));
    tmp -> next = NULL;

    ascii = strToKey(id);
    key = ascii % symTableSize;

    /*start searching*/
    tmp = symTable[key];
    while(tmp != NULL){
        if(!strcmp(tmp -> id, id)){
            return tmp -> type;
        }
        tmp = tmp -> next;
    }
}

/*to generate labels*/
char *genLabel(){
    char *str = (char *)malloc(512 * sizeof(char));
    sprintf(str, "Label_%d", labelCount++);
    return str;
}

/*to generate EXITs*/
char *genEXIT(){
    char *str = (char *)malloc(512 * sizeof(char));
    sprintf(str, "EXIT_%d", exitCount++);
    return str;
}

/*to get the labels that has already been generated*/
char *getLabel(int labNum){
    char *str = (char *)malloc(512 * sizeof(char));
    sprintf(str, "Label_%d", labNum);
    return str;
}

/*to get the labels that has already been generated*/
char *getEXIT(int exitNum){
    char *str = (char *)malloc(512 * sizeof(char));
    sprintf(str, "EXIT_%d", exitNum);
    return str;
}

/*relational ops*/
void relaCast(SEMTYPE from, SEMTYPE to, OPERATOR op)
{
    if(from == to){ //if no need to cast
        if(from == INT_t || from == FLOAT_t){
            writeCode("\tisub");
        }
    }
    else{
        // TODO: relational casting
    }
}



