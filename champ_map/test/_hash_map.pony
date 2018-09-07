
use "ponytest"
use ".."

class iso _TestHashMapEmpty is UnitTest
  fun name(): String => "hash_map/empty"

  fun apply(h: TestHelper) =>
    let map = Map[USize, USize]
    try
      let v = map(123)?
      h.fail("map lookup succeeded on an empty map")
    else
      h.complete(true)
    end
