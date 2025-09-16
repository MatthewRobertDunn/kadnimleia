import ../../common/types
import std/[asyncdispatch, uri]


# Dummy implementation for testing
type
  DummyNode* = ref object of KademliaInterface
    node: Uri
    totalPings: int

method ping*(self: DummyNode): Future[bool] {.async.} =
  self.totalPings = self.totalPings + 1
  return true