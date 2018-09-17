
use "ponytest"
use ".."

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  fun tag tests(test: PonyTest) =>
    // test(_TestBitsChunkBits)
    // test(_TestBitsMaxLevel)
    // test(_TestBitsMask)
    test(_TestHashMapLookupEmpty)
    test(_TestHashMapLookupSingleExisting)
    test(_TestHashMapLookupSingleNonexistent)
    test(_TestHashMapInsertMultiple)
    test(_TestHashMapRemoveMultiple)
