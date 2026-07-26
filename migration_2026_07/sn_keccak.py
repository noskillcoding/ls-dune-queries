"""Pure-python Keccak-256 + starknet_keccak (no deps)."""

_RC = [
    0x0000000000000001, 0x0000000000008082, 0x800000000000808A, 0x8000000080008000,
    0x000000000000808B, 0x0000000080000001, 0x8000000080008081, 0x8000000000008009,
    0x000000000000008A, 0x0000000000000088, 0x0000000080008009, 0x000000008000000A,
    0x000000008000808B, 0x800000000000008B, 0x8000000000008089, 0x8000000000008003,
    0x8000000000008002, 0x8000000000000080, 0x000000000000800A, 0x800000008000000A,
    0x8000000080008081, 0x8000000000008080, 0x0000000080000001, 0x8000000080008008,
]
_ROT = [
    [0, 36, 3, 41, 18],
    [1, 44, 10, 45, 2],
    [62, 6, 43, 15, 61],
    [28, 55, 25, 21, 56],
    [27, 20, 39, 8, 14],
]
_M = (1 << 64) - 1


def _rol(x, n):
    n %= 64
    return ((x << n) | (x >> (64 - n))) & _M


def _keccak_f(A):
    for rnd in range(24):
        # theta
        C = [A[x][0] ^ A[x][1] ^ A[x][2] ^ A[x][3] ^ A[x][4] for x in range(5)]
        D = [C[(x - 1) % 5] ^ _rol(C[(x + 1) % 5], 1) for x in range(5)]
        for x in range(5):
            for y in range(5):
                A[x][y] ^= D[x]
        # rho + pi
        B = [[0] * 5 for _ in range(5)]
        for x in range(5):
            for y in range(5):
                B[y][(2 * x + 3 * y) % 5] = _rol(A[x][y], _ROT[x][y])
        # chi
        for x in range(5):
            for y in range(5):
                A[x][y] = B[x][y] ^ ((~B[(x + 1) % 5][y]) & B[(x + 2) % 5][y] & _M)
        # iota
        A[0][0] ^= _RC[rnd]
    return A


def keccak256(data: bytes) -> bytes:
    rate = 136  # bytes, for 256-bit output
    # Keccak (Ethereum/Starknet) padding: 0x01 ... 0x80
    padlen = rate - (len(data) % rate)
    if padlen == 1:
        data = data + b"\x81"
    else:
        data = data + b"\x01" + b"\x00" * (padlen - 2) + b"\x80"
    A = [[0] * 5 for _ in range(5)]
    for off in range(0, len(data), rate):
        block = data[off:off + rate]
        for i in range(rate // 8):
            lane = int.from_bytes(block[i * 8:(i + 1) * 8], "little")
            A[i % 5][i // 5] ^= lane
        A = _keccak_f(A)
    out = b""
    while len(out) < 32:
        for i in range(rate // 8):
            if len(out) >= 32:
                break
            out += (A[i % 5][i // 5]).to_bytes(8, "little")
        if len(out) < 32:
            A = _keccak_f(A)
    return out[:32]


MASK_250 = (1 << 250) - 1


def sn_keccak(name: str) -> int:
    """Starknet selector: keccak256(name) truncated to 250 bits."""
    return int.from_bytes(keccak256(name.encode()), "big") & MASK_250


def hx(i: int) -> str:
    return "0x" + format(i, "064x")


if __name__ == "__main__":
    # self-test: keccak256("") known digest
    assert keccak256(b"").hex() == \
        "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470", \
        keccak256(b"").hex()
    assert keccak256(b"abc").hex() == \
        "4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45"
    print("keccak256 self-test OK")
