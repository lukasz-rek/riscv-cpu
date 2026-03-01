CC      = riscv64-elf-gcc
OBJCOPY = riscv64-elf-objcopy
CFLAGS  = -march=rv32i_zicsr -mabi=ilp32 -nostdlib -ffreestanding -O3 \
          -I. \
          -DPERFORMANCE_RUN=1 -DITERATIONS=50 -DFLAGS_STR=\"-O3\"
LDFLAGS = -T ../linker.ld

BUILD_DIR = build

all: $(BUILD_DIR)/coremark.hex

$(BUILD_DIR)/coremark.hex: $(BUILD_DIR)/coremark.elf | $(BUILD_DIR)
	$(OBJCOPY) -O binary $< $(BUILD_DIR)/coremark.bin
	hexdump -v -e '1/1 "%02x\n"' $(BUILD_DIR)/coremark.bin > $@

$(BUILD_DIR)/coremark.elf: | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(LDFLAGS) ../start.S *.c -o $@ -lgcc

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

clean:
	rm -rf $(BUILD_DIR)

.PHONY: all clean
