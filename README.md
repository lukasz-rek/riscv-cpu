Just making a riscv cpu for fun (questionable)!

# Build

Have verilator, verible, gtkwave and make installed

```
# To build and then run main core
make build run

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


