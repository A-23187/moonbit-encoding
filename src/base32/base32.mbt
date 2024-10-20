pub enum Encoding {
  Encoding(String, Char)
  StdEncoding(Char)
}

trait EncodeTable {
  op_get(Self, Int) -> Char
}

trait DecodeTable {
  contains(Self, Char) -> Bool
  op_get(Self, Char) -> Int
  op_set(Self, Char, Int) -> Unit
}

impl DecodeTable for Bytes with contains(bytes : Bytes, ch : Char) -> Bool {
  ch.to_int() < bytes.length() && bytes[ch.to_int()] != 0xff
}

impl DecodeTable for Bytes with op_get(bytes : Bytes, ch : Char) -> Int {
  bytes[ch.to_int()].to_int()
}

impl DecodeTable for Bytes with op_set(bytes : Bytes, ch : Char, i : Int) -> Unit {
  bytes[ch.to_int()] = i.to_byte()
}

impl DecodeTable for Map[Char, Int] with op_get(map : Map[Char, Int], ch : Char) -> Int {
  map[ch].unwrap()
}

pub type! Base32EncodingError {
  Base32EncodingError(String)
  InvalidBase32CharError(Char, String)
  InvalidPaddingCharError(Char, String)
} derive(Eq, Show)

pub let no_padding = '\x00'

pub let std_padding = '='

fn init {
  std_padding |> ignore
}

fn check_encoding(
  encoding : Encoding
) -> (EncodeTable, DecodeTable, Char)!Base32EncodingError {
  let (encode_table, decode_table, padding_char) = match encoding {
    Encoding(encode_table, padding_char) => {
      if encode_table.length() != 32 {
        raise Base32EncodingError("encoding alphabet is not 32-characters long")
      }
      for c in encode_table {
        if c == '\r' || c == '\n' {
          raise InvalidBase32CharError(
            c, "encoding alphabet contains newline character",
          )
        }
      }
      let n = 1 +
        encode_table.fold(
          init=0,
          fn(i, c) { if i > c.to_int() { i } else { c.to_int() } },
        )
      let mut decode_table : DecodeTable = b""
      if n <= 256 {
        decode_table = Bytes::make(n, b'\xff')
      } else {
        let decode_table_map : Map[Char, Int] = {}
        decode_table = decode_table_map
      }
      for i, c in encode_table {
        if decode_table.contains(c) {
          raise Base32EncodingError(
            "encoding alphabet includes duplicate characters",
          )
        }
        decode_table[c] = i
      }
      (encode_table, decode_table, padding_char)
    }
    StdEncoding(padding_char) =>
      (
        "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567", b"\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\x1a\x1b\x1c\x1d\x1e\x1f\xff\xff\xff\xff\xff\xff\xff\xff\xff\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19",
        padding_char,
      )
  }
  if padding_char != no_padding {
    if padding_char == '\r' || padding_char == '\n' {
      raise InvalidPaddingCharError(padding_char, "invalid padding character")
    }
    if decode_table.contains(padding_char) {
      raise InvalidPaddingCharError(
        padding_char, "padding character contained in encoding alphabet",
      )
    }
  }
  (encode_table, decode_table, padding_char)
}

fn encoded_length(n : Int, padding : Bool) -> Int {
  if padding {
    8 * ((n + 4) / 5)
  } else {
    8 * (n / 5) + (8 * (n % 5) + 4) / 5
  }
}

pub fn encode(
  input : Bytes,
  ~encoding : Encoding = StdEncoding(std_padding)
) -> String!Base32EncodingError {
  let (encode_table, _, padding_char) = check_encoding!(encoding)
  let n = input.length()
  let r = n % 5 // n = 5*k + r
  let sb = StringBuilder::new(
    size_hint=2 * encoded_length(n, padding_char != no_padding),
  )
  // encode the first 5*k bytes
  let mut i = 0
  while i < n - r {
    let mut v = 0UL
    for j = 0; j < 5; j = j + 1 {
      v = (v << 8) | input[i + j].to_uint64()
    }
    for j = 35; j >= 0; j = j - 5 {
      sb.write_char(encode_table[((v >> j) & 0x1f).to_int()])
    }
    i = i + 5
  }
  //
  if r == 0 {
    return sb.to_string()
  }
  // encode the last `r` bytes to `remainning_n` chars
  let remaining_n = (8 * r + 4) / 5
  let mut v = 0UL
  for j = 0; j < r; j = j + 1 {
    v = (v << 8) | input[i + j].to_uint64()
  }
  v = v << (5 * remaining_n - 8 * r)
  for j = 5 * remaining_n - 5; j >= 0; j = j - 5 {
    sb.write_char(encode_table[((v >> j) & 0x1f).to_int()])
  }
  // padding with `padding_char`
  if padding_char != no_padding {
    for i = 0, padding_n = 8 - remaining_n; i < padding_n; i = i + 1 {
      sb.write_char(padding_char)
    }
  }
  sb.to_string()
}

fn decoded_length(n : Int, padding : Bool) -> Int {
  if padding {
    5 * (n / 8)
  } else {
    5 * (n / 8) + 5 * (n % 8) / 8
  }
}

pub fn decode(
  input : String,
  ~encoding : Encoding = StdEncoding(std_padding)
) -> Bytes!Base32EncodingError {
  let (_, decode_table, padding_char) = check_encoding!(encoding)
  let mut n = input.length()
  while n > 0 && input[n - 1] == padding_char {
    n = n - 1
  }
  for i = 0; i < n; i = i + 1 {
    if not(decode_table.contains(input[i])) {
      raise InvalidBase32CharError(input[i], "invalid base32 character")
    }
  }
  let output = Bytes::new(decoded_length(n, false))
  let mut oi = 0
  let r = n % 8 // n = 8k + r
  // decode the first 8*k chars
  let mut i = 0
  while i < n - r {
    let mut v = 0UL
    for j = 0; j < 8; j = j + 1 {
      v = (v << 5) | decode_table[input[i + j]].to_uint64()
    }
    for j = 32; j >= 0; j = j - 8 {
      output[oi] = ((v >> j) & 0xff).to_byte()
      oi = oi + 1
    }
    i = i + 8
  }
  //
  if r == 0 {
    return output
  }
  // decode the remaining `r` chars to `remaining_n` bytes
  let remaining_n = 5 * r / 8
  let mut v = 0UL
  for j = 0; j < r; j = j + 1 {
    v = (v << 5) | decode_table[input[i + j]].to_uint64()
  }
  v = v >> (5 * r - 8 * remaining_n)
  for j = 8 * remaining_n - 8; j >= 0; j = j - 8 {
    output[oi] = ((v >> j) & 0xff).to_byte()
    oi = oi + 1
  }
  output
}
