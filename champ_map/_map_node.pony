
use col = "collections"

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
    let msk = Bits.mask(hash, level)
    let bit = Bits.bitpos(hash, level)
    let idx = Bits.index(_bitmap, bit)
    match _entries(idx)?
    | (let k: K, let v: V) =>
      if H.eq(k, key) then
        v
      else
        error
      end
    | let node: _MapNode[K, V, H] =>
      node(key, hash, level + 1)?
    | let bucket: _MapBucket[K, V, H] =>
      for entry in bucket.values() do
        if H.eq(entry._1, key) then
          return entry._2
        end
      end
      error
    end

  fun val update(key: K, hash: USize, value: V, level: USize)
    : (_MapNode[K, V, H], Bool) ?
  =>
    let msk = Bits.mask(hash, level)
    let bit = Bits.bitpos(hash, level)
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
        elseif level == Bits.max_level() then
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
          let existing_bit = Bits.bitpos(existing_hash, level + 1)
          let new_bit = Bits.bitpos(hash, level + 1)

          var sub_bitmap = existing_bit or new_bit

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
      | let node: _MapNode[K, V, H] =>
        // entry is a node, update it recursively
        (let new_node, let inserted) = node.update(key, hash, value, level + 1)?
        let new_entries = recover iso _entries.clone() end
        new_entries.update(idx, new_node)?
        (_MapNode[K, V, H](consume new_entries, _bitmap), inserted)
      | let bucket: _MapBucket[K, V, H] =>
        // entry is a bucket; add our value to it
        let new_bucket =
          recover val
            let nb = bucket.clone()
            nb.push((key, value))
            nb
          end
        let new_entries = recover iso _entries.clone() end
        new_entries.update(idx, new_bucket)?
        (_MapNode[K, V, H](consume new_entries, _bitmap), true)
      end
    else
      // there is no entry in our array; add one
      let new_bitmap = _bitmap or bit
      let new_idx = Bits.index(new_bitmap, bit)
      let new_entries =
        recover iso
          let es = Array[_MapEntry[K, V, H]](_entries.size() + 1)
          _entries.copy_to(es, 0, 0, _entries.size())
          es.insert(new_idx, (key, value))?
          es
        end
      (_MapNode[K, V, H](consume new_entries, new_bitmap), true)
    end

  fun val remove(key: K, hash: USize, level: USize)
    : (_MapNode[K, V, H] | _MapLeaf[K, V, H] | DoNotHoist) ?
  =>
    let msk = Bits.mask(hash, level)
    let bit = Bits.bitpos(hash, level)
    let idx = Bits.index(_bitmap, bit)
    match _entries(idx)?
    | (let k: K, let v: V) =>
      if not H.eq(k, key) then
        error
      end

      if (level == 0) or (_entries.size() >= 2) then
        // return a node minus the entry
        let es = recover _entries.clone() end
        es.delete(idx)?
        _MapNode[K, V, H](consume es, _bitmap and (not bit))
      elseif _entries.size() == 2 then
        // get rid of this node and hoist the remaining entry
        return _entries(1 - idx)? as (_MapNode[K, V, H] | _MapLeaf[K, V, H])
      else
        // get rid of this node and remove its entry in the node above
        DoNotHoist
      end
    | let node: _MapNode[K, V, H] =>
      match node.remove(key, hash, level + 1)?
      | DoNotHoist =>
        // node pointed to a single entry; just remove it
        if (level == 0) or (_entries.size() >= 2) then
          let es = recover _entries.clone() end
          es.delete(idx)?
          _MapNode[K, V, H](consume es, _bitmap and (not bit))
        else
          DoNotHoist
        end
      | let entry: _MapEntry[K, V, H] =>
        // replace the node
        let es = recover _entries.clone() end
        es(idx)? = entry
        _MapNode[K, V, H](consume es, _bitmap)
      end
    | let bucket: _MapBucket[K, V, H] =>
      // remove us from the bucket
      let bs =
        recover val
          let bs' = _MapBucket[K, V, H](bucket.size())
          for entry in bucket.values() do
            if not H.eq(entry._1, key) then
              bs'.push(entry)
            end
          end
          bs'
        end
      if bs.size() == bucket.size() then
        // we didn't find our entry
        error
      end

      if bs.size() == 0 then
        // remove this node from the node above
        DoNotHoist
      else
        // remove from the bucket
        let es = recover _entries.clone() end
        es(idx)? = bs
        _MapNode[K, V, H](consume es, _bitmap)
      end
    end

primitive DoNotHoist
