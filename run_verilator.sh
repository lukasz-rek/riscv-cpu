#!/bin/bash

# Simple script to run Verilator simulation

# Check if verilator is installed
if ! command -v verilator &> /dev/null; then
    echo "Error: Verilator is not installed. Please install it first."
    exit 1
fi

# Create output directory
mkdir -p obj_dir

# Run verilator
echo "Running Verilator..."
verilator -Wall --cc adder_tb.sv adder.sv --exe --build -j 0 -Mdir obj_dir --timing --main

# Check if compilation was successful
if [ $? -eq 0 ]; then
    echo "Compilation successful. Running simulation..."
    ./obj_dir/Vadder_tb
else
    echo "Compilation failed."
    exit 1
fi