CC = gcc 
CFLAGS = -m32 -O3 -I. -DPERFORMANCE_RUN=1 -DITERATIONS=60000 -DFLAGS_STR=\"-O3\"

# Source files

coremark: 
	$(CC) $(CFLAGS) *.c -o coremark -lm 

clean:
	rm coremark

.PHONY: clean