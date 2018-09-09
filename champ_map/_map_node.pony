
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

  fun set(n: USize, b: USize): USize =>
    n or (USize(1) << b)

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
  let _entries: Array[_MapEntry[K, V, H]] iso
  let _bitmap: USize

  new val empty() =>
    _entries = recover iso Array[_MapEntry[K, V, H]](0) end
    _bitmap = 0

  new val create(entries: Array[_MapEntry[K, V, H]] iso, bitmap: USize) =>
    _entries = consume entries
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

  fun val update(key: K, hash: USize, value: V, level: USize)
    : (_MapNode[K, V, H], Bool) ?
  =>
    let bit = Bits.bitpos(hash, level)?
    let idx = Bits.index(_bitmap, bit)
    if idx < _entries.size() then
      // there is already an entry at the index in our array
      match _entries(idx)?
      | (let existing_key: K, let existing_value: V) =>
        // entry is a value
        if H.eq(key, existing_key) then
          // it's the same key, replace it
          let new_entries = recover iso _entries.clone() end
          new_entries.update(idx, (key, value))?
          (_MapNode[K, V, H](consume new_entries, _bitmap), false)
        elseif level == Bits.max_level()? then
          // we don't have any hash left, make a new bucket
          let new_bucket =
            recover val
              let bb = _MapBucket[K, V, H](2)
              bb.push((existing_key, existing_value))
              bb.>push((key, value))
            end
          let new_entries = recover iso _entries.clone() end
          new_entries.update(idx, new_bucket)?
          (_MapNode[K, V, H](consume new_entries, _bitmap), true)
        else
          // make a new node with the original value and ours
          let existing_hash = H.hash(existing_key)
          let existing_bit = Bits.bitpos(existing_hash, level + 1)?
          let new_bit = Bits.bitpos(hash, level + 1)?
          var sub_bitmap = Bits.set(USize(0), existing_bit)
          sub_bitmap = Bits.set(sub_bitmap, new_bit)

          let existing_idx = Bits.index(sub_bitmap, existing_bit)
          let new_idx = Bits.index(sub_bitmap, new_bit)

          let sub_entries =
            recover iso
              if existing_idx == new_idx then
                [as _MapEntry[K, V, H]:
                  [as _MapLeaf[K, V, H]:
                    (existing_key, existing_value)
                    (key, value)
                  ]
                ]
              elseif existing_idx < new_idx then
                [as _MapEntry[K, V, H]:
                  (existing_key, existing_value)
                  (key, value)
                ]
              else
                [as _MapEntry[K, V, H]:
                  (key, value)
                  (existing_key, existing_value)
                ]
              end
            end
          let sub_node = _MapNode[K, V, H](consume sub_entries, sub_bitmap)

          let new_entries = recover iso _entries.clone() end
          new_entries.update(idx, sub_node)?
          (_MapNode[K, V, H](consume new_entries, _bitmap), true)
        end
      | let bucket: _MapBucket[K, V, H] =>
        // entry is a bucket; add our value to it
        let new_bucket =
          recover val
            let nb = bucket.clone()
            nb.>push((key, value))
          end
        let new_entries = recover iso _entries.clone() end
        new_entries.update(idx, new_bucket)?
        (_MapNode[K, V, H](consume new_entries, _bitmap), true)
      | let node: _MapNode[K, V, H] =>
        // entry is a node, update it recursively
        (let new_node, let inserted) = node.update(key, hash, value, level + 1)?
        let new_entries = recover iso _entries.clone() end
        new_entries.update(idx, new_node)?
        (_MapNode[K, V, H](consume new_entries, _bitmap), inserted)
      end
    else
      // there is no entry in our array; add one
      let new_bitmap = Bits.set(_bitmap, bit)
      let new_idx = Bits.index(new_bitmap, bit)
      let new_entries =
        recover iso
          let es = Array[_MapEntry[K, V, H]](_entries.size() + 1)
          _entries.copy_to(es, 0, 0, _entries.size())
          es.>insert(new_idx, (key, value))?
        end
      (_MapNode[K, V, H](consume new_entries, new_bitmap), true)
    end
