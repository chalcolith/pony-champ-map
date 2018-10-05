
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
    for n in [as USize: 10; 100; 1000; 10_000; 100_000; 1_000_000].values() do
      bench(_KuliMapEqInsert(n))
      bench(_PonyMapEqInsert(n))
      bench(_KuliMapEqUpdate(n))
      bench(_PonyMapEqUpdate(n))
      bench(_KuliMapEqRemove(n))
      bench(_PonyMapEqRemove(n))
      bench(_KuliMapEqRetrieve(n))
      bench(_PonyMapEqRetrieve(n))
      bench(_KuliMapEqIterate(n))
      bench(_PonyMapEqIterate(n))
    end

class iso _KuliMapEqInsert is MicroBenchmark
  let _n: USize
  let _a: Array[USize]
  var _m: kuli.Map[USize, _TestValue]
  var _i: USize

  new iso create(n: USize = 1_000_000) =>
    _n = n
    _a = try _Shuffle.get_array(Rand, _n)? else Array[USize] end
    _m = kuli.Map[USize, _TestValue]
    _i = 0

  fun name(): String => "kuli/map/eq/insert " + _n.string()

  fun ref apply() ? =>
    let k = _a(_i % _a.size())?
    _m = _m.update(k, _TestValue(k))?
    DoNotOptimise[kuli.Map[USize, _TestValue]](_m)
    DoNotOptimise.observe()
    _i = _i + 1

class iso _PonyMapEqInsert is MicroBenchmark
  let _n: USize
  let _a: Array[USize]
  var _m: pony.Map[USize, _TestValue]
  var _i: USize

  new iso create(n: USize = 1_000_000) =>
    _n = n
    _a = try _Shuffle.get_array(Rand, _n)? else Array[USize] end
    _m = pony.Map[USize, _TestValue]
    _i = 0

  fun name(): String => "pony/map/eq/insert " + _n.string()

  fun ref apply() ? =>
    let k = _a(_i % _a.size())?
    _m = _m.update(k, _TestValue(k))
    DoNotOptimise[pony.Map[USize, _TestValue]](_m)
    DoNotOptimise.observe()
    _i = _i + 1

class iso _KuliMapEqUpdate is MicroBenchmark
  let _n: USize
  let _a: Array[USize]
  let _b: Array[USize]
  var _m: kuli.Map[USize, _TestValue]
  var _i: USize

  new iso create(n: USize = 1_000_000) =>
    _n = n
    let r = Rand
    _a = try _Shuffle.get_array(r, _n)? else Array[USize] end
    _b = try _Shuffle.get_array(r, _n)? else Array[USize] end
    _m = kuli.Map[USize, _TestValue]
    for a in _a.values() do
      try
        _m = _m.update(a, _TestValue(a))?
      end
    end
    _i = 0

  fun name(): String => "kuli/map/eq/update " + _n.string()

  fun ref apply() ? =>
    let k = _a(_i % _a.size())?
    _m = _m.update(k, _TestValue(_b(_i % _b.size())?))?
    DoNotOptimise[kuli.Map[USize, _TestValue]](_m)
    DoNotOptimise.observe()
    _i = _i + 1

class iso _PonyMapEqUpdate is MicroBenchmark
  let _n: USize
  let _a: Array[USize]
  let _b: Array[USize]
  var _m: pony.Map[USize, _TestValue]
  var _i: USize

  new iso create(n: USize = 1_000_000) =>
    _n = n
    let r = Rand
    _a = try _Shuffle.get_array(r, _n)? else Array[USize] end
    _b = try _Shuffle.get_array(r, _n)? else Array[USize] end
    _m = pony.Map[USize, _TestValue]
    for a in _a.values() do
      _m = _m.update(a, _TestValue(a))
    end
    _i = 0

  fun name(): String => "pony/map/eq/update " + _n.string()

  fun ref apply() ? =>
    let k = _a(_i % _a.size())?
    _m = _m.update(k, _TestValue(_b(_i % _b.size())?))
    DoNotOptimise[pony.Map[USize, _TestValue]](_m)
    DoNotOptimise.observe()
    _i = _i + 1

