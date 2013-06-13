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

