#include <stdint.h>


volatile uint32_t * const result = (uint32_t*)0x80001000;
volatile uint32_t * const done = (uint32_t*)0x80001004;

int main() {
    int variable = 1;
    variable += 1;
    *result = variable;
    *done = 0xDEADBEEF;  // signal completion
    return 0;
}
