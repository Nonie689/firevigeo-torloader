##
## Makefile
##
## Licensed under GNU GPL v3

PREFIX := /usr/

all: 
	shc -S -f firevigeo.sh -o firevigeo
	\chown root:root firevigeo
	\chmod u+s firevigeo
	\chmod u+x firevigeo

clean :
	\rm *.x.c

cleanall :
	\rm firevigeo
	\rm *.x.c
#install:
#	chown root:root firevigeo
#	chmod u+s firevigeo
#	chmod u+x firevigeo
#	cp firevigeo $(PREFIX)bin/firevideo
#	mkdir -p $(PREFIX)lib/firevideo/
#	cp -r data $(PREFIX)lib/firevideo/data/
#	cp LICENSE $(PREFIX)lib/firevideo/LICENSE
#	cp country_codes.lst $(PREFIX)lib/firevideo/country_codes.lst
#
#uninstall:
#	\rm $(PREFIX)bin/firevideo
#
