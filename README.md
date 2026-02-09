Just making a riscv cpu to learn out of order execution in depth and to just benchmark random bits of knowledge I've had. 
* Is making fancy computer arithmetic faster than just + in Vivado?
* Is out of order exec that much better (probably but idk)?
* What caching and branch prediction seems to work better
* How does that all work out on actual hardware next to me?
* Other stuff like this

They should've tought me all that at uni but they only teased it.

Currently, there is a simple riscv32i implementation that does everything in a single cycle and stalls when reading memory from BRAM. Slow but works. It also has .tcl script that compiles everything for a kria kv260 so the timing/area impacts can be measured. Next I wanna port coremark, maybe dhrystone also and then go on to implement improvements and see whether they are actually worth anything. 

# Build

Have verilator, verible, gtkwave and make installed

```
# To build and then run main core with the code from code/main.c
make build run

# To re-compile code in code/main.c, tho it should happen with above target
make code

# For quick linting checks or formatting with verible
make lint
make format

# To build & run for specific module
make build TOP_MODULE_NAME=register_file run

# To check some waves
gtkwave logs/waveform.fst


```

# Tests
For now LLM made placeholders, I will need to improve them one day.


