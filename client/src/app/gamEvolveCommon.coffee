# Get alias for the global scope
globals = @

# All will be in the "GE" namespace
GE = globals.GE ? {}
globals.GE = GE

# Can be used to mimic enums in JS
# Since this is called by the GE namspace definition below, it must be defined first
GE.makeConstantSet = (values...) ->
  obj =
    # Checks if the value is in the set
    contains: (value) -> return value of obj
  for value in values then obj[value] = value
  return Object.freeze(obj)

GE.logLevels = GE.makeConstantSet("ERROR", "WARN", "INFO")

GE.signals = GE.makeConstantSet("DONE", "ERROR")

# Looks for the first element in the array or object which is equal to value, using the _.isEqual() test
# If no element exists, returns -1
GE.indexOf = (collection, value) ->
  for k, v of collection
    if _.isEqual(v, value) then return k
  return -1

# Returns true if the value is in the collection, using the _.isEqual() test
# If no element exists, returns -1
GE.contains = (collection, value) -> GE.indexOf(collection, value) != -1

# Similar to _.uniq(), but tests using the _.isEqual() method
GE.uniq = (array) ->
  results = []
  seen = []
  _.each array, (value, index) ->
    if not GE.contains(seen, value)
      seen.push(value)
      results.push(array[index])
  return results

# There is probably a faster way to do this 
GE.cloneData = (o) -> 
  try
    JSON.parse(JSON.stringify(o))
  catch e
    throw new Error("Unable to clone, perhaps it is not plain old data: #{e}")

# Create new array with the value of these arrays
GE.concatenate = (rest...) -> _.flatten(rest, true)

# Return an array with the new value added
GE.appendToArray = (array, value) -> GE.concatenate(array, [value])

# Return an array with all instances of the element removed
GE.removeFromArray = (array, value) -> return (element for element in array when not _.isEqual(value, element))

# If the value is not in the array, then add it, else remove it
GE.toggleValueInArray = (array, value) ->
  return if GE.contains(array, value) then GE.removeFromArray(array, value) else GE.appendToArray(array, value)

# Like Underscore's method, but uses GE.indexOf()
GE.intersection = (array) ->
  rest = Array.prototype.slice.call(arguments, 1)
  return _.filter _.uniq(array), (item) ->
    return _.every rest, (other) ->
      return GE.indexOf(other, item) >= 0

# Like Underscore's method, but uses GE.contains()
GE.difference = (array) ->
  rest = Array.prototype.concat.apply(Array.prototype, Array.prototype.slice.call(arguments, 1))
  return _.filter array, (value) -> 
    return not GE.contains(rest, value)

# Shortcut for timeout function, to avoid trailing the time at the end 
GE.doLater = (f) -> setTimeout(f, 0)

# Freeze an object recursively
# Based on https://developer.mozilla.org/en-US/docs/JavaScript/Reference/Global_Objects/Object/freeze
GE.deepFreeze = (o) -> 
  # First freeze the object
  Object.freeze(o)

  # Recursively freeze all the object properties
  for own key, prop of o
    if _.isObject(prop) and not Object.isFrozen(prop) then GE.deepFreeze(prop)

  return o

# Shortcut to clone and then freeze result
GE.cloneFrozen = (o) -> return GE.deepFreeze(GE.cloneData(o))

# Adds value to the given object, associating it with an unique (and meaningless) key
# Returns 
GE.addUnique = (obj, value) -> obj[_.uniqueId()] = value

# Creates a new object based on the keys and values of the given one.
# Calls f(value, key) for each key
GE.mapObject = (obj, f) -> 
  mapped = {}
  for key, value of obj
    mapped[key] = f(value, key)
  return mapped

# Returns an object { mimeType: String, base64: Bool, data: String}
GE.splitDataUrl = (url) -> 
  matches = url.match(/data:([^;]+);([^,]*),(.*)/)
  return {
    mimeType: matches[1]
    base64: matches[2] == "base64"
    data: matches[3]
  }

# Creates and returns a blob from a data URL (either base64 encoded or not).
# Adopted from filer.js by Eric Bidelman (ebidel@gmail.com)
GE.dataURLToBlob = (dataURL) ->
  BASE64_MARKER = 'base64,'
  if dataURL.indexOf(BASE64_MARKER) == -1
    parts = dataURL.split(',')
    contentType = parts[0].split(':')[1]
    raw = parts[1]

    return new Blob([raw], {type: contentType})

  parts = dataURL.split(BASE64_MARKER)
  contentType = parts[0].split(':')[1]
  raw = window.atob(parts[1])
  rawLength = raw.length

  uInt8Array = new Uint8Array(rawLength)

  for i in [0..rawLength - 1] 
    uInt8Array[i] = raw.charCodeAt(i)

  return new Blob([uInt8Array], {type: contentType})

# For accessing a value within an embedded object or array
# Takes a parent object/array and the "path" as an array
# Returns [parent, key] where parent is the array/object and key is last one required to access the child
GE.getParentAndKey = (parent, pathParts) ->
  if pathParts.length is 0 then return [parent, null]
  if pathParts.length is 1 then return [parent, pathParts[0]]
  if pathParts[0] of parent then return GE.getParentAndKey(parent[pathParts[0]], _.rest(pathParts))
  throw new Error("Cannot find intermediate key '#{pathParts[0]}'")

# Return the beginning of a string, up to the first newline
GE.firstLine = (str) ->
  index = str.indexOf("\n")
  return if index is -1 then str else str.slice(0, index)

# Returns a new object like the old one, but with the new key-value pair set
GE.addToObject = (obj, key, value) ->
  newObj = GE.cloneData(obj)
  newObj[key] = value
  return newObj

# Returns a new object like the old one, but with the value set at a unique key
GE.addUniqueToObject = (obj, value) -> GE.addToObject(obj, _.uniqueId(), value)

# Like _.filter(), but preserves object indexes
GE.filterObject = (obj, predicate) ->
  newObj = {}
  for key, value of obj
    if predicate(value, key) then newObj[key] = value
  return newObj
