
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

  fun val entries_size(): USize =>
    _entries.size()

  fun val entries_entry(i: USize): _MapEntry[K, V, H] ? =>
    _entries(i)?

  fun val apply(key: K, hash: USize, level: USize): V ? =>
    let bit = _Bits.bitpos(hash, level)
    let idx = _Bits.index(_bitmap, bit)
    match _entries(idx)?
    | let node: _MapNode[K, V, H] =>
      node(key, hash, level +~ 1)?
    | (let k: K, let v: V) =>
      if H.eq(k, key) then
        v
      else
        error
      end
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
    let bit = _Bits.bitpos(hash, level)
    let idx = _Bits.index(_bitmap, bit)
    if idx < _entries.size() then
      // there is already an entry at the index in our array
      match _entries(idx)?
      | let node: _MapNode[K, V, H] =>
        // entry is a node, update it recursively
        (let new_node, let inserted) = node.update(key, hash, value,
          level +~ 1)?
        let new_entries = recover iso _entries.clone() end
        new_entries.update(idx, new_node)?
        (_MapNode[K, V, H](consume new_entries, _bitmap), inserted)
      | (let existing_key: K, let existing_value: V) =>
        // entry is a value
        if H.eq(key, existing_key) then
          // it's the same key, replace it
          let new_entries = recover iso _entries.clone() end
          new_entries.update(idx, (key, value))?
          (_MapNode[K, V, H](consume new_entries, _bitmap), false)
        elseif level == _Bits.max_level() then
          // we don't have any hash left, make a new bucket
          let new_entries = recover iso _entries.clone() end
          new_entries.update(idx,
            [ (existing_key, existing_value); (key, value) ])?
          (_MapNode[K, V, H](consume new_entries, _bitmap), true)
        else
          // make a new node with the original value and ours
          let existing_hash = H.hash(existing_key)
          let sub_bit0 = _Bits.bitpos(existing_hash, level +~ 1)
          let sub_bit1 = _Bits.bitpos(hash, level +~ 1)
          let sub_node =
            if sub_bit0 < sub_bit1 then
              let sub_entries: Array[_MapEntry[K, V, H]] iso =
                recover iso
                  [ (existing_key, existing_value) ; (key, value) ]
                end
              _MapNode[K, V, H](consume sub_entries, sub_bit0 or sub_bit1)
            elseif sub_bit0 > sub_bit1 then
              let sub_entries: Array[_MapEntry[K, V, H]] iso =
                recover iso
                  [ (key, value) ; (existing_key, existing_value) ]
                end
              _MapNode[K, V, H](consume sub_entries, sub_bit0 or sub_bit1)
            else
              // hash collision at this level; combine lower
              var sn = _MapNode[K, V, H]([(existing_key, existing_value)],
                sub_bit0)
              (sn, _) = sn.update(key, hash, value, level +~ 1)?
              sn
            end
          let new_entries = recover iso _entries.clone() end
          new_entries.update(idx, sub_node)?
          (_MapNode[K, V, H](consume new_entries, _bitmap), true)
        end
      | let bucket: _MapBucket[K, V, H] =>
        // entry is a bucket; add our value to it
        let new_entries = recover iso _entries.clone() end
        var inserted = true
        let new_bucket =
          recover val
            let nb = bucket.clone()
            for (i, (k, _)) in nb.pairs() do
              if H.eq(key, k) then
                nb(i)? = (key, value)
                inserted = false
                break
              end
            end
            if inserted then
              nb.push((key, value))
            end
            nb
          end
        new_entries.update(idx, new_bucket)?
        (_MapNode[K, V, H](consume new_entries, _bitmap), inserted)
      end
    else
      // there is no entry in our array; add one
      let new_entries =
        recover iso
          let es = _entries.clone()
          es.push((key, value))
          es
        end
      (_MapNode[K, V, H](consume new_entries, _bitmap or bit), true)
    end

  fun val remove(key: K, hash: USize, level: USize)
    : (_MapNode[K, V, H] | _MapLeaf[K, V, H] | _NodeRemoved) ?
  =>
    let bit = _Bits.bitpos(hash, level)
    let idx = _Bits.index(_bitmap, bit)
    match _entries(idx)?
    | (let k: K, let v: V) =>
      // hash matches a leaf, remove it
      if not H.eq(k, key) then
        error
      end
      _remove_entry(idx, level)?
    | let node: _MapNode[K, V, H] =>
      match node.remove(key, hash, level +~ 1)?
      | _NodeRemoved =>
        // node pointed to a single entry; just remove it
        _remove_entry(idx, level)?
      | let entry: _MapEntry[K, V, H] =>
        // replace entry
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
      if (level > 0) and (bs.size() < 2) then
        if bs.size() == 0 then
          // bucket is now empty
          _remove_entry(idx, level)?
        else
          // promote remaining value to leaf
          let es = recover _entries.clone() end
          es(idx)? = bs(0)?
          _MapNode[K, V, H](consume es, _bitmap)
        end
      else
        // remove entry from the bucket
        let es = recover _entries.clone() end
        es(idx)? = bs
        _MapNode[K, V, H](consume es, _bitmap)
      end
    end

  fun val _remove_entry(idx: USize, level: USize)
    : (_MapNode[K, V, H] | _MapLeaf[K, V, H] | _NodeRemoved) ?
  =>
    if (level > 0) and (_entries.size() <= 2) then
      if _entries.size() == 1 then
        _NodeRemoved
      else
        let entry = _entries(1 - idx)?
        match entry
        | let leaf: _MapLeaf[K, V, H] =>
          leaf
        else
          _MapNode[K, V, H]([entry], _remove_bit(idx))
        end
      end
    else
      let es = recover _entries.clone() end
      es.delete(idx)?
      _MapNode[K, V, H](consume es, _remove_bit(idx))
    end

  fun val _remove_bit(idx: USize): USize =>
    var found: USize = 0
    for i in col.Range(0, USize(0).bitwidth()) do
      let bit = USize(1) << i
      if (bit and _bitmap) != 0 then
        if found == idx then
          return _bitmap and (not bit)
        end
        found = found + 1
      end
    end
    _bitmap

  fun val debug(str: String iso, level: USize,
    pk: {(K, String iso): String iso^}, pv: {(V, String iso): String iso^})
    : String iso^
  =>
    var str': String iso = consume str
    for _ in col.Range(0, level) do str'.append("  ") end
    str'.append("{ " + level.string() + " < ")
    for bit in col.Range(0, USize(0).bitwidth()) do
      if ((USize(1) << bit) and _bitmap) != 0 then
        str'.append(bit.string())
        str'.append(" ")
      end
    end
    str'.append(">\n")

    var i: USize = 0
    for entry in _entries.values() do
      if i > 0 then
        str'.append(",\n")
      end
      match entry
      | (let k: K, let v: V) =>
        for _ in col.Range(0, level+1) do str'.append("  ") end
        str'.append("(")
        str' = pk(k, consume str')
        str'.append(", ")
        str' = pv(v, consume str')
        str'.append(")")
      | let node: _MapNode[K, V, H] =>
        str' = node.debug(consume str', level+1, pk, pv)
      | let bucket: _MapBucket[K, V, H] =>
        for _ in col.Range(0, level+1) do str'.append("  ") end
        str'.append("[")
        var j: USize = 0
        for value in bucket.values() do
          if j > 0 then
            str'.append(", ")
          end
          str'.append("(")
          str' = pk(value._1, consume str')
          str'.append(", ")
          str' = pv(value._2, consume str')
          str'.append(")")
          j = j + 1
        end
        str'.append("]")
      end
      i = i + 1
    end
    str'.append("\n")
    for _ in col.Range(0, level) do str'.append("  ") end
    str'.append("}")
    consume str'

primitive _NodeRemoved
