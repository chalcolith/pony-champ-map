# Pony-Champ-Map

This is an experimental implementation of the compressed hash array-mapped
prefix tree from 'Optimizing Hash-Array Mapped Tries for Fast and Lean Immutable
JVM Collections' by Michael J. Steindorfer and Jurgen J. Vinju.

Mostly developed to investigate bugs in the existing Pony implementation.

## Installation

* Install [pony-stable](https://github.com/ponylang/pony-stable)
* Update your `bundle.json`

```json
{
  "type": "github",
  "repo": "kulibali/pony-champ-map"
}
```

* `stable fetch` to fetch your dependencies
* `use "{PACKAGE}"` to include this package
* `stable env ponyc` to compile your application
