
// cls && make && make test
// && stable env ponyc -o build\release champ-map\bench
// && build\release\bench.exe --ponynoyield --noadjust

use "ponybench"
use "random"

use col = "collections"
use pony = "collections/persistent"
use kuli = ".."

actor Main is BenchmarkList
  new create(env: Env) =>
    PonyBench(env, this)

  fun tag benchmarks(bench: PonyBench) =>
    bench(_KuliMapEqInsert)
    bench(_PonyMapEqInsert)
    bench(_KuliMapEqRemove)
    bench(_PonyMapEqRemove)
    bench(_KuliMapEqRetrieve)
    bench(_PonyMapEqRetrieve)
    bench(_KuliMapEqIterate)
    bench(_PonyMapEqIterate)

class iso _KuliMapEqInsert is MicroBenchmark
  let _n: USize
  let _a: Array[USize]
  var _m: kuli.Map[USize, _TestValue]
  var _i: USize

  new iso create(n: USize = 100_000) =>
    _n = n
    _a = try _Shuffle.get_array(Rand, _n)? else Array[USize] end
    _m = kuli.Map[USize, _TestValue]
    _i = 0

  fun name(): String => "kuli/map/eq/insert"

  fun ref apply() ? =>
    let k = _a(_i % _a.size())?
    _m = _m.update(k, _TestValue(k))?
    _i = _i + 1

class iso _PonyMapEqInsert is MicroBenchmark
  let _n: USize
  let _a: Array[USize]
  var _m: pony.Map[USize, _TestValue]
  var _i: USize

  new iso create(n: USize = 100_000) =>
    _n = n
    _a = try _Shuffle.get_array(Rand, _n)? else Array[USize] end
    _m = pony.Map[USize, _TestValue]
    _i = 0

  fun name(): String => "pony/map/eq/insert"

  fun ref apply() ? =>
    let k = _a(_i % _a.size())?
    _m = _m.update(k, _TestValue(k))
    _i = _i + 1

class iso _KuliMapEqRetrieve is MicroBenchmark
  let _n: USize
  let _a: Array[USize]
  let _b: Array[USize]
  var _m: kuli.Map[USize, _TestValue]
  var _i: USize

  new iso create(n: USize = 100_000) =>
    _n = n
    let r = Rand
    _a = try _Shuffle.get_array(r, _n)? else Array[USize] end
    _b = try _Shuffle.get_array(r, _n)? else Array[USize] end
    _m = kuli.Map[USize, _TestValue]
    try
      for k in _a.values() do
        _m = _m.update(k, _TestValue(k))?
      end
    end
    _i = 0

  fun name(): String => "kuli/map/eq/retrieve"

  fun ref apply() =>
    try
      let k = _b(_i % _b.size())?
      DoNotOptimise[_TestValue](_m(k)?)
    end
    _i = _i + 1

class iso _PonyMapEqRetrieve is MicroBenchmark
  let _n: USize
  let _a: Array[USize]
  let _b: Array[USize]
  var _m: pony.Map[USize, _TestValue]
  var _i: USize

  new iso create(n: USize = 100_000) =>
    _n = n
    let r = Rand
    _a = try _Shuffle.get_array(r, _n)? else Array[USize] end
    _b = try _Shuffle.get_array(r, _n)? else Array[USize] end
    _m = pony.Map[USize, _TestValue]
    for k in _a.values() do
      _m = _m.update(k, _TestValue(k))
    end
    _i = 0

  fun name(): String => "pony/map/eq/retrieve"

  fun ref apply() =>
    try
      let k = _b(_i % _b.size())?
      DoNotOptimise[_TestValue](_m(k)?)
    end
    _i = _i + 1

class iso _KuliMapEqRemove is MicroBenchmark
  let _n: USize
  let _a: Array[USize]
  let _b: Array[USize]
  var _m: kuli.Map[USize, _TestValue]
  var _i: USize

  new iso create(n: USize = 100_000) =>
    _n = n
    let r = Rand
    _a = try _Shuffle.get_array(r, _n)? else Array[USize] end
    _b = try _Shuffle.get_array(r, _n)? else Array[USize] end
    _m = kuli.Map[USize, _TestValue]
    try
      for k in _a.values() do
        _m = _m.update(k, _TestValue(k))?
      end
    end
    _i = 0

  fun name(): String => "kuli/map/eq/remove"

  fun ref apply() =>
    try
      let k = _b(_i % _b.size())?
      _m = _m.remove(k)?
    end
    _i = _i + 1

class iso _PonyMapEqRemove is MicroBenchmark
  let _n: USize
  let _a: Array[USize]
  let _b: Array[USize]
  var _m: pony.Map[USize, _TestValue]
  var _i: USize

  new iso create(n: USize = 100_000) =>
    _n = n
    let r = Rand
    _a = try _Shuffle.get_array(r, _n)? else Array[USize] end
    _b = try _Shuffle.get_array(r, _n)? else Array[USize] end
    _m = pony.Map[USize, _TestValue]
    for k in _a.values() do
      _m = _m.update(k, _TestValue(k))
    end
    _i = 0

  fun name(): String => "pony/map/eq/remove"

  fun ref apply() =>
    try
      let k = _b(_i % _b.size())?
      _m = _m.remove(k)?
    end
    _i = _i + 1

class iso _KuliMapEqIterate is MicroBenchmark
  let _n: USize
  let _a: Array[USize]
  let _m: kuli.Map[USize, _TestValue]
  let _i: Iterator[(USize, _TestValue)]

  new iso create(n: USize = 100_000) =>
    _n = n
    _a = try _Shuffle.get_array(Rand, _n)? else Array[USize] end
    var m = kuli.Map[USize, _TestValue]
    try
      for k in _a.values() do
        m = m.update(k, _TestValue(k))?
      end
    end
    _m = m
    _i = m.pairs()

  fun name(): String => "kuli/map/eq/iterate"

  fun ref apply() =>
    if _i.has_next() then
      try
        DoNotOptimise[(USize, _TestValue)](_i.next()?)
      end
    end

class iso _PonyMapEqIterate is MicroBenchmark
  let _n: USize
  let _a: Array[USize]
  let _m: pony.Map[USize, _TestValue]
  let _i: Iterator[(USize, _TestValue)]

  new iso create(n: USize = 100_000) =>
    _n = n
    _a = try _Shuffle.get_array(Rand, _n)? else Array[USize] end
    var m = pony.Map[USize, _TestValue]
    for k in _a.values() do
      m = m.update(k, _TestValue(k))
    end
    _m = m
    _i = m.pairs()

  fun name(): String => "pony/map/eq/iterate"

  fun ref apply() =>
    if _i.has_next() then
      try
        DoNotOptimise[(USize, _TestValue)](_i.next()?)
      end
    end

class val _TestValue
  let n: USize
  let s: String

  new val create(n': USize) =>
    n = n'
    s = n'.string()

  fun box eq(that: box->_TestValue): Bool =>
    (n == that.n) and (s == that.s)

  fun box ne(that: box->_TestValue): Bool =>
    (n != that.n) or (s != that.s)

  fun string(): String iso^ =>
    n.string()

primitive _Shuffle
  fun get_array(rng: Rand, size: USize): Array[USize] ? =>
    let arr = Array[USize](size)
    for i in col.Range(0, size) do
      arr.push(i)
    end
    for i in col.Range(0, arr.size() - 1) do
      let idx = i + (rng.next().usize() % (arr.size() - i))
      let temp = arr(idx)?
      arr(idx)? = arr(i)?
      arr(i)? = temp
    end
    arr
