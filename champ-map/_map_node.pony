
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
    let data_idx = _Bits.index(_datamap, bit)
    var lower_data = false
    if (_datamap and bit) != 0 then
      (let k, let v) = _entries(data_idx)? as _MapLeaf[K, V, H]
      if H.eq(k, key) then
        let es = recover iso _entries.clone() end
        es.update(data_idx, (key, value))?
        return (_MapNode[K, V, H](consume es, _datamap, _nodemap), false)
      else
        lower_data = true
      end
    end

    if (_nodemap and bit) != 0 then
      let node_idx = _entries.size() - 1 - _Bits.index(_nodemap, bit)
      if level < _Bits.max_level() then
        let es = recover iso _entries.clone() end
        var node = (_entries(node_idx)? as _MapNode[K, V, H])
        if lower_data then
          (let k, let v) = _entries(data_idx)? as _MapLeaf[K, V, H]
          (node, _) = node.update(k, H.hash(k), v, level +~ 1)?
          (node, let inserted) = node.update(key, hash, value, level +~ 1)?
          es.update(node_idx, node)?
          es.remove(data_idx, 1)
          (_MapNode[K, V, H](consume es, _datamap and (not bit), _nodemap),
            inserted)
        else
          (node, let inserted) = node.update(key, hash, value, level +~ 1)?
          es.update(node_idx, node)?
          (_MapNode[K, V, H](consume es, _datamap, _nodemap), inserted)
        end
      else
        let bs =
          recover val
            let bucket = (_entries(node_idx)? as _MapBucket[K, V, H]).clone()
            var found = false
            for (i, (k, v)) in bucket.pairs() do
              if H.eq(k, key) then
                bucket.update(i, (key, value))?
                found = true
                break
              end
            end
            if not found then
              bucket.push((key, value))
            end
            bucket
          end
        let es = recover iso _entries.clone() end
        es.update(node_idx, bs)?
        (_MapNode[K, V, H](consume es, _datamap, _nodemap), true)
      end
    else
      if level < _Bits.max_level() then
        let es = recover iso _entries.clone() end
        if lower_data then
          (let k, let v) = _entries(data_idx)? as _MapLeaf[K, V, H]
          var node = empty()
          (node, _) = node.update(k, H.hash(k), v, level + 1)?
          (node, let inserted) = node.update(key, hash, value, level + 1)?
          let node_idx = _entries.size() - 1 - _Bits.index(_nodemap, bit)
          es.remove(data_idx, 1)
          es.insert(node_idx, node)?
          (_MapNode[K, V, H](consume es, _datamap and (not bit),
            _nodemap or bit), inserted)
        else
          es.insert(data_idx, (key, value))?
          (_MapNode[K, V, H](consume es, _datamap or bit, _nodemap), true)
        end
      else
        let es = recover iso _entries.clone() end
        es.push([(key, value)])
        (_MapNode[K, V, H](consume es, _datamap, _nodemap or bit), true)
      end
    end

  fun val _remove_remaining_entry(size: USize, idx: USize, level: USize)
    : (_MapNode[K, V, H] | _MapLeaf[K, V, H] | _NodeRemoved) ?
  =>
    if size == 1 then
      _NodeRemoved
    else
      match _entries(1 - idx)?
      | let leaf: _MapLeaf[K, V, H] =>
        leaf
      | let node: _MapNode[K, V, H] =>
        var new_node = empty()
        let iter = MapPairs[K, V, H](node, USize.max_value())
        while true do
          try
            (let k, let v) = iter.next()?
            (new_node, _) = new_node.update(k, H.hash(k), v, level)?
          else
            break
          end
        end
        new_node
      else
        error
      end
    end

  fun val remove(key: K, hash: USize, level: USize)
    : (_MapNode[K, V, H] | _MapLeaf[K, V, H] | _NodeRemoved) ?
  =>
    let bit = _Bits.bitpos(hash, level)
    if (_datamap and bit) != 0 then
      let num_entries = _entries.size()
      let data_idx = _Bits.index(_datamap, bit)
      if (level > 0) and (num_entries <= 2) then
        _remove_remaining_entry(num_entries, data_idx, level)?
      else
        let es = recover iso _entries.clone() end
        es.remove(data_idx, 1)
        _MapNode[K, V, H](consume es, _datamap and (not bit), _nodemap)
      end
    elseif (_nodemap and bit) != 0 then
      let num_entries = _entries.size()
      let node_idx = _entries.size() - 1 - _Bits.index(_nodemap, bit)
      if level < _Bits.max_level() then
        let node = _entries(node_idx)? as _MapNode[K, V, H]
        match node.remove(key, hash, level +~ 1)?
        | let sub_node: _MapNode[K, V, H] =>
          let es = recover iso _entries.clone() end
          es.update(node_idx, sub_node)?
          _MapNode[K, V, H](consume es, _datamap, _nodemap)
        | let leaf: _MapLeaf[K, V, H] =>
          let data_idx = _Bits.index(_datamap, bit)
          let es = recover iso _entries.clone() end
          es.remove(node_idx, 1)
          es.insert(data_idx, leaf)?
          _MapNode[K, V, H](consume es, _datamap or bit, _nodemap and (not bit))
        | _NodeRemoved =>
          if (level > 0) and (num_entries <= 2) then
            _remove_remaining_entry(num_entries, node_idx, level)?
          else
            let es = recover iso _entries.clone() end
            es.remove(node_idx, 1)
            _MapNode[K, V, H](consume es, _datamap, _nodemap and (not bit))
          end
        end
      else
        let bucket = _entries(node_idx)? as _MapBucket[K, V, H]
        if bucket.size() > 1 then
          let bs =
            recover val
              let bs' = _MapBucket[K, V, H](bucket.size())
              for (k, v) in bucket.values() do
                if not H.eq(k, key) then
                  bs'.push((k, v))
                end
              end
              bs'
            end
          if bs.size() == bucket.size() then
            error // we didn't find the leaf
          elseif bs.size() == 1 then
            let data_index = _Bits.index(_datamap, bit)
            let node_index = _entries.size() - 1 - _Bits.index(_nodemap, bit)
            let es = recover iso _entries.clone() end
            es.remove(node_index, 1)
            es.insert(data_index, bs(0)?)?
            _MapNode[K, V, H](consume es, _datamap or bit,
              _nodemap and (not bit))
          else
            let es = recover iso _entries.clone() end
            es.update(node_idx, consume bs)?
            _MapNode[K, V, H](consume es, _datamap, _nodemap)
          end
        else
          if num_entries <= 2 then
            if num_entries == 1 then
              _NodeRemoved
            else
              match _entries(1 - node_idx)?
              | let leaf: _MapLeaf[K, V, H] =>
                leaf
              | let sub_bucket: _MapBucket[K, V, H] =>
                _MapNode[K, V, H]([recover sub_bucket.clone() end], _datamap,
                  _nodemap and (not bit))
              | let node: _MapNode[K, V, H] =>
                error
              end
            end
          else
            let es = recover iso _entries.clone() end
            es.remove(node_idx, 1)
            _MapNode[K, V, H](consume es, _datamap, _nodemap and (not bit))
          end
        end
      end
    else
      error
    end

  fun val debug(str: String iso, level: USize, index: USize, bitpos: USize,
    pk: {(K, String iso): String iso^}, pv: {(V, String iso): String iso^})
    : String iso^ ?
  =>
    var str': String iso = consume str
    for _ in col.Range(0, level) do str'.append("  ") end
    str'.append(index.string() + "@" + bitpos.string() + ": { " + level.string()
      + " < ")
    let bitpositions = Array[USize]
    for bit in col.Range(0, USize(0).bitwidth()) do
      if ((USize(1) << bit) and _datamap) != 0 then
        bitpositions.push(bit)
        str'.append(bit.string())
        str'.append(" ")
      end
    end
    str'.append("; ")
    for bit in col.Range(0, USize(0).bitwidth()) do
      if ((USize(1) << bit) and _nodemap) != 0 then
        bitpositions.push(bit)
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
        str'.append(i.string() + "@" + bitpositions(i)?.string())
        str'.append(": (")
        str' = pk(k, consume str')
        str'.append(", ")
        str' = pv(v, consume str')
        str'.append(")")
      | let node: _MapNode[K, V, H] =>
        str' = node.debug(consume str', level+1, i, bitpositions(i)?, pk, pv)?
      | let bucket: _MapBucket[K, V, H] =>
        for _ in col.Range(0, level+1) do str'.append("  ") end
        str'.append(i.string() + "@" + bitpositions(i)?.string())
        str'.append(": [")
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
