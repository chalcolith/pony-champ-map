
use col = "collections"

class MapPairs[K: Any #share, V: Any #share, H: col.HashFunction[K] val]
  embed _stack: Array[(_MapNode[K, V, H], USize, USize)] = _stack.create()
  let _size: USize
  var _map_index: USize

  new create(root: _MapNode[K, V, H], size: USize) =>
    _stack.push((root, 0, USize.max_value()))
    _size = size
    _map_index = 0

  fun has_next(): Bool =>
    _map_index < _size

  fun ref next(): (K, val->V) ? =>
    while true do
      var node: _MapNode[K, V, H]
      var node_index: USize
      var bucket_index: USize

      // get the current node and index
      (node, node_index, bucket_index) = _stack(_stack.size() - 1)?

      // if we are at the end of the array, go back up
      while (node_index == node.entries_size()) do
        _stack.pop()?
        (node, node_index, bucket_index) = _stack(_stack.size() - 1)?
      end

      match node.entries_entry(node_index)?
      | let leaf: _MapLeaf[K, V, H] =>
        // we are at a leaf; increment our state and return the leaf
        _map_index = _map_index + 1
        _stack(_stack.size() - 1)? = (node, node_index + 1, bucket_index)
        return leaf
      | let entry: _MapNode[K, V, H] =>
        // we are at an entry; push it and loop
        _stack(_stack.size() - 1)? = (node, node_index + 1, bucket_index)
        _stack.push((entry, 0, USize.max_value()))
      | let bucket: _MapBucket[K, V, H] =>
        // we are at a bucket
        if bucket_index == USize.max_value() then
          bucket_index = 0
        end
        if bucket_index < bucket.size() then
          _map_index = _map_index + 1
          _stack(_stack.size() - 1)? = (node, node_index, bucket_index + 1)
          return bucket(bucket_index)?
        else
          _stack(_stack.size() - 1)? = (node, node_index + 1, USize.max_value())
        end
      end
    end
    error

class MapKeys[K: Any #share, V: Any #share, H: col.HashFunction[K] val]
  embed _pairs: MapPairs[K, V, H]

  new create(root: _MapNode[K, V, H], size: USize) =>
    _pairs = MapPairs[K, V, H](root, size)

  fun has_next(): Bool =>
    _pairs.has_next()

  fun ref next(): K ? =>
    _pairs.next()?._1

class MapValues[K: Any #share, V: Any #share, H: col.HashFunction[K] val]
  embed _pairs: MapPairs[K, V, H]

  new create(root: _MapNode[K, V, H], size: USize) =>
    _pairs = MapPairs[K, V, H](root, size)

  fun has_next(): Bool =>
    _pairs.has_next()

  fun ref next(): val->V ? =>
    _pairs.next()?._2
