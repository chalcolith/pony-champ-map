
use c = "collections"
use "itertools"
use "ponytest"
use "random"
use ".."

class val _TestValue
  let n: USize
  let s: String

  new val create(n': USize) =>
    n = n'
    s = n'.string()

  fun string(): String iso^ =>
    n.string()

class iso _TestHashMapLookupEmpty is UnitTest
  fun name(): String => "hash_map/lookup_empty"

  fun apply(h: TestHelper) =>
    let map = Map[USize, _TestValue]
    h.assert_error({() ? => let v = map(123)? },
      "map lookup succeeded on an empty map")

class iso _TestHashMapLookupSingleExisting is UnitTest
  fun name(): String => "hash_map/lookup_single_existing"

  fun apply(h: TestHelper) ? =>
    var map = Map[USize, _TestValue]
    map = map.update(USize(1234), _TestValue(5678))?
    h.assert_eq[USize](5678, map(USize(1234))?.n)

class iso _TestHashMapLookupSingleNonexistent is UnitTest
  fun name(): String => "hash_map/lookup_single_nonexistent"

  fun apply(h: TestHelper) ? =>
    var map = Map[USize, _TestValue]
    map = map.update(USize(1234), _TestValue(5678))?
    h.assert_error({() ? => let v = map(USize(9876))? },
    "map lookup succeeded on the wrong key")

class iso _TestHashMapInsertMultiple is UnitTest
  fun name(): String => "hash_map/insert_multiple"

  fun apply(h: TestHelper) ? =>
    let num: USize = 10_000
    let rng = Rand
    let arr = Array[(USize,_TestValue)](num)

    let not_in_map = rng.next().usize()
    var map = Map[USize, _TestValue]
    //_Debug.debug(h, map)
    for i in c.Range(0, num) do
      var k = rng.next().usize()
      while k == not_in_map do k = rng.next().usize() end
      let v = _TestValue(rng.next().usize())
      arr.push((k, v))
      //h.log("adding k=" + k.string() + ", v=" + v.n.string())
      map = map.update(k, v)?
      //_Debug.debug(h, map)
    end

    for (k, expected) in arr.values() do
      let actual = map(k)?
      h.assert_eq[USize](expected.n, actual.n)
    end

    var num_found: USize = 0
    for i in c.Range(0, num) do
      try
        let actual = map(not_in_map)?
        num_found = num_found + 1
      end
    end
    h.assert_eq[USize](0, num_found, "found " + num_found.string() +
      " collisions")

class iso _TestHashMapRemoveMultiple is UnitTest
  fun name(): String => "hash_map/remove_multiple"

  fun apply(h: TestHelper) ? =>
    let num: USize = 1000
    let rng = Rand(1234, 5678)

    let keys = _Shuffle.get_array(rng, num)?
    let vals = Array[_TestValue](num)
    var map = Map[USize, _TestValue]
    //_Debug.debug(h, map)
    for k in keys.values() do
      let v = _TestValue(rng.next().usize())
      //h.log("adding k=" + k.string() + ", v=" + v.n.string())
      vals.push(v)
      map = map.update(k, v)?
      //_Debug.debug(h, map)
    end

    var expected_size = map.size()
    let indices_to_delete = _Shuffle.get_array(rng, num)?
    for i in indices_to_delete.values() do
      let k = keys(i)?
      let v = vals(i)?
      //h.log("deleting i=" + i.string() + ", k=" + k.string())
      //_Debug.debug(h, map)

      h.assert_no_error(
        {() ? =>
          let actual = map(k)?
          h.assert_eq[USize](v.n, actual.n)
        },
        "Map did not contain (" + k.string() + ", " + v.s + ") @ " + i.string()
        + " for i=" + i.string() + ", size=" + expected_size.string()
      )

      map = map.remove(k)?
      //_Debug.debug(h, map)

      expected_size = expected_size - 1
      h.assert_eq[USize](expected_size, map.size())
      h.assert_error({() ? =>
        let actual = map(k)?
        let foo = actual
      },
        "Map lookup succeeded after delete for i=" + i.string() + ", size="
        + expected_size.string() + ", k=" + k.string())
    end
    h.assert_eq[USize](0, map.size())

primitive _Shuffle
  fun get_array(rng: Rand, size: USize): Array[USize] ? =>
    let arr = Array[USize](size)
    for i in c.Range(0, size) do
      arr.push(i)
    end
    for i in c.Range(0, arr.size() - 1) do
      let idx = i + (rng.next().usize() % (arr.size() - i))
      let temp = arr(idx)?
      arr(idx)? = arr(i)?
      arr(i)? = temp
    end
    arr

primitive _Debug
  fun debug(h: TestHelper, map: Map[USize, _TestValue]) =>
    var str: String iso = recover String end
    str = map.debug(consume str, _Debug~print[USize](),
      _Debug~print[_TestValue]())
    h.log(str.clone())

  fun print[T: (Stringable & Any val)](t: T, str: String iso): String iso^ =>
    str.append(t.string())
    consume str
