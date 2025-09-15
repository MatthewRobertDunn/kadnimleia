import std/uri
import std/times
import stew/base64 
import std/options
import std/parseutils
import strutils
import std/sequtils
import ../common/types
import ../common/seq_utils
import std/asyncdispatch
from std/sugar import `=>`

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


type BucketEntry* = ref object
    node: Uri
    nodeId: NodeId
    lastSeen: DateTime

type Bucket = seq[BucketEntry]

proc findByNodeId(self: Bucket, nodeId: NodeId): BucketEntry =
    let entries = self.filterIt(it.nodeId == nodeId)
    if(entries.len == 0):
        return nil
    elif(entries.len == 1):
        return entries[0]
    else:
        raise newException(ValueError, "Unexpected duplicates in bucket")

type RoutingTable* = ref object
    localNode: Uri   #our local name and address eg kad://nodeid@ip:port
    localNodeId: NodeId
    maxEntries: int
    table: array[HASH_SIZE + 1, Bucket]
    resolveNode: proc(node: Uri): KademliaInterface


proc newRoutingTable* (localNode: Uri) : RoutingTable =
    let localNodeId = localNode.toNodeId()
    if (localNodeId.isNone):
        raise newException(ValueError, "Invalid local Uri")
    #initialize a new table array, wonder if this is correctly done
    var table: array[HASH_SIZE + 1, Bucket]
    for i in 0..HASH_SIZE:
        table[i] = @[]
    return RoutingTable(
                            localNode: localNode,
                            localNodeId: localNodeId.get,
                            maxEntries: 20,
                            table: table
                        )
   
const PING_TIMEOUT = 5000

proc insertOrUpdateBucket(self: RoutingTable, bucket: var Bucket, node: Uri, nodeId: NodeId) {.async.} =
     #check if we already know this node
    let bucketEntry = bucket.findByNodeId(nodeId)
    if(bucketEntry != nil):
        bucketEntry.node = node
        bucketEntry.lastSeen = now()
        return

    if(bucket.len >= self.maxEntries):
        let oldestEntry = bucket.minBy(x => x.lastSeen)
        let proxy = self.resolveNode(oldestEntry.node)
        try:
            
            if(await proxy.ping().withTimeout(PING_TIMEOUT)):
                #ping was a success, just update last seen and exit
                oldestEntry.lastSeen = now()
                return
        except:
            discard
        #Add new entry
        let newEntry = BucketEntry(node: node, nodeId: nodeId, lastSeen: now())
        bucket.add(newEntry)

proc insertOrUpdate* (self: RoutingTable, node: Uri): Future = 
    let nodeId = node.toNodeId()
    if(nodeId.isNone):
        return
    let bucketIndex = self.localNodeId.bucketIndex(nodeId.get)
    return self.insertOrUpdateBucket(self.table[bucketIndex], node, nodeId)

#hi there