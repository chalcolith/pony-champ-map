primitive Bits
  fun chunk_bits(width: USize = USize(0).bitwidth()): USize =>
    match width
    | 64 => 6
    | 32 => 5
    | 128 => 7
    else
      var result: USize = 1
      while (1 << result) < width do
        result = result + 1
      end
      result
    end

  fun max_level(): USize =>
    USize(0).bitwidth() / chunk_bits()

  // fun set(n: USize, b: USize): USize =>
  //   n or (USize(1) << b)

  // fun clear(n: USize, b: USize): USize =>
  //   n and (not (USize(1) << b))

  fun mask(hash: USize, level: USize): USize =>
    let chunk = chunk_bits()
    (hash >> (level * chunk)) and ((1 << chunk) - 1)

  fun bitpos(hash: USize, level: USize): USize =>
    USize(1) << Bits.mask(hash, level)

  fun index(bitmap: USize, bit: USize): USize =>
    (bitmap and (bit - 1)).popcount()
