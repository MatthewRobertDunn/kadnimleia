
from ../common/types import KademliaInterface

type KadServer* = object

proc ping*(self: KadServer): bool = 
    return true