# MDR-XB950N1 protocol map

## Transport and framing

- Bluetooth Classic RFCOMM
- Service UUID: `96CC203E-5068-46AD-B32D-E316F5E069BA`
- Table 1 message type: `0x0c`
- Acknowledgement message type: `0x01`
- Start/end bytes: `0x3e` / `0x3c`
- Escape byte: `0x3d`; escaped `3c`, `3d`, and `3e` become `3d 2c`, `3d 2d`,
  and `3d 2e`
- Body: `type | sequence | uint32be length | payload | checksum`
- Checksum: sum of every preceding unescaped body byte modulo 256

Every incoming command is acknowledged with an empty ACK frame whose sequence
is `1 - receivedSequence`.

## Commands

| Setting | Get payload | Set payload | Return / notify |
|---|---|---|---|
| Protocol version | `00 00` | — | `01` |
| Model / firmware | `04 01` / `04 02` | — | `05` |
| Capabilities | `06 00` | — | `07` |
| Battery | `10 00` | — | `11` / `13` |
| Surround VPT | `46 01` | `48 01 <preset>` | `47` / `49` |
| CLEAR BASS | `56 02` | `58 02 <signed-level>` | `57` / `59` |
| Noise cancelling | `66 01` | `68 01 01 <0|1>` | `67` / `69` |

Surround presets are Off `00`, Outdoor Stage `01`, Arena `02`, Concert Hall
`03`, and Club `04`. CLEAR BASS transports −10…+10 directly as a signed byte.

For example, CLEAR BASS −2 with sequence 1 is:

```text
3e 0c 01 00 00 00 03 58 02 fe 68 3c
```
