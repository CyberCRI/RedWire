###
LCS implementation that supports arrays or strings

Ripped and adapted from https://github.com/benjamine/jsondiffpatch

reference: http://en.wikipedia.org/wiki/Longest_common_subsequence_problem
###

# Get alias for the global scope
globals = @

# All will be in the "RW" namespace
RW = globals.RW ? {}
globals.RW = RW

checkMatch = (oldValue, newValue, indexInOldValue, indexInNewValue) -> _.isEqual(oldValue[indexInOldValue], newValue[indexInNewValue])

lengthMatrix = (oldValue, newValue) ->
  len1 = oldValue.length
  len2 = newValue.length
  x = undefined
  y = undefined
  
  # initialize empty matrix of len1+1 x len2+1
  matrix = [len1 + 1]
  x = 0
  while x < len1 + 1
    matrix[x] = [len2 + 1]
    y = 0
    while y < len2 + 1
      matrix[x][y] = 0
      y++
    x++

  # save sequence lengths for each coordinate
  x = 1
  while x < len1 + 1
    y = 1
    while y < len2 + 1
      if checkMatch(oldValue, newValue, x - 1, y - 1)
        matrix[x][y] = matrix[x - 1][y - 1] + 1
      else
        matrix[x][y] = Math.max(matrix[x - 1][y], matrix[x][y - 1])
      y++
    x++
  return matrix

backtrack = (matrix, oldValue, newValue, indexInOldValue, indexInNewValue) ->
  if indexInOldValue is 0 or indexInNewValue is 0
    return (
      sequence: []
      indices1: []
      indices2: []
    )
  if checkMatch(oldValue, newValue, indexInOldValue - 1, indexInNewValue - 1)
    subsequence = backtrack(matrix, oldValue, newValue, indexInOldValue - 1, indexInNewValue - 1)
    subsequence.sequence.push oldValue[indexInOldValue - 1]
    subsequence.indices1.push indexInOldValue - 1
    subsequence.indices2.push indexInNewValue - 1
    return subsequence
  if matrix[indexInOldValue][indexInNewValue - 1] > matrix[indexInOldValue - 1][indexInNewValue]
    backtrack matrix, oldValue, newValue, indexInOldValue, indexInNewValue - 1
  else
    backtrack matrix, oldValue, newValue, indexInOldValue - 1, indexInNewValue

analyzeLcs = (oldValue, newValue) ->
  matrix = lengthMatrix(oldValue, newValue)
  result = backtrack(matrix, oldValue, newValue, oldValue.length, newValue.length)
  result.sequence = result.sequence.join("")  if typeof oldValue is "string" and typeof newValue is "string"
  return result

RW.makePatchesForArray = (oldValue, newValue, path, prefix, patches) ->
  commonHead = 0
  commonTail = 0
  len1 = oldValue.length 
  len2 = newValue.length

  # Find common head
  while commonHead < len1 && commonHead < len2 && _.isEqual(oldValue[commonHead], newValue[commonHead])
    commonHead++

  # Find common tail 
  while commonTail + commonHead < len1 && commonTail + commonHead < len2 && _.isEqual(oldValue[len1 - 1 - commonTail], newValue[len2 - 1 - commonTail])
    commonTail++

  if commonHead + commonTail == len1
    # Trivial case, a block (1 or more consecutive items) was added
    for index in _.range(commonHead, len2 - commonTail) 
      patches.push { add: "#{prefix}/#{index}", value: newValue[index], path: path }
  else if commonHead + commonTail == len2
    # Trivial case, a block (1 or more consecutive items) was removed
    for index in _.range(commonHead, len1 - commonTail) 
      patches.push { remove: "#{prefix}/#{index}", path: path }
  else
    # Diff is not trivial, find the LCS (Longest Common Subsequence)
    trimmed1 = oldValue.slice(commonHead, len1 - commonTail)
    trimmed2 = newValue.slice(commonHead, len2 - commonTail)
    seq = analyzeLcs(trimmed1, trimmed2)

    removedIndexes = []
    index = commonHead
    while index < len1 - commonTail
      if not _.contains(seq.indices1, index - commonHead) 
        # either removed or modified
        removedIndexes.push(index)
      index++

    index = commonHead
    while index < len2 - commonTail
      if not _.contains(seq.indices2, index - commonHead)
        if _.contains(removedIndexes, index)
          # OPT: there must be a better way to do this
          RW.makePatches(oldValue[index], newValue[index], path, "#{prefix}/#{index}", patches)
          removedIndexes = _.without(removedIndexes, index)
        else
          # added
          patches.push({ add: "#{prefix}/#{index}", value: newValue[index], path: path })
      index++

    for index in removedIndexes
      patches.push({ remove: "#{prefix}/#{index}", path: path })

  return patches
