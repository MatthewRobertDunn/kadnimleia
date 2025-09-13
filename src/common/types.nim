import std/uri

type NodeID* = array[160, byte]

type KademliaInterface* = concept c
    c.ping() is bool
    c.findNode(NodeID) is seq[Uri]
    c.findValue(NodeID) is string
    c.store(NodeID, string) is bool
    c.nodeId is NodeID
