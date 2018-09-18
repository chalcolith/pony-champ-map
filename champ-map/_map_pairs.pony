
use col = "collections"

class MapPairs[K: Any #share, V: Any #share, H: col.HashFunction[K] val]
  embed _stack: Array[(_MapNode[K, V, H], USize)] = _stack.create()
  let _size: USize
  let _index: USize

  new create(root: _MapNode[K, V, H], size: USize) =>
    _stack.push((root, 0))
    _size = size
    _index = 0

  fun has_next(): Bool =>
    _index < _size

  fun ref next(): (K, val->V) ? =>
    (let node, let i) = _stack(_stack.size() - 1)?
    while i == node.entries_size() do
