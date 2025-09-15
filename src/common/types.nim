import std/asyncfutures

const HASH_SIZE* = 160
const HASH_SIZE_BYTES* : int = HASH_SIZE div 8
type NodeId* = array[HASH_SIZE_BYTES, byte]

type KademliaInterface* = ref object of RootObj

method ping*(self: KademliaInterface): Future[bool] {.base.} =
    quit("Not implemented")