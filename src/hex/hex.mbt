pub type! HexDecodeError {
  OddLengthHexStringError
  InvalidHexCharError(Char)
} derive(Eq, Show)

let hex_table = "0123456789abcdef"

let reverse_hex_table = b"\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\xff\xff\xff\xff\xff\xff\xff\x0a\x0b\x0c\x0d\x0e\x0f\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\x0a\x0b\x0c\x0d\x0e\x0f"

pub fn encode(input : Bytes) -> String {
  let hex = StringBuilder::new(size_hint=4 * input.length())
  for b in input {
    hex.write_char(hex_table[(b >> 4).to_int()])
    hex.write_char(hex_table[(b & 0x0f).to_int()])
  }
  hex.to_string()
}

pub fn decode(input : String) -> Bytes!HexDecodeError {
  if input.length() % 2 != 0 {
    raise OddLengthHexStringError
  }
  for c in input {
    if c.to_int() >= reverse_hex_table.length() || reverse_hex_table[c.to_int()] == 0xff {
      raise InvalidHexCharError(c)
    }
  }
  let bytes = Bytes::new(input.length() / 2)
  for i = 0; i < input.length(); i = i + 2 {
    let hi = reverse_hex_table[input[i].to_int()]
    let lo = reverse_hex_table[input[i + 1].to_int()]
    bytes[i / 2] = (hi << 4) | lo
  }
  bytes
}
