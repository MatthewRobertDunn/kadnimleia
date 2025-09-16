
type
  Comparable = concept T
    (T < T) is bool

type
  Equateable = concept T
    (T == T) is bool


# Returns the element in the sequence that maximizes `f`
proc maxBy*[T: Comparable, U](s: seq[T]; f: proc(x:T):U): T =
  if s.len == 0:
    raise newException(ValueError, "Cannot get max of empty sequence")
  var best = s[0]
  var bestVal = f(best)
  for x in s[1..^1]:
    let val = f(x)
    if val > bestVal:
      best = x
      bestVal = val
  return best


# Returns the element in the sequence that minimizes `f`
proc minBy*[T: Comparable, U](s: seq[T], f: proc(x:T):U): T =
  if s.len == 0:
    raise newException(ValueError, "Cannot get min of empty sequence")
  var best = s[0]
  var bestVal = f(best)
  for x in s[1..^1]:
    let val = f(x)
    if val < bestVal:
      best = x
      bestVal = val
  return best

# removes an item
proc remove*[T: Equateable](s: var seq[T], item: T) =
  let index = s.find(item)
  if index >= 0:
    s.del(index)