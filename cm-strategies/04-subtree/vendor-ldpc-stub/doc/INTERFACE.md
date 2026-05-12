# LDPC Codec — Vendor Interface

| Signal     | Width | Dir | Notes |
|------------|-------|-----|-------|
| `clk`      | 1     | I   | System clock |
| `rst_n`    | 1     | I   | Active-low reset |
| `in_valid` | 1     | I   | Data valid |
| `in_data`  | 8     | I   | Bytes-in |
| `out_valid`| 1     | O   | Output valid |
| `out_data` | 8     | O   | Bytes-out |

## Parameters
- `CODEWORD = 4096`   : LDPC codeword length
- `ITERATIONS = 16`   : Decoder iteration limit

## Latency
Pass-through stub. Real vendor IP: ~120 cycles per codeword.
