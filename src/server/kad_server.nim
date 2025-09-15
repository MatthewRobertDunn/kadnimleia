
from ../common/types import KademliaInterface

type KadServer* = object

proc ping*(self: KadServer): bool = 
    return true

proc toConcept*(self: KadServer): KademliaInterface =
    return self