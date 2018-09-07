
use col = "collections"

type Map[K: (col.Hashable val & Equatable[K]), V: Any #share] is
  HashMap[K, V, col.HashEq[K]]
  """
  A map that uses structural equality to compare keys.
  """

type MapIs[K: Any #share, V: Any #share] is HashMap[K, V, col.HashIs[K]]
  """
  A map that uses identity to compare keys.
  """

class val HashMap[K: Any #share, V: Any #share, H: col.HashFunction[K] val]
  let _root: _MapNode[K, V, H]
  let _size: USize

  new val create() =>
    _root = _MapNode[K, V, H].empty()
    _size = 0

  fun val apply(k: K): val->V ? =>
    _root(k, H.hash(k), 0)?

  fun val try_get(k: K): (val->V | None) =>
    try
      _root(k, H.hash(k), 0)?
    else
      None
    end
