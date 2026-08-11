# makefile

#LDFLAGS = -lcurses -ltermcap
LDFLAGS = -lncurses
CFLAGS = -O -I../lib

tiar: tiar.o
	$(CC) -o $@ $@.o $(LDFLAGS)

clean:
	$(RM) tiar.o tiar
