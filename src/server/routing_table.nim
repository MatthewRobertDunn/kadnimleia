import std/uri
import std/times
import stew/base64 
import std/options
import std/parseutils
import strutils
from ../common/types import HASH_SIZE, HASH_SIZE_BYTES, NodeId

const VALID_SCHEMES = @["tcp"]
proc isValidKadUri(self: Uri): bool =
    #Allowed schemes
    if not (self.scheme in VALID_SCHEMES):
        return false

    #username must be at least HASH_SIZE_BYTES
    if(self.username.len < HASH_SIZE_BYTES):  
        return false

    var port: int = 0
    try: 
        if parseInt(self.port, port) == 0:
            return false
    except ValueError: 
        return false

    if port < 1024:
        return false

    if self.hostname.isEmptyOrWhitespace():
        return false 

    return true    

proc toNodeId*(self: Uri): Option[NodeId] =
    if(not self.isValidKadUri()):
        return none(NodeId)

    var decoded : seq[byte] = decode(Base64Url, self.username)
    if decoded.len != HASH_SIZE_BYTES:
        return none(NodeId)
    return some(cast[ptr NodeId](decoded[0].addr)[])
    
proc toUserName(nodeId: NodeId): string =
    return encode(Base64Url, nodeId)

proc newKadUri*(nodeId: NodeId, host: string, port: string, isIPv6 = false): Uri =
  result = initUri(isIPv6)
  result.scheme = "tcp"
  result.username = toUserName(nodeId)
  result.hostname = host
  result.port = port    


proc kadDistance(self: NodeID, other: NodeID): NodeID =
    for i in 0..<HASH_SIZE_BYTES:
        result[i] = self[i] xor other[i]      

#Find the first bit that differs based on the distance metrix
proc bucketIndex*(self: NodeId, other: NodeId): int =
    let dist = self.kadDistance(other)
    for i in 0..<HASH_SIZE_BYTES:          # MSB → LSB bytes
        if dist[i] == 0:
            continue
        for bit in countdown(7, 0):
            if (dist[i] and (1'u8 shl bit)) != 0:
                return HASH_SIZE - (i*8 + (7 - bit))
    return 0


type BucketEntry* = object
    node: Uri
    lastSeen: DateTime

type RoutingTable* = object
    localUri: Uri   #our local name and address eg kad://nodeid@ip:port
    localNodeId: NodeId
    k: int
    table: array[HASH_SIZE - 1, seq[BucketEntry]]


proc newRoutingTable* (localUri: Uri) : RoutingTable =
    let localNodeId = localUri.toNodeId()
    if (localNodeId.isNone):
        raise newException(ValueError, "Invalid local Uri")
    #initialize a new table array, wonder if this is correctly done
    var table: array[HASH_SIZE - 1 , seq[BucketEntry]]
    for i in 0..<(HASH_SIZE - 1):
        table[i] = @[]
    return RoutingTable(
                        localUri: localUri,
                        localNodeId: localNodeId.get,
                        k: 20,
                        table: table
                        )



    




