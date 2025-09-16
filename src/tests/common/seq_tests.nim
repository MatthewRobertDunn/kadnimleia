import std/unittest
import ../../common/seq_utils
import std/strformat
from std/sugar import `=>`

test "maxBy":
    let s = @[5, 10 , 12, 2, 5]
    let expected = 12
    let actual = s.maxBy(x => x)
    assert(expected == actual, fmt"Got {actual} expected {expected}")



test "minBy":
    let s = @[5, 10 , 12, 2, 5]
    let expected = 2
    let actual = s.minBy(x => x)
    assert(expected == actual, fmt"Got {actual} expected {expected}")    

test "remove":
    var s = @[5, 10 , 12, 2, 5]
    s.remove(10)
    let expected = @[5, 5, 12, 2]
    assert(s == expected, fmt"Got {s} expected {expected}")        

#chirp chirp chirp