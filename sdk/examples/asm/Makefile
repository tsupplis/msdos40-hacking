hello.com: hello.obj
	link hello;
	exe2bin hello.exe hello.com

hello.obj: hello.asm
	masm hello.asm;

clean:
	if exist hello.obj del hello.obj
	if exist hello.exe del hello.exe
	if exist hello.com del hello.com
	if exist hello.map del hello.map
