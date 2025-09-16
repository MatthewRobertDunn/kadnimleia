#bucket.nim
import ../common/types
import ../common/sequtils
import std/uri
import std/times
import std/locks
import std/sequtils
import std/options
from std/sugar import `=>`

type BucketEntryObj* = object
    node*: Uri
    nodeId*: NodeId
    lastSeen*: DateTime

type BucketEntry* = ref BucketEntryObj    

type BucketObj = object
    entries: seq[BucketEntry]
    lock: Lock

type Bucket* = ref BucketObj

proc `=destroy`(self: BucketObj) =
    deinitLock(self.lock)

proc newBucket*(): Bucket = 
    let bucket = Bucket()
    initLock(bucket.lock)
    return bucket

proc findByNodeId*(self: Bucket, nodeId: NodeId): BucketEntry =
    withLock(self.lock):
        for entry in self.entries:
            if entry.nodeId == nodeId:
                return entry

proc replace*(self: Bucket, oldEntry: BucketEntry, newEntry: BucketEntry) = 
    withLock(self.lock):
        let oldLength = self.entries.len
        self.entries.remove(oldEntry)
        if(oldLength == self.entries.len):
            raise newException(ValueError, "Old entry did not exist in the bucket")
        self.entries.add(newEntry)

proc add*(self: Bucket, newEntry: BucketEntry) =
    withLock(self.lock):
        self.entries.add(newEntry)

proc remove*(self: Bucket, entry: BucketEntry) =
    withLock(self.lock):
        self.entries.remove(entry)

proc len*(self: Bucket): int = 
    withLock(self.lock):
        return len(self.entries)

proc findLeastRecentlySeenIfFull*(self: Bucket, capacity: int): Option[BucketEntry] =
    withLock(self.lock):
        if self.entries.len < capacity:
            return none(BucketEntry)
        return some(self.entries.minBy(x => x.lastSeen))

proc toSeq*(self: Bucket): seq[BucketEntryObj] =
    withLock(self.lock):
        return self.entries.map(x => x[])