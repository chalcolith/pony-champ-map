
use col = "collections"

type Set[T: (col.Hashable val & Equatable[T])] is HashSet[T, col.HashEq[T]]

type SetIs[T: Any #share] is HashSet[T, col.HashIs[T]]

class val HashSet[T: Any #share, H: col.HashFunction[T] val]
  is Comparable[HashSet[T, H] box]

  let _map: HashMap[T, Bool, H]

  new val create() =>
    _map = HashMap[T, Bool, H]

  new val _create(map: HashMap[T, Bool, H]) =>
    _map = map

  fun size(): USize =>
    _map.size()

  fun apply(value: val->T): val->T ? =>
    if _map(value)? == true then
      value
    else
      error
    end

  fun contains(value: val->T): Bool =>
    _map.contains(value)

  fun val add(value: val->T): HashSet[T, H] =>
    try
      _create(_map.update(value, true)?)
    else
      this
    end

  fun val sub(value: val->T): HashSet[T, H] =>
    try
      _create(_map.remove(value)?)
    else
      this
    end

  fun val op_or(that: (HashSet[T, H] | Iterator[T])): HashSet[T, H] =>
    let i =
      match that
      | let hs: HashSet[T, H] => hs.values()
      | let i': Iterator[T] => i'
      end
    var result = this
    for value in i do
      result = result.add(value)
    end
    result

  fun val op_and(that: (HashSet[T, H] | Iterator[T])): HashSet[T, H] =>
    let i =
      match that
      | let hs: HashSet[T, H] => hs.values()
      | let i': Iterator[T] => i'
      end
    var result = create()
    for value in i do
      if this.contains(value) then
        result = result.add(value)
      end
    end
    result

  fun val op_xor(that: (HashSet[T, H] | Iterator[T])): HashSet[T, H] =>
    let i =
      match that
      | let hs: HashSet[T, H] => hs.values()
      | let i': Iterator[T] => i'
      end
    var result = this
    for value in i do
      if this.contains(value) then
        result = result.sub(value)
      else
        result = result.add(value)
      end
    end
    result

  fun val without(that: (HashSet[T, H] | Iterator[T])): HashSet[T, H] =>
    let i =
      match that
      | let hs: HashSet[T, H] => hs.values()
      | let i': Iterator[T] => i'
      end
    var result = this
    for value in i do
      if this.contains(value) then
        result = result.sub(value)
      end
    end
    result

  fun eq(that: HashSet[T, H] box): Bool =>
    (this.size() == that.size()) and (this <= that)

  fun lt(that: HashSet[T, H] box): Bool =>
    (this.size() < that.size()) and (this <= that)

  fun le(that: HashSet[T, H] box): Bool =>
    for value in this.values() do
      if not that.contains(value) then
        return false
      end
    end
    true

  fun gt(that: HashSet[T, H] box): Bool =>
    (this.size() > that.size()) and (that <= this)

  fun ge(that: HashSet[T, H] box): Bool =>
    that <= this

  fun values(): Iterator[T]^ =>
    _map.keys()
