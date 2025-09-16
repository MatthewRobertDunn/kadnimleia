import std/unittest
import std/sysrand
import std/strformat
import std/options
import std/uri
import ../../server/routing_table
import ../../common/types
import std/asyncdispatch
from std/sugar import `=>`

proc getTestUri(): Uri =
    var expectedId: NodeId
    if not urandom(expectedId):
      assert(false, "NodeID Generation failed")
    return newKadUri(expectedId, "127.0.0.1", "1234")

test "URI encoding":
    var expectedId: NodeId
    if not urandom(expectedId):
        assert(false, "NodeID Generation failed")
    let testUri = newKadUri(expectedId, "127.0.0.1", "1234")
    let actualId = testUri.toNodeId()
    assert(actualId.isSome)
    assert(actualId.get == expectedId)


test "bucketIndex for identical IDs is 0":
    var x: NodeId
    var y: NodeId
    let result = bucketIndex(x,y)
    assert(result == 0)

test "bucketIndex detects last bit difference":
  var x, y: NodeId
  y[^1] = 1
  let result = bucketIndex(x, y)
  assert(result == 1, fmt"Got {result} expected 1")

test "bucketIndex detects first bit difference":
  var x, y: NodeId
  x[0] = 0b1000_0000
  let result = bucketIndex(x, y)
  assert(result == HASH_SIZE, fmt"Got {result} expected {HASH_SIZE}")


test "bucketIndex detects difference in 4th byte":
  var x, y: NodeId
  # pick a bit in the 4th byte (index 3), third MSB
  y[3] = 1'u8 shl 5
  let result = bucketIndex(x, y)
  assert(result == HASH_SIZE - (3*8 + (7-5)), fmt"Got {result} expected {HASH_SIZE - (3*8 + (7-5))}")  



test "insert node into empty routing table":
  proc test() {.async.} = 
    var myNodeId: NodeId
    let myNode = newKadUri(myNodeId, "127.0.0.1", "1234")
    var otherNodeId: NodeId
    otherNodeId[2] = 0xFF
    let otherNode = newKadUri(otherNodeId, "127.0.0.2", "1234")
    let routingTable = newRoutingTable(myNode, nil)
    await routingTable.insertOrUpdate(otherNode)
  
  waitFor(test())
