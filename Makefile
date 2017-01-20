
all:
	cd src/tok64_src && mkdir -p ../../bin && /usr/bin/env gcc tok64.c && mv a.out ../../bin/tok64

clean:
	test -d src/tok64_src && rm bin/tok64 && rmdir bin
