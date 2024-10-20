test "encode with StdEncoding" {
  let tests = [
    ('=', b"", Ok("")),
    (
      '=',
      b"\x00\x44\x32\x14\xc7\x42\x54\xb6\x35\xcf\x84\x65\x3a\x56\xd7\xc6\x75\xbe\x77\xdf",
      Ok("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"),
    ),
    ('=', b"\x19\x00\x30\x90\x85\xd6", Ok("DEADBEEF2Y======")),
    ('+', b"\x19\x00\x30\x90\x85\xe7\x39", Ok("DEADBEEF444Q++++")),
    ('-', b"\x19\x00\x30\x90\x85\xef\x7b\xde", Ok("DEADBEEF55554---")),
    (
      @base32.no_padding,
      b"\x19\x00\x30\x90\x85\xff\xff\xff\xff",
      Ok("DEADBEEF777777Y"),
    ),
  ]
  for t in tests {
    let (padding_char, input, result) = t
    if padding_char == @base32.std_padding {
      assert_eq!(@base32.encode?(input), result)
    } else {
      assert_eq!(
        @base32.encode?(input, encoding=@base32.StdEncoding(padding_char)),
        result,
      )
    }
  }
}

test "decode with StdEncoding" {
  let tests = [
    ('=', "", Ok(b"")),
    (
      '=',
      "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567",
      Ok(
        b"\x00\x44\x32\x14\xc7\x42\x54\xb6\x35\xcf\x84\x65\x3a\x56\xd7\xc6\x75\xbe\x77\xdf",
      ),
    ),
    ('=', "DEADBEEF22======", Ok(b"\x19\x00\x30\x90\x85\xd6")),
    ('+', "DEADBEEF4444++++", Ok(b"\x19\x00\x30\x90\x85\xe7\x39")),
    ('-', "DEADBEEF55555---", Ok(b"\x19\x00\x30\x90\x85\xef\x7b\xde")),
    (
      @base32.no_padding,
      "DEADBEEF7777777",
      Ok(b"\x19\x00\x30\x90\x85\xff\xff\xff\xff"),
    ),
    (
      '=',
      "1",
      Err(@base32.InvalidBase32CharError('1', "invalid base32 character")),
    ),
  ]
  for t in tests {
    let (padding_char, input, result) = t
    if padding_char == @base32.std_padding {
      assert_eq!(@base32.decode?(input), result)
    } else {
      assert_eq!(
        @base32.decode?(input, encoding=@base32.StdEncoding(padding_char)),
        result,
      )
    }
  }
}

test "general Encoding" {
  let tests = [
    (
      @base32.Encoding("i am not a 32-characters string", '='),
      "",
      Err(
        @base32.Base32EncodingError(
          "encoding alphabet is not 32-characters long",
        ),
      ),
    ),
    (
      @base32.Encoding("i'm a 32-characters string but \r", '='),
      "",
      Err(
        @base32.InvalidBase32CharError(
          '\r', "encoding alphabet contains newline character",
        ),
      ),
    ),
    (
      @base32.Encoding("i am a 32-characters long string", '='),
      "",
      Err(
        @base32.Base32EncodingError(
          "encoding alphabet includes duplicate characters",
        ),
      ),
    ),
    (
      @base32.Encoding("0123456789ABCDEFGHIJKLMNOPQRSTUV", '\n'),
      "",
      Err(@base32.InvalidPaddingCharError('\n', "invalid padding character")),
    ),
    (
      @base32.Encoding("0123456789ABCDEFGHIJKLMNOPQRSTUV", '0'),
      "",
      Err(
        @base32.InvalidPaddingCharError(
          '0', "padding character contained in encoding alphabet",
        ),
      ),
    ),
    (
      @base32.Encoding("0123456789ABCDEFGHIJKLMNOPQRSTUV", '='),
      "0123456789ABCDEFGHIJKLMNOPQRSTUV",
      Ok(
        b"\x00\x44\x32\x14\xc7\x42\x54\xb6\x35\xcf\x84\x65\x3a\x56\xd7\xc6\x75\xbe\x77\xdf",
      ),
    ),
    (
      @base32.Encoding(
        "一二三四五六七八九十甲乙丙丁戊己庚辛壬癸子丑寅卯辰巳午未申酉戌亥",
        '=',
      ),
      "甲乙丙丁一二三四",
      Ok(b"\x52\xd8\xd0\x04\x43"),
    ),
  ]
  for t in tests {
    let (encoding, input, result) = t
    assert_eq!(@base32.decode?(input, ~encoding), result)
  }
}
