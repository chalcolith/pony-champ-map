
use col = "collections"

primitive Bits
  fun chunk_bits(): USize ? =>
    match USize(0).bitwidth()
    | 32 => 5
    | 64 => 6
    else error
    end

  fun max_level(): USize ? =>
    USize(0).bitwidth() / chunk_bits()?

  fun mask(hash: USize, level: USize): USize ? =>
    let chunk = chunk_bits()?
    (hash >> (level * chunk)) and ((1 << chunk) - 1)

  fun bitpos(hash: USize, level: USize): USize ? =>
    USize(1) << Bits.mask(hash, level)?

  fun index(bitmap: USize, bit: USize): USize =>
    (bitmap and (bit - 1)).popcount()

type _MapLeaf[K: Any #share, V: Any #share, H: col.HashFunction[K] val]
  is (K, V)

type _MapBucket[K: Any #share, V: Any #share, H: col.HashFunction[K] val]
  is Array[_MapLeaf[K, V, H]] val

type _MapEntry[K: Any #share, V: Any #share, H: col.HashFunction[K] val]
  is (_MapNode[K, V, H] | _MapBucket[K, V, H] | _MapLeaf[K, V, H])

class val _MapNode[K: Any #share, V: Any #share, H: col.HashFunction[K] val]
  let _entries: Array[_MapEntry[K, V, H]] val
  let _bitmap: USize

  new val empty() =>
    _entries = recover val Array[_MapEntry[K, V, H]](0) end
    _bitmap = 0

  new val create(entries: Array[_MapEntry[K, V, H]] val, bitmap: USize) =>
    _entries = entries
    _bitmap = bitmap

  fun val apply(key: K, hash: USize, level: USize): V ? =>
    let bit = Bits.bitpos(hash, level)?
    let idx = Bits.index(_bitmap, bit)
    match _entries(idx)?
    | (_, let v: V) =>
      v
    | let bucket: _MapBucket[K, V, H] =>
      for entry in bucket.values() do
        if H.eq(entry._1, key) then
          return entry._2
        end
      end
      error
    | let node: _MapNode[K, V, H] =>
      node(key, hash, level + 1)?
    end
