; This .j file is generated by the following micro go language
; var x int
; var a int = 2
; var y float32 = 1.3
; x = a + 5 * 2
; y = x - 3.2

.class public main
.super java/lang/Object
.method public static main([Ljava/lang/String;)V
.limit stack 10
.limit locals 10
	ldc 0
	istore 0
	ldc 2
	istore 1
	ldc 1.300000
	fstore 2
	iload 1
	ldc 5
	ldc 2
	imul
	iadd
	istore 0
	iload 0
	ldc 3.200000
	fstore 3 
	i2f 
	fload 3 
	fsub 
	fstore 2
	return
.end method
