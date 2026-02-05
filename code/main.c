#include <stdint.h>


volatile uint32_t * const result = (uint32_t*)0x80001000;
volatile uint32_t * const done = (uint32_t*)0x80001004;

int main() {
    int variable = 5;
    int abc = 200;
    variable *= abc;
    *result = variable;
    *done = 0xDEADBEEF;  // signal completion
    return 0;
}

int __mulsi3(int a, int b) {
    int res = 0;
    while (b > 0) {
        if (b & 1) {
            res += a;
        }
        a <<= 1;
        b >>= 1;
    }
    return res;
}