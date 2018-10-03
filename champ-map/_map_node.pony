
use col = "collections"

type _MapLeaf[K: Any #share, V: Any #share, H: col.HashFunction[K] val]
  is (K, V)

type _MapBucket[K: Any #share, V: Any #share, H: col.HashFunction[K] val]
  is Array[_MapLeaf[K, V, H]] val

type _MapEntry[K: Any #share, V: Any #share, H: col.HashFunction[K] val]
  is (_MapNode[K, V, H] | _MapBucket[K, V, H] | _MapLeaf[K, V, H])

class val _MapNode[K: Any #share, V: Any #share, H: col.HashFunction[K] val]
  let _entries: Array[_MapEntry[K, V, H]] iso
  let _datamap: USize
  let _nodemap: USize

  new val empty() =>
    _entries = recover iso Array[_MapEntry[K, V, H]](0) end
    _datamap = 0
    _nodemap = 0

  new val create(entries: Array[_MapEntry[K, V, H]] iso,
    datamap: USize, nodemap: USize)
  =>
    _entries = consume entries
    _datamap = datamap
    _nodemap = nodemap

  fun val entries_size(): USize =>
    _entries.size()

  fun val entries_entry(i: USize): _MapEntry[K, V, H] ? =>
    _entries(i)?

  fun val apply(key: K, hash: USize, level: USize): V ? =>
    let bit = _Bits.bitpos(hash, level)
    if (_datamap and bit) != 0 then
      let data_idx = _Bits.index(_datamap, bit)
      (let k, let v) = _entries(data_idx)? as _MapLeaf[K, V, H]
      if H.eq(k, key) then
        return v
      end
    end

    if (_nodemap and bit) != 0 then
      let node_idx = _entries.size() - 1 - _Bits.index(_nodemap, bit)
      if level < _Bits.max_level() then
        let node = _entries(node_idx)? as _MapNode[K, V, H]
        return node(key, hash, level +~ 1)?
      else
        let bucket = _entries(node_idx)? as _MapBucket[K, V, H]
        for entry in bucket.values() do
          if H.eq(entry._1, key) then
            return entry._2
          end
        end
      end
    end
    error

  fun val update(key: K, hash: USize, value: V, level: USize)
    : (_MapNode[K, V, H], Bool) ?
  =>
    let bit = _Bits.bitpos(hash, level)
    if (_datamap and bit) != 0 then
      let data_idx = _Bits.index(_datamap, bit)
      (let k, let v) = _entries(data_idx)? as _MapLeaf[K, V, H]
      if H.eq(k, key) then
        let es = recover iso _entries.clone() end
        es.update(data_idx, (key, value))?
        return (_MapNode[K, V, H](consume es, _datamap, _nodemap), false)
      end
    end

    if (_nodemap and bit) != 0 then
      let node_idx = _entries.size() - 1 - _Bits.index(_nodemap, bit)
      if level < _Bits.max_level() then
        let es = recover iso _entries.clone() end
        (let node, let inserted) = (_entries(node_idx)? as _MapNode[K, V, H])
          .update(key, hash, value, level + 1)?
        es.update(node_idx, node)?
        (_MapNode[K, V, H](consume es, _datamap, _nodemap), inserted)
      else
        let bs =
          recover val
            let bucket = (_entries(node_idx)? as _MapBucket[K, V, H]).clone()
            bucket.>push((key, value))
          end
        let es = recover iso _entries.clone() end
        es.update(node_idx, bs)?
        (_MapNode[K, V, H](consume es, _datamap, _nodemap), true)
      end
    else
      if level < _Bits.max_level() then
        let data_idx = _Bits.index(_datamap, bit)
        let es = recover iso _entries.clone() end
        es.insert(data_idx, (key, value))?
        (_MapNode[K, V, H](consume es, _datamap or bit, _nodemap), true)
      else
        let es = recover iso _entries.clone() end
        es.push([(key, value)])
        (_MapNode[K, V, H](consume es, _datamap, _nodemap or bit), true)
      end
    end

  fun val remove(key: K, hash: USize, level: USize)
    : (_MapNode[K, V, H] | _MapLeaf[K, V, H] | _NodeRemoved) ?
  =>
    error

  // fun val _remove_old(key: K, hash: USize, level: USize)
  //   : (_MapNode[K, V, H] | _MapLeaf[K, V, H] | _NodeRemoved) ?
  // =>
  //   let bit = _Bits.bitpos(hash, level)
  //   let idx = _Bits.index(_bitmap, bit)
  //   match _entries(idx)?
  //   | (let k: K, let v: V) =>
  //     // hash matches a leaf, remove it
  //     if not H.eq(k, key) then
  //       error
  //     end
  //     _remove_entry(idx, level)?
  //   | let node: _MapNode[K, V, H] =>
  //     match node.remove(key, hash, level +~ 1)?
  //     | _NodeRemoved =>
  //       // node pointed to a single entry; just remove it
  //       _remove_entry(idx, level)?
  //     | let entry: _MapEntry[K, V, H] =>
  //       // replace entry
  //       let es = recover _entries.clone() end
  //       es(idx)? = entry
  //       _MapNode[K, V, H](consume es, _bitmap)
  //     end
  //   | let bucket: _MapBucket[K, V, H] =>
  //     // remove us from the bucket
  //     let bs =
  //       recover val
  //         let bs' = _MapBucket[K, V, H](bucket.size())
  //         for entry in bucket.values() do
  //           if not H.eq(entry._1, key) then
  //             bs'.push(entry)
  //           end
  //         end
  //         bs'
  //       end
  //     if bs.size() == bucket.size() then
  //       // we didn't find our entry
  //       error
  //     end
  //     if (level > 0) and (bs.size() < 2) then
  //       if bs.size() == 0 then
  //         // bucket is now empty
  //         _remove_entry(idx, level)?
  //       else
  //         // promote remaining value to leaf
  //         let es = recover _entries.clone() end
  //         es(idx)? = bs(0)?
  //         _MapNode[K, V, H](consume es, _bitmap)
  //       end
  //     else
  //       // remove entry from the bucket
  //       let es = recover _entries.clone() end
  //       es(idx)? = bs
  //       _MapNode[K, V, H](consume es, _bitmap)
  //     end
  //   end

  // fun val _remove_entry(idx: USize, level: USize)
  //   : (_MapNode[K, V, H] | _MapLeaf[K, V, H] | _NodeRemoved) ?
  // =>
  //   if (level > 0) and (_entries.size() <= 2) then
  //     if _entries.size() == 1 then
  //       _NodeRemoved
  //     else
  //       let entry = _entries(1 - idx)?
  //       match entry
  //       | let leaf: _MapLeaf[K, V, H] =>
  //         leaf
  //       else
  //         _MapNode[K, V, H]([entry], _remove_bit(idx))
  //       end
  //     end
  //   else
  //     let es = recover _entries.clone() end
  //     es.delete(idx)?
  //     _MapNode[K, V, H](consume es, _remove_bit(idx))
  //   end

  // fun val _remove_bit(idx: USize): USize =>
  //   var found: USize = 0
  //   for i in col.Range(0, USize(0).bitwidth()) do
  //     let bit = USize(1) << i
  //     if (bit and _bitmap) != 0 then
  //       if found == idx then
  //         return _bitmap and (not bit)
  //       end
  //       found = found + 1
  //     end
  //   end
  //   _bitmap

  fun val debug(str: String iso, level: USize,
    pk: {(K, String iso): String iso^}, pv: {(V, String iso): String iso^})
    : String iso^
  =>
    var str': String iso = consume str
    for _ in col.Range(0, level) do str'.append("  ") end
    str'.append("{ " + level.string() + " < ")
    for bit in col.Range(0, USize(0).bitwidth()) do
      if ((USize(1) << bit) and _datamap) != 0 then
        str'.append(bit.string())
        str'.append(" ")
      end
    end
    str'.append("; ")
    for bit in col.Range(0, USize(0).bitwidth()) do
      if ((USize(1) << bit) and _nodemap) != 0 then
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
