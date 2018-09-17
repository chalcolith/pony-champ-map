
// use "ponytest"
// use ".."

// class iso _TestBitsChunkBits is UnitTest
//   fun name(): String => "bits/chunk_bits"

//   fun apply(h: TestHelper)  =>
//     h.assert_eq[USize](3, Bits.chunk_bits(8))
//     h.assert_eq[USize](4, Bits.chunk_bits(16))
//     h.assert_eq[USize](5, Bits.chunk_bits(32))
//     h.assert_eq[USize](6, Bits.chunk_bits(64))
//     h.assert_eq[USize](7, Bits.chunk_bits(128))
//     h.assert_eq[USize](8, Bits.chunk_bits(256))

// class iso _TestBitsMaxLevel is UnitTest
//   fun name(): String => "bits/max_level"

//   fun apply(h: TestHelper)  =>
//     if USize(0).bitwidth() == 64 then
//       h.assert_eq[USize](10, Bits.max_level())
//     elseif USize(0).bitwidth() == 32 then
//       h.assert_eq[USize](6, Bits.max_level())
//     else
//       h.fail("Only 32- and 64-bit systems are supported.")
//     end

// class iso _TestBitsMask is UnitTest
//   fun name(): String => "bits/mask"

//   fun apply(h: TestHelper)  =>
//     if USize(0).bitwidth() == 64 then
//       let n: USize = 0b1000_000111_110010_000011_101111_000000_001000_110010_000110_000001_010111
//       h.assert_eq[USize](0b010111, Bits.mask(n, 0))
//       h.assert_eq[USize](0b000001, Bits.mask(n, 1))
//       h.assert_eq[USize](0b000110, Bits.mask(n, 2))
//       h.assert_eq[USize](0b110010, Bits.mask(n, 3))
//       h.assert_eq[USize](0b001000, Bits.mask(n, 4))
//       h.assert_eq[USize](0b000000, Bits.mask(n, 5))
//       h.assert_eq[USize](0b101111, Bits.mask(n, 6))
//       h.assert_eq[USize](0b000011, Bits.mask(n, 7))
//       h.assert_eq[USize](0b110010, Bits.mask(n, 8))
//       h.assert_eq[USize](0b000111, Bits.mask(n, 9))
//       h.assert_eq[USize](0b001000, Bits.mask(n, 10))
//     elseif USize(0).bitwidth() == 32 then
//       let n: USize = 0b00_00101_11000_11111_10110_10000_01011
//       h.assert_eq[USize](0b01011, Bits.mask(n, 0))
//       h.assert_eq[USize](0b10000, Bits.mask(n, 1))
//       h.assert_eq[USize](0b10110, Bits.mask(n, 2))
//       h.assert_eq[USize](0b11111, Bits.mask(n, 3))
//       h.assert_eq[USize](0b11000, Bits.mask(n, 4))
//       h.assert_eq[USize](0b00101, Bits.mask(n, 5))
//       h.assert_eq[USize](0b00000, Bits.mask(n, 6))
//     else
//       h.fail("Only 32- and 64-bit systems are supported.")
//     end
