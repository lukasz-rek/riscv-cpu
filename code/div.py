BITS_INPUT = 8

BITS = BITS_INPUT + 1  # Account for sign


class Register:
    def __init__(self, width: int, value: int):
        self.width = width
        self.bits = [0] * width
        for i in range(0, width):
            self.bits[i] = (value >> i) & 1

    def __repr__(self) -> str:
        bin_str = f"{self.bits[self.width - 1]} "
        block_count = 0
        for i in range(self.width - 2, -1, -1):
            bin_str += str(self.bits[i])
            block_count += 1
            if block_count == 4:
                block_count = 0
                bin_str += " "
        return bin_str

    @classmethod
    def _from_bits(cls, width: int, bits: list[int]):
        r = cls.__new__(cls)
        r.width = width
        r.bits = bits[:]
        return r

    def __lshift__(self, n: int):
        new_bits = [0] * n + self.bits[: self.width - n]  # shift up, drop MSBs
        return Register._from_bits(self.width, new_bits)

    def __add__(self, other):
        new_bits = [0] * self.width
        carry = 0
        for i in range(self.width):
            s = self.bits[i] + other.bits[i] + carry
            new_bits[i] = s & 1
            carry = s >> 1
        return Register._from_bits(self.width, new_bits)

    def __int__(self):
        unsigned = sum(b << i for i, b in enumerate(self.bits))
        if self.sign:
            unsigned -= 1 << self.width
        return unsigned

    @property
    def sign(self) -> int:
        return self.bits[self.width - 1]


# Get values
a = int(input("Dividend: "))
b = int(input("Divisor:  "))
b_bits = Register(BITS, b)
z = Register(BITS, a)
d = Register(BITS, b) << BITS // 2
d_n = Register(BITS, -b) << BITS // 2
print("Received: ")
print(f"  z: {z}")
print(f"  b: {b_bits}")
print(f" d : {d}    =  {int(d)}")
print(f" dn: {d_n}    =  {int(d_n)}")
print("=" * 36)

# Begin division
r = Register(BITS, a)
q = Register(BITS // 2, 0)
zero_flag = 0

for i in range(0, BITS // 2):
    print(f" s{i} : {r}    =  {int(r)}\n")
    if int(r) == 0:
        print("Deteced zero s")
        zero_flag = 1
    r = r << 1
    print(f"2s{i} : {r}    =  {int(r)}")
    if r.sign == b_bits.sign:
        print(f"  -d: {d_n}    =  q: 1")
        r += d_n
        q = (q << 1) + Register(BITS, 1)
    else:
        print(f"  +d: {d}     != q: 0")
        r += d
        q = q << 1
    print("=" * 36)

print(f" s{BITS // 2} : {r}")
print(f" p  : {q}")
q = (q << 1) + Register(BITS // 2, 1)
print(f" q_c: {q}")
if (r.sign != z.sign or zero_flag) and int(r) != 0:
    print("Signs diff detected\n")
    if r.sign == d.sign:
        print("Signs match: s -= d, q += 1")
        r += d_n
        q += Register(BITS, 1)
    else:
        print("Signs mismatch: s += d, q -= 1")
        r += d
        q += Register(BITS, -1)

print(f" s{BITS // 2} : {r} = {int(r) >> 4}")
print(f" q  : {q} = {int(q)}")