class iso _KuliMapEqRetrieve is MicroBenchmark
  let _n: USize
  let _a: Array[USize]
  let _b: Array[USize]
  var _m: kuli.Map[USize, _TestValue]
  var _i: USize

  new iso create(n: USize = 1_000_000) =>
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

  fun name(): String => "kuli/map/eq/retrieve " + _n.string()

  fun ref apply() =>
    try
      let k = _b(_i % _b.size())?
      DoNotOptimise[_TestValue](_m(k)?)
      DoNotOptimise.observe()
    end
    _i = _i + 1

class iso _PonyMapEqRetrieve is MicroBenchmark
  let _n: USize
  let _a: Array[USize]
  let _b: Array[USize]
  var _m: pony.Map[USize, _TestValue]
  var _i: USize

  new iso create(n: USize = 1_000_000) =>
    _n = n
    let r = Rand
    _a = try _Shuffle.get_array(r, _n)? else Array[USize] end
    _b = try _Shuffle.get_array(r, _n)? else Array[USize] end
    _m = pony.Map[USize, _TestValue]
    for k in _a.values() do
      _m = _m.update(k, _TestValue(k))
    end
    _i = 0

  fun name(): String => "pony/map/eq/retrieve " + _n.string()

  fun ref apply() =>
    try
      let k = _b(_i % _b.size())?
      DoNotOptimise[_TestValue](_m(k)?)
      DoNotOptimise.observe()
    end
    _i = _i + 1

class iso _KuliMapEqRemove is MicroBenchmark
  let _n: USize
  let _a: Array[USize]
  let _b: Array[USize]
  var _m: kuli.Map[USize, _TestValue]
  var _i: USize

  new iso create(n: USize = 1_000_000) =>
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

  fun name(): String => "kuli/map/eq/remove " + _n.string()

  fun ref apply() =>
    try
      let k = _b(_i % _b.size())?
      _m = _m.remove(k)?
      DoNotOptimise[kuli.Map[USize, _TestValue]](_m)
      DoNotOptimise.observe()
    end
    _i = _i + 1

class iso _PonyMapEqRemove is MicroBenchmark
  let _n: USize
  let _a: Array[USize]
  let _b: Array[USize]
  var _m: pony.Map[USize, _TestValue]
  var _i: USize

  new iso create(n: USize = 1_000_000) =>
    _n = n
    let r = Rand
    _a = try _Shuffle.get_array(r, _n)? else Array[USize] end
    _b = try _Shuffle.get_array(r, _n)? else Array[USize] end
    _m = pony.Map[USize, _TestValue]
    for k in _a.values() do
      _m = _m.update(k, _TestValue(k))
    end
    _i = 0

  fun name(): String => "pony/map/eq/remove " + _n.string()

  fun ref apply() =>
    try
      let k = _b(_i % _b.size())?
      _m = _m.remove(k)?
      DoNotOptimise[pony.Map[USize, _TestValue]](_m)
      DoNotOptimise.observe()
    end
    _i = _i + 1

class iso _KuliMapEqIterate is MicroBenchmark
  let _n: USize
  let _a: Array[USize]
  let _m: kuli.Map[USize, _TestValue]
  let _i: Iterator[(USize, _TestValue)]

  new iso create(n: USize = 1_000_000) =>
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

  fun name(): String => "kuli/map/eq/iterate " + _n.string()

  fun ref apply() =>
    if _i.has_next() then
      try
        DoNotOptimise[(USize, _TestValue)](_i.next()?)
        DoNotOptimise.observe()
      end
    end

class iso _PonyMapEqIterate is MicroBenchmark
  let _n: USize
  let _a: Array[USize]
  let _m: pony.Map[USize, _TestValue]
  let _i: Iterator[(USize, _TestValue)]

  new iso create(n: USize = 1_000_000) =>
    _n = n
    _a = try _Shuffle.get_array(Rand, _n)? else Array[USize] end
    var m = pony.Map[USize, _TestValue]
    for k in _a.values() do
      m = m.update(k, _TestValue(k))
    end
    _m = m
    _i = m.pairs()

  fun name(): String => "pony/map/eq/iterate " + _n.string()

  fun ref apply() =>
    if _i.has_next() then
      try
        DoNotOptimise[(USize, _TestValue)](_i.next()?)
        DoNotOptimise.observe()
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
