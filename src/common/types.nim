import std/asyncfutures
import std/uri
import std/parseutils
import strutils
import std/options
import stew/base64 

const HASH_SIZE* = 160
const HASH_SIZE_BYTES* : int = HASH_SIZE div 8
type NodeId* = array[HASH_SIZE_BYTES, byte]


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

type KademliaInterface* = ref object of RootObj

method ping*(self: KademliaInterface): Future[bool] {.base.} =
    quit("Not implemented")


type ResolveNodeProxy* = proc(node: Uri): KademliaInterface

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
