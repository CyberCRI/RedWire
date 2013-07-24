# Get alias for the global scope
globals = @

# All will be in the "GE" namespace
GE = {}
# Export GE globally
globals.GE = GE

# Can be used to mimic enums in JS
# Since this is called by the GE namspace definition below, it must be defined first
GE.makeConstantSet = (values...) ->
  obj =
    # Checks if the value is in the set
    contains: (value) -> return value of obj
  for value in values then obj[value] = value
  return Object.freeze(obj)

GE.logLevels = GE.makeConstantSet("ERROR", "WARN", "INFO", "LOG")

GE.signals = GE.makeConstantSet("DONE", "ERROR")

# Looks for the first element in the array or object which is equal to value.
# If no element exists, returns -1
GE.indexOfEquals = (collection, value) ->
  for k, v of collection
    if _.isEqual(v, value) then return k
  return -1

# There is probably a faster way to do this 
GE.cloneData = (o) -> JSON.parse(JSON.stringify(o))

# Create new array with the value of these arrays
GE.concatenate = (rest...) -> _.flatten(rest, true)

