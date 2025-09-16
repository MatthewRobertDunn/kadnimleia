import std/uri
import std/times
import std/options
import ../common/types
import std/asyncdispatch
import std/async
import buckets
import std/strformat

type RoutingTable* = ref object
    localNode: Uri   #our local name and address eg kad://nodeid@ip:port
    localNodeId: NodeId
    maxEntries: int
    table: array[HASH_SIZE + 1, Bucket]
    resolveNodeProxy: ResolveNodeProxy

proc newRoutingTable* (localNode: Uri, reolveNodeProxy: ResolveNodeProxy) : RoutingTable =
    let localNodeId = localNode.toNodeId()
    if (localNodeId.isNone):
        raise newException(ValueError, "Invalid local Uri")
    #initialize a new table array, wonder if this is correctly done
    var table: array[HASH_SIZE + 1, Bucket]
    for i in 0..HASH_SIZE:
        table[i] = newBucket(index = i)
    return RoutingTable(
                            localNode: localNode,
                            localNodeId: localNodeId.get,
                            maxEntries: 20,
                            table: table
                        )
   
const PING_TIMEOUT = 5000


proc getBucketByNodeId(self: RoutingTable, nodeId: NodeId): Bucket = 
    let bucketIndex = self.localNodeId.bucketIndex(nodeId)
    return self.table[bucketIndex]

proc insertOrUpdate* (self: RoutingTable, node: Uri) {.async.} = 
    let parsedNodeId = node.toNodeId()
    if(parsedNodeId.isNone):
        return
    let nodeId = parsedNodeId.get

    var bucket = self.getBucketByNodeId(nodeId)

    #check if we already know this node
    let bucketEntry = bucket.findByNodeId(nodeId)
    if(bucketEntry != nil):
        bucketEntry.node = node
        bucketEntry.lastSeen = now()
        return

    let maybeOldestEntry = bucket.findLeastRecentlySeenIfFull(self.maxEntries)
    if maybeOldestEntry.isSome:
        #bucket is full
        let oldestEntry = maybeOldestEntry.get
        let proxy = self.resolveNodeProxy(oldestEntry.node)
        try:
            if(await proxy.ping().withTimeout(PING_TIMEOUT)):
                #ping was a success, just update last seen and exit
                oldestEntry.lastSeen = now()
                return
        except:
            #ping wasn't a success, remove old entry, new one will be added
            bucket.remove(oldestEntry)
    #Add new entry
    let newEntry = BucketEntry(node: node, nodeId: nodeId, lastSeen: now())
    bucket.add(newEntry)

proc getBucketSnapshot*(self: RoutingTable, nodeId: NodeId): (seq[BucketEntryObj], int) =
    let bucket = self.getBucketByNodeId(nodeId)
    return (bucket.toSeq(), bucket.index)