let tests : Array[(Bytes, String)] = [
  (b"", ""),
  (b"\x01\x23\x45\x67\x89\xab\xcd\xef", "0123456789abcdef"),
]

test "encode" {
  for t in tests {
    let (bytes, str) = t
    assert_eq!(@hex.encode(bytes), str)
  }
}

test "decode" {
  for t in tests {
    let (bytes, str) = t
    assert_eq!(@hex.decode!(str), bytes)
  }
  for
    t in [
      ("bee", Err(@hex.OddLengthHexStringError)),
      ("-1", Err(@hex.InvalidHexCharError('-'))),
      ("中文", Err(@hex.InvalidHexCharError('中'))),
    ] {
    let (str, result) = t
    assert_eq!(@hex.decode?(str), result)
  }
}
