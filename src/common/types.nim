import std/uri


const HASH_SIZE* = 160
const HASH_SIZE_BYTES* : int = HASH_SIZE div 8
type NodeId* = array[HASH_SIZE_BYTES, byte]



type KademliaInterface* = concept c
    c.ping() is bool
    c.findNode(NodeID) is seq[Uri]
    c.findValue(NodeID) is string
    c.store(NodeID, string) is bool
    c.nodeId is NodeID
