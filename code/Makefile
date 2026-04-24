CC = clang
OBJCOPY = llvm-objcopy

CFLAGS   = --target=riscv32 -march=rv32im -mabi=ilp32 -nostdlib -g -ffreestanding \
         -ffunction-sections -fdata-sections
LDFLAGS  = -fuse-ld=lld -Wl,--gc-sections -T linker.ld

BUILD_DIR = build

all: $(BUILD_DIR)/program.hex

$(BUILD_DIR)/program.hex: $(BUILD_DIR)/program.elf | $(BUILD_DIR)
	$(OBJCOPY) -O binary $< $(BUILD_DIR)/program.bin
	hexdump -v -e '1/4 "%08x\n"' $(BUILD_DIR)/program.bin > $@

$(BUILD_DIR)/program.elf: $(BUILD_DIR)/program.o $(BUILD_DIR)/start.o | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(LDFLAGS) $(BUILD_DIR)/start.o $(BUILD_DIR)/program.o -o $@

$(BUILD_DIR)/program.o: main.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/start.o: start.S | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

clean:
	rm -rf $(BUILD_DIR)

.PHONY: all clean
