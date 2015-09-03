# Get alias for the global scope
globals = @

# All will be in the "RW" namespace
RW = globals.RW ? {}
globals.RW = RW

# The logFunction can be reset before visiting each chip that calls transformers
RW.transformersLogger = null

RW.Circuit = class 
  constructor: (options) -> 
    _.defaults this, options,
      board: {}

RW.ChipVisitorConstants = class 
  constructor: (options) -> 
    _.defaults this, options,
      circuits: 
        main: new RW.Circuit()
      processors: {}
      switches: {}
      transformers: {}
      assets: {}
      memoryData: {} # Map of circuitIds to data
      ioData: {} # Map of circuitIds to data

RW.CircuitMeta = class
  constructor: (@id, @type) -> 

RW.CircuitResult = class 
  constructor: (options) -> 
    _.defaults this, options,
      memoryPatches: []
      ioPatches: []
      circuitPatches: []
      logMessages: []
      scratchPatches: []
      activeChipPaths: []

# A ChipVisitorResult is a single signal and a collection of CircuitResult
RW.ChipVisitorResult = class 
  constructor: (@signal = null, @circuitResults = {}) ->

  # Creates circuit results if they don't exist, and returns it
  getCircuitResults: (circuitId) -> 
    if circuitId not of @circuitResults then @circuitResults[circuitId] = new RW.CircuitResult()
    return @circuitResults[circuitId]

  # Adds new results to current one. Does not affect @signal
  append: (other) ->
    for circuitId, circuitResult of other.circuitResults
      # If we don't have existing results, just reference the new ones
      if circuitId not of @circuitResults then @circuitResults[circuitId] = circuitResult
      else
        # Append onto the existing ones
        for attr in ["memoryPatches", "ioPatches", "circuitPatches", "scratchPatches", "logMessages", "activeChipPaths"]
          @circuitResults[circuitId][attr] = @circuitResults[circuitId][attr].concat(other.circuitResults[circuitId][attr])

# Class used just to "tag" a string as being a reference rather than a JSON value
RW.BindingReference = class 
  constructor: (@ref) ->

# Search through the board returning a list of all circuitMeta
RW.listCircuitMeta = (circuits) -> 
  searchRecursive = (parentId, chip, circuitMetaList) -> 
    if "circuit" of chip 
      newCircuitMeta = new RW.CircuitMeta(RW.makeCircuitId(parentId, chip.id), chip.circuit)
      circuitMetaList.push(newCircuitMeta)
      searchRecursive(newCircuitMeta.id, circuits[chip.circuit].board, circuitMetaList)
    if "children" of chip 
      for child in chip.children then searchRecursive(parentId, child, circuitMetaList)
    return circuitMetaList

  return searchRecursive("main", circuits.main.board, [new RW.CircuitMeta("main", "main")])

RW.makeCircuitId = (parentId, childId) -> "#{parentId}.#{childId}"

RW.getParentCircuitId = (circuitId) -> _.initial(circuitId.split(".")).join(".")

RW.getChildCircuitId = (circuitId) -> _.last(circuitId.split("."))

# Used to evaluate expressions against with RW.evaluateExpressionFunction
RW.makeEvaluationContext = (circuitMeta, constants, circuitData, scratchData, bindings) ->
  context = 
    memory: constants.memoryData[circuitMeta.id]
    io: constants.ioData[circuitMeta.id]
    assets: constants.assets
    transformers: constants.transformers
    circuit: circuitData
    scratch: scratchData
    bindings: {}
  RW.setupBindings(context, bindings)
  return context

RW.setupBindings = (evaluationContext, bindings) ->
  for bindingName, bindingValue of bindings
    if bindingValue instanceof RW.BindingReference
      [parent, key] = RW.getParentAndKey(evaluationContext, RW.splitAddress(bindingValue.ref))
      evaluationContext.bindings[bindingName] = parent[key]
    else
      evaluationContext.bindings[bindingName] = bindingValue

# context is created with RW.makeEvaluationContext()
# pins are optional
RW.evaluateExpressionFunction = (context, f, pins) ->
  f(context.memory, context.io, context.assets, context.transformers, context.circuit, context.bindings, pins)

# context is created with RW.makeEvaluationContext()
RW.evaluateEmitterFunction = (context, f) ->
  f(context.memory, context.io, context.assets, context.transformers, context.circuit, context.bindings)

# Returns address as array (like pathParts) with binding refs replaced with their full addresses (to memory or io) 
RW.resolveBindingAddresses = (bindings, pathParts) ->
  if pathParts[0] in ["memory", "io", "circuit", "scratch"] then return pathParts
  if pathParts[0] is "bindings"
    if pathParts[1] not of bindings then throw new Error("Cannot find the binding for #{pathParts[1]}")
    bindingValue = bindings[pathParts[1]]
    if bindingValue instanceof RW.BindingReference
      replacedAddress = RW.splitAddress(bindingValue.ref).concat(pathParts[2..])
      return RW.resolveBindingAddresses(bindings, replacedAddress)
    else
      throw new Error("Cannot write to constant bindings such as '#{JSON.stringify(bindingValue)}'")
  else throw new Error("Cannot resolve address '#{RW.joinPathParts(pathParts)}'")

# Reject arrays as objects
RW.isOnlyObject = (o) -> return _.isObject(o) and not _.isArray(o)

# Return a typeof that distinguishes between arrays and objects
RW.typeof = (x) ->
  if _.isArray(x) then return "array"
  return typeof(x)

# Returns an error, setting the circuit and path of the offending chip along the way
RW.makeExecutionError = (msg, circuitMeta, path) -> 
  e = new Error(msg)
  e.circuitMeta = circuitMeta
  e.path = path
  return e

# Sets a value within an embedded object or array, creating intermediate objects if necessary
# Takes a root object/array and the "path" as an array of keys
# Returns the root
RW.deepSet = (root, pathParts, value) ->
  if pathParts.length == 0 then throw new Exception("Path is empty")
  else if pathParts.length == 1 then root[pathParts[0]] = value
  else 
    # The intermediate key is missing, so create a new array for it
    if not root[pathParts[0]]? then root[pathParts[0]] = {}
    RW.deepSet(root[pathParts[0]], _.rest(pathParts), value)
  return root

# Compare new object and old object to create list of patches.
# The top-level oldValue must be an object
# Using JSON patch format @ http://tools.ietf.org/html/draft-pbryan-json-patch-04
# Array analysis is taken from the jsondiffpatch library
# TODO: handle escape syntax
RW.makePatches = (oldValue, newValue, path = null, prefix = "", patches = []) ->
  if _.isEqual(newValue, oldValue) then return patches

  if oldValue is undefined
    patches.push { add: prefix, value: newValue, path: path }
  else if newValue is undefined 
    patches.push { remove: prefix, path: path }
  else if not _.isObject(newValue) or not _.isObject(oldValue) or RW.typeof(oldValue) != RW.typeof(newValue)
    patches.push { replace: prefix, value: newValue, path: path }
  else if _.isArray(oldValue) 
    RW.makePatchesForArray(oldValue, newValue, path, prefix, patches)
  else 
    # both elements are objects 
    keys = _.union(_.keys(oldValue), _.keys(newValue))
    RW.makePatches(oldValue[key], newValue[key], path, "#{prefix}/#{key}", patches) for key in keys

  return patches

# Takes an oldValue and list of patches and creates a new value
# The top-level oldValue must be an object
# Using JSON patch format @ http://tools.ietf.org/html/draft-pbryan-json-patch-04
# TODO: handle escape syntax
RW.applyPatches = (patches, oldValue, prefix = "") ->
  splitPath = (path) -> _.rest(path.split("/"))

  joinPath = (pathParts) -> pathParts.join("/")

  getPatchType = (patch) -> 
    if "remove" of patch then return "remove"
    else if "add" of patch then return "add"
    else if "replace" of patch then return "replace"
    else throw new Error("Can't find type of patch")

  getPatchPath = (patch) -> patch[getPatchType(patch)]

  getPatchSpecificity = (patch) -> splitPath(getPatchPath(patch)).length

  # Keep track of array modifications
  arrayIndexMappings = {}

  ensureIndexMapping = (arrayPath, array)->
    # If we haven't seen this array before, create an identity mapping
    if arrayPath not of arrayIndexMappings
      arrayIndexMappings[arrayPath] = _.object(_.range(array.length), _.range(array.length))
    return arrayIndexMappings[arrayPath]

  handleArrayRemoval = (arrayPath, array, key) ->
    mapping = ensureIndexMapping(arrayPath, array)
    if key of mapping
      # Remove the value itself
      array.splice(mapping[key], 1)

      # Remove the index, and decrement the other indexes
      delete mapping[key]
      for mappingKey, mappingValue of mapping when parseInt(mappingKey) > parseInt(key)
        mapping[mappingKey] = mappingValue - 1

  handleArrayReplacement = (arrayPath, array, key, newValue) ->
    mapping = ensureIndexMapping(arrayPath, array)
    mappedIndex = mapping[key]

    # Change the value itself
    array[mappedIndex] = newValue

  handleArrayInsertion = (arrayPath, array, key, newValue) ->
    mapping = ensureIndexMapping(arrayPath, array)
    # Find the first index in the mapping that is greater than the original key 
    # Because order of object keys may not be perserved, we need to extract the keys and sort them in numerical order
    nextMappingIndex = _.chain(mapping).keys().sortBy((k) -> parseInt(k)).find((k) -> parseInt(k) >= parseInt(key)).value()
    # Obtain the actual index in the array, or if no key is found, insert at the end of the list
    insertIndex = if nextMappingIndex? then mapping[nextMappingIndex] else array.length

    # Insert at the new index
    array.splice(insertIndex, 0, patch.value)

    # Increment the other indexes
    for mappingKey, mappingValue of mapping when parseInt(mappingKey) >= nextMappingIndex
      mapping[mappingKey] = mappingValue + 1

  value = RW.cloneData(oldValue)

  # Sort patches by specificity (most to least) and then by type (replacement, removal, insertion)
  sortedPatches = _.sortBy patches, (patch) ->  
    -3 * getPatchSpecificity(patch) - switch getPatchType(patch)
      when "replace" then 2
      when "remove" then 1
      when "add" then 0

  for patch in sortedPatches
    switch getPatchType(patch)
      when "replace"
        pathParts = splitPath(patch.replace)
        [parent, key] = RW.getParentAndKey(value, pathParts)
        if _.isArray(parent) 
          handleArrayReplacement(joinPath(_.initial(pathParts)), parent, key, patch.value)
        else
          parent[key] = patch.value

      when "remove"
        pathParts = splitPath(patch.remove)
        [parent, key] = RW.getParentAndKey(value, pathParts)
        if _.isArray(parent) 
          handleArrayRemoval(joinPath(_.initial(pathParts)), parent, key)
        else 
          delete parent[key]

      when "add"
        pathParts = splitPath(patch.add)
        [parent, key] = RW.getParentAndKey(value, pathParts)
        if _.isArray(parent)  
          handleArrayInsertion(joinPath(_.initial(pathParts)), parent, key, patch.value)
        else 
          parent[key] = patch.value # For objects

  return value

# We don't allow multiple patches to modify the same data with different values
# Returns a list of objects like { path: "", patches: [] }
RW.detectPatchConflicts = (patches) ->
  patchesConflict = (patches) -> 
    _.uniq(patches, false, ((patch) -> patch.value)).length > 1

  # Only modification patches concern us.
  # Group these patches by their path.
  groupedPatches = _.chain(patches).filter((patch) -> "replace" of patch).groupBy((patch) -> patch.replace).value()

  # Any groups with multiple patches and different values are conflicts
  conflicts = for path, patchGroup of groupedPatches when patchGroup.length > 1 and patchesConflict(patchGroup)
    path: path
    patches: patchGroup

  return conflicts

RW.getPatchDestination = (patch) -> patch.add or patch.replace or patch.remove

# Creates a patch to the outputAddress of the given outputValue and appends it to the result
# TODO: what an unweildy function, with more parameters than lines! Need to refactor it somehow
RW.derivePatches = (circuitMeta, path, bindings, evaluationContext, result, outputAddress, outputValue) -> 
  pathParts = RW.resolveBindingAddresses(bindings, RW.splitAddress(outputAddress))
  # Get the original value to compare the output against
  [parent, key] = RW.getParentAndKey(evaluationContext, pathParts)
  # Find which list to apply patches to
  circuitResults = result.getCircuitResults(circuitMeta.id)
  destinationList = switch pathParts[0] 
    when "memory" then circuitResults.memoryPatches 
    when "io" then circuitResults.ioPatches
    when "circuit" then circuitResults.circuitPatches
    when "scratch" then circuitResults.scratchPatches
    else throw new Error("Unknown destination '#{pathParts[0]}'")

  # Drop "memory" or "io" off the prefix for patches
  prefix = RW.joinPathParts(pathParts[1..])
  # Obtain patches and append them to the destination list
  RW.makePatches(parent[key], outputValue, path, prefix, destinationList)

# Set default values in pinDefs
RW.fillPinDefDefaults = (pinDefs) ->
  # Cannot use normal "for key, value of" loop because cannot handle replace null values
  for pinName of pinDefs
    if not pinDefs[pinName]? then pinDefs[pinName] = {}
    _.defaults pinDefs[pinName], 
      direction: "in"
  return pinDefs

# Returns an object mapping pin expression names to their values 
# pinFunctions is an object that contains 'in' and 'out' attributes
RW.evaluateInputPinExpressions = (circuitMeta, path, constants, evaluationContext, pinDefs, pinFunctions) ->
  evaluatedPins = {}

  for pinName, pinOptions of pinDefs
    # Resolve pin expression value. If the board doesn't specify a value, use the default, it it exists. Otherwise, throw exception for input values
    if pinOptions.direction not in ["in", "inout"] then continue

    # Use default functions if no other is provided
    if pinFunctions.in?[pinName] 
      pinFunction = pinFunctions.in[pinName]
    else if pinOptions.default? 
      pinFunction = pinOptions.default
    else 
      throw RW.makeExecutionError("Missing input pin expression function for pin '#{pinName}'", circuitMeta, path)
    
    try
      # Get the value
      evaluatedPins[pinName] = RW.evaluateExpressionFunction(evaluationContext, pinFunction)
      
      # Protect inout pins from changing buffer values directly by cloning the data
      if pinOptions.direction is "inout"
        evaluatedPins[pinName] = RW.cloneData(evaluatedPins[pinName]) 
    catch error
      throw RW.makeExecutionError("Error evaluating the input pin expression expression '#{pinFunction}' for pin '#{pinName}': #{RW.formatStackTrace(error)}", circuitMeta, path)
  return evaluatedPins

# Updates the evaluation context by evaluating the output pin expressions
# pinFunctions is an object that contains 'in' and 'out' attributes
RW.evaluateOutputPinExpressions = (circuitMeta, path, constants, bindings, evaluationContext, result, pinDefs, pinFunctions, evaluatedPins) ->
  for pinName, pinFunction of pinFunctions?.out
    try
      outputValue = RW.evaluateExpressionFunction(evaluationContext, pinFunction, evaluatedPins)
    catch error
      throw RW.makeExecutionError("Error evaluating the output pin expression '#{pinFunction}' for pin '#{pinName}': #{RW.formatStackTrace(error)}\nPin values were #{JSON.stringify(evaluatedPins)}.", circuitMeta, path)

    RW.derivePatches(circuitMeta, path, bindings, evaluationContext, result, pinName, outputValue)

RW.calculateBindingSet = (circuitMeta, path, chip, constants, circuitData, scratchData, oldBindings) ->
  bindingSet = []

  # If expression is a JSON object (which includes arrays) then loop over the values. Otherwise make references to memory and io
  if _.isObject(chip.splitter.from)
    for key, value of chip.splitter.from
      # Avoid polluting old object, and avoid creating new properties
      newBindings = Object.create(oldBindings)
      newBindings[chip.splitter.bindTo] = value
      if chip.splitter.index? then newBindings["#{chip.splitter.index}"] = key

      if chip.splitter.where?
        evaluationContext = RW.makeEvaluationContext(circuitMeta, constants, circuitData, scratchData, newBindings)

        try
          # If the where clause evaluates to false, don't add it
          if RW.evaluateExpressionFunction(evaluationContext, chip.splitter.where) then bindingSet.push(newBindings)
        catch error
          throw RW.makeExecutionError("Error evaluating the where expression '#{chip.splitter.where}' for splitter chip '#{chip}': #{RW.formatStackTrace(error)}", circuitMeta, path)
      else
        bindingSet.push(newBindings)
  else if _.isString(chip.splitter.from)
    inputContext = 
      memory: constants.memoryData[circuitMeta.id]
      io: constants.ioData[circuitMeta.id]
      circuit: circuitData

    [parent, key] = RW.getParentAndKey(inputContext, RW.splitAddress(chip.splitter.from))
    boundValue = parent[key]

    for key of boundValue
      # Avoid polluting old object, and avoid creating new properties
      newBindings = Object.create(oldBindings)
      newBindings[chip.splitter.bindTo] = new RW.BindingReference("#{chip.splitter.from}.#{key}")
      if chip.splitter.index? then newBindings["#{chip.splitter.index}"] = key

      if chip.splitter.where?
        # TODO: compile expressions ahead of time
        evaluationContext = RW.makeEvaluationContext(circuitMeta, constants, circuitData, scratchData, newBindings)
        try
          # If the where clause evaluates to false, don't add it
          if RW.evaluateExpressionFunction(evaluationContext, chip.splitter.where) then bindingSet.push(newBindings)
        catch error
          throw RW.makeExecutionError("Error evaluating the where expression '#{chip.splitter.where}' for splitter chip '#{chip}': #{RW.formatStackTrace(error)}", circuitMeta, path)
      else
        bindingSet.push(newBindings)
  else
    throw new Error("Splitter 'from' must be string or a JSON object")

  return bindingSet

RW.visitProcessorChip = (circuitMeta, path, chip, constants, circuitData, scratchData, bindings) ->
  if chip.processor not of constants.processors then throw RW.makeExecutionError("Cannot find processor '#{chip.processor}'", circuitMeta, path)

  processor = constants.processors[chip.processor]

  result = new RW.ChipVisitorResult()
  RW.transformersLogger = RW.makeLogFunction(circuitMeta, path, result)

  evaluationContext = RW.makeEvaluationContext(circuitMeta, constants, circuitData, scratchData, bindings)
  RW.fillPinDefDefaults(processor.pinDefs)
  try
    evaluatedPins = RW.evaluateInputPinExpressions(circuitMeta, path, constants, evaluationContext, processor.pinDefs, chip.pins)
  catch e
    result.signal = RW.signals.ERROR
    RW.transformersLogger(RW.logLevels.ERROR, "Evaluating input pin expressions raised an exception #{e}.\n#{RW.formatStackTrace(e)}")
    return result # Quit early

  try
    result.signal = processor.update(evaluatedPins, constants.assets, constants.transformers, RW.transformersLogger)
  catch e
    result.signal = RW.signals.ERROR
    RW.transformersLogger(RW.logLevels.ERROR, "Calling processor #{chip.processor}.update raised an exception #{e}. Input pins were #{JSON.stringify(evaluatedPins)}.\n#{RW.formatStackTrace(e)}")
    return result # Quit early

  try
    RW.evaluateOutputPinExpressions(circuitMeta, path, constants, bindings, evaluationContext, result, processor.pinDefs, chip.pins, evaluatedPins)
  catch e
    result.signal = RW.signals.ERROR
    RW.transformersLogger(RW.logLevels.ERROR, "Evaluating output pin expressions raised an exception #{e}.\n#{RW.formatStackTrace(e)}")
    return result # Quit early

  return result

RW.visitSwitchChip = (circuitMeta, path, chip, constants, circuitData, scratchData, bindings) ->
  if chip.switch not of constants.switches then throw RW.makeExecutionError("Cannot find switch '#{chip.switch}'", circuitMeta, path)

  switchChip = constants.switches[chip.switch]
  # Keys of arrays are given as strings, so we need to convert them back to numbers
  childNames = if chip.children? then (child.name ? parseInt(index)) for index, child of chip.children else []

  result = new RW.ChipVisitorResult()
  RW.transformersLogger = RW.makeLogFunction(circuitMeta, path, result)

  evaluationContext = RW.makeEvaluationContext(circuitMeta, constants, circuitData, scratchData, bindings)
  RW.fillPinDefDefaults(switchChip.pinDefs)
  try
    evaluatedPins = RW.evaluateInputPinExpressions(circuitMeta, path, constants, evaluationContext, switchChip.pinDefs, chip.pins)
  catch e
    result.signal = RW.signals.ERROR
    RW.transformersLogger(RW.logLevels.ERROR, "Evaluating input pin expressions raised an exception #{e}.\n#{RW.formatStackTrace(e)}")
    return result # Quit early

  # check which children should be activated
  activeChildren = null
  if "listActiveChildren" of switchChip
    try
      activeChildren = switchChip.listActiveChildren(evaluatedPins, childNames, constants.transformers, RW.transformersLogger, path)
      if not activeChildren? or not _.isArray(activeChildren) 
        throw RW.makeExecutionError("Calling listActiveChildren() on chip '#{chip.switch}' did not return an array", circuitMeta, path)
    catch e
      RW.transformersLogger(RW.logLevels.ERROR, "Calling switch #{chip.switch}.listActiveChildren raised an exception #{e}. Input pins were #{JSON.stringify(evaluatedPins)}. Children are #{JSON.stringify(childNames)}.\n#{RW.formatStackTrace(e)}")
      result.signal = RW.signals.ERROR
      return result # return early
 
  # By default, all children are considered active
  if activeChildren is null then activeChildren = _.range(childNames.length)
 
  # Continue with children
  childSignals = new Array(childNames.length)
  try
    for activeChildName in activeChildren
      childIndex = RW.indexOf(childNames, activeChildName)
      if childIndex is -1 then throw new RW.makeExecutionError("Switch referenced a child '#{activeChildName}' that doesn't exist", circuitMeta, path)
      childResult = RW.visitChip(circuitMeta, RW.appendToArray(path, childIndex.toString()), chip.children[childIndex], constants, circuitData, scratchData, bindings)
      childSignals[childIndex] = childResult.signal
      result.append(childResult)
  catch e
    # RW.transformersLogger may have been reset by visit to children
    RW.transformersLogger = RW.makeLogFunction(circuitMeta, path, result)
    RW.transformersLogger(RW.logLevels.ERROR, "Cannot run switch children.\n#{RW.formatStackTrace(e)}")
    result.signal = RW.signals.ERROR
    return result # return early

  # RW.transformersLogger may have been reset by visit to children
  RW.transformersLogger = RW.makeLogFunction(circuitMeta, path, result)

  # Handle signals
  if "handleSignals" of switchChip
    try
      signalsResult = switchChip.handleSignals(evaluatedPins, childNames, activeChildren, childSignals, constants.transformers, RW.transformersLogger)
      temporaryResult = new RW.ChipVisitorResult(signalsResult)

      RW.evaluateOutputPinExpressions(circuitMeta, path, constants, bindings, evaluationContext, result, switchChip.pinDefs, chip.pins, evaluatedPins)

      result.append(temporaryResult)
      result.signal = signalsResult # append() does not affect result
    catch
      RW.transformersLogger(RW.logLevels.ERROR, "Calling switch #{chip.switch}.handleSignals raised an exception #{e}. Input pins were #{JSON.stringify(evaluatedPins)}. Children are #{JSON.stringify(childNames)}.\n#{RW.formatStackTrace(e)}")
      result.signal = RW.signals.ERROR
      return result # return early

  return result

RW.visitSplitterChip = (circuitMeta, path, chip, constants, circuitData, scratchData, oldBindings) ->
  bindingSet = RW.calculateBindingSet(circuitMeta, path, chip, constants, circuitData, scratchData, oldBindings)
  result = new RW.ChipVisitorResult()
  for newBindings in bindingSet
    # Continue with children
    for childIndex, child of (chip.children or [])
      childResult = RW.visitChip(circuitMeta, RW.appendToArray(path, childIndex), child, constants, circuitData, scratchData, newBindings)
      result.append(childResult)
  return result

RW.visitEmitterChip = (circuitMeta, path, chip, constants, circuitData, scratchData, bindings) ->
  originalEvaluationContext = RW.makeEvaluationContext(circuitMeta, constants, circuitData, scratchData, bindings)

  # Make modifiedEvaluationContext by copying in just the dependencies for memory and io
  modifiedEvaluationContext = 
    memory: {}
    io: {}
    assets: constants.assets
    transformers: constants.transformers
    circuit: circuitData
    scratch: scratchData
    bindings: {}

  # All of the dependencies could be modified, so their parents are first cloned
  for dependencyPath in chip.emitter.dependencyPaths
    [originalParent, key] = RW.getParentAndKey(originalEvaluationContext, dependencyPath)
    RW.deepSet(modifiedEvaluationContext, dependencyPath, RW.cloneData(originalParent[key]))
  RW.setupBindings(modifiedEvaluationContext, bindings)

  # Return "DONE" signal, so it can be put in sequences
  result = new RW.ChipVisitorResult(RW.signals.DONE)  
  RW.transformersLogger = RW.makeLogFunction(circuitMeta, path, result)

  # Now call the function
  try
    expressionResult = RW.evaluateEmitterFunction(modifiedEvaluationContext, chip.emitter.expression)
    # TODO: return result as signal, or DONE if undefined 
  catch e
    result.signal = RW.signals.ERROR
    RW.transformersLogger(RW.logLevels.ERROR, "Error evaluating emitter chip.\n#{RW.formatStackTrace(e)}")
    return result # Quit early

  # Finally, detect the differences between the modified context and the original 
  for dependencyPath in chip.emitter.dependencyPaths 
    [parent, key] = RW.getParentAndKey(modifiedEvaluationContext, dependencyPath)
    RW.derivePatches(circuitMeta, path, bindings, originalEvaluationContext, result, RW.joinAddress(dependencyPath), parent[key])
  
  return result

RW.visitCircuitChip = (circuitMeta, path, chip, constants, parentCircuitData, scratchData, bindings) ->
  # Expect chip data like { circuit: circuitType, id: circuitId: , children: , pins: }
  # Look up chip
  circuit = constants.circuits[chip.circuit]

  # Prepare result and logger
  result = new RW.ChipVisitorResult()
  RW.transformersLogger = RW.makeLogFunction(circuitMeta, path, result)

  # Make circuitData for child, based on pins
  evaluationContext = RW.makeEvaluationContext(circuitMeta, constants, parentCircuitData, scratchData, bindings)
  try
    childCircuitData = RW.evaluateInputPinExpressions(circuitMeta, path, constants, evaluationContext, circuit.pinDefs, chip.pins)
  catch e
    result.signal = RW.signals.ERROR
    RW.transformersLogger(RW.logLevels.ERROR, "Evaluating input pin expressions raised an exception #{e}.\n#{RW.formatStackTrace(e)}")
    return result # Quit early

  # Visit the chip itself
  childCircuitId = RW.makeCircuitId(circuitMeta.id, chip.id)
  childVisitorResult = RW.visitChip(new RW.CircuitMeta(childCircuitId, chip.circuit), [], circuit.board, constants, childCircuitData, scratchData, {})
  result.append(childVisitorResult)
  result.signal = childVisitorResult.signal

  # Build the new childCircuitData
  childCircuitPatches = childVisitorResult.getCircuitResults(childCircuitId).circuitPatches
  # Check for conflicts 
  conflicts = RW.detectPatchConflicts(childCircuitPatches)
  if conflicts.length > 0 then throw new Error("Memory patches conflict for circuit #{childCircuitId}:\n#{JSON.stringify(conflicts)}")

  # RW.transformersLogger may have been reset by visit to children
  RW.transformersLogger = RW.makeLogFunction(circuitMeta, path, result)

  try
    # Patch 
    newChildCircuitData = RW.applyPatches(childCircuitPatches, childCircuitData)
  catch e
    result.signal = RW.signals.ERROR
    RW.transformersLogger(RW.logLevels.ERROR, "Merging circuit data from #{childCircuitId} raised an exception #{e}.\n#{RW.formatStackTrace(e)}")

  try
    RW.evaluateOutputPinExpressions(circuitMeta, path, constants, bindings, evaluationContext, result, circuit.pinDefs, chip.pins, newChildCircuitData)
  catch e
    result.signal = RW.signals.ERROR
    RW.transformersLogger(RW.logLevels.ERROR, "Evaluating output pin expressions raised an exception #{e}. Input pins were #{JSON.stringify(evaluatedPins)}.\n#{RW.formatStackTrace(e)}")

  return result

RW.visitPipeChip = (circuitMeta, path, chip, constants, circuitData, oldScratchData, oldBindings) ->
  # Create new scratch data
  scratchKey = _.uniqueId("scratch")

  # Put new scratch data in an object to use applyPatches() later
  newScratchData = RW.addToObject(oldScratchData, scratchKey, null)

  # Create new bindings, pointing to the scratch data
  newBindings = Object.create(oldBindings)
  newBindings[chip.pipe.bindTo] = new RW.BindingReference("scratch.#{scratchKey}")

  # Prepare result and logger
  result = new RW.ChipVisitorResult()
  RW.transformersLogger = RW.makeLogFunction(circuitMeta, path, result)

  # Get the initial value
  newScratchData[scratchKey] = null
  if chip.pipe.initialValue
    evaluationContext = RW.makeEvaluationContext(circuitMeta, constants, circuitData, oldScratchData, oldBindings)
    try
      newScratchData[scratchKey] = RW.evaluateExpressionFunction(evaluationContext, chip.pipe.initialValue)
    catch e
      result.signal = RW.signals.ERROR
      RW.transformersLogger(RW.logLevels.ERROR, "Error executing the input value '#{chip.pipe.initialValue}' for pipe chip chip.\n#{RW.formatStackTrace(e)}")
      return result # Quit early

  for childIndex, child of chip.children
    # Visit the child
    childVisitorResult = RW.visitChip(circuitMeta, RW.appendToArray(path, childIndex.toString()), chip.children[childIndex], constants, circuitData, newScratchData, newBindings)

    # Apply patches to the scratch key and remove them from the result
    circuitResults = childVisitorResult.getCircuitResults(circuitMeta.id)
    groupedScratchPatches = _.groupBy circuitResults.scratchPatches, (patch) -> 
      if RW.startsWith(RW.getPatchDestination(patch), "/#{scratchKey}") then "mine" else "others" 

    # Check for conflicts 
    conflicts = RW.detectPatchConflicts(groupedScratchPatches.mine)
    if conflicts.length > 0 
      result.signal = RW.signals.ERROR
      RW.transformersLogger(RW.logLevels.ERROR, "Pipe patches conflict:\n#{JSON.stringify(conflicts)}")
      return result # Quit early

    # RW.transformersLogger may have been reset by visit to children
    RW.transformersLogger = RW.makeLogFunction(circuitMeta, path, result)

    # Patch 
    try
      newScratchData = RW.applyPatches(groupedScratchPatches.mine, newScratchData)
    catch e
      result.signal = RW.signals.ERROR
      RW.transformersLogger(RW.logLevels.ERROR, "Merging pipe data raised an exception #{e}.\n#{RW.formatStackTrace(e)}")
      return result # Quit early

    # Keep the remaining scratch patches
    childVisitorResult.scratchPatches = groupedScratchPatches.other
    result.append(childVisitorResult)
    result.signal = childVisitorResult.signal

  # Store the results
  if chip.pipe.outputDestination
    evaluationContext = RW.makeEvaluationContext(circuitMeta, constants, circuitData, newScratchData, newBindings)
    RW.derivePatches(circuitMeta, path, newBindings, evaluationContext, result, chip.pipe.outputDestination, newScratchData[scratchKey])

  return result

RW.chipVisitors =
  "processor": RW.visitProcessorChip
  "switch": RW.visitSwitchChip
  "splitter": RW.visitSplitterChip
  "emitter": RW.visitEmitterChip
  "circuit": RW.visitCircuitChip
  "pipe": RW.visitPipeChip

# The path is an array of the indices necessary to access the children
RW.visitChip = (circuitMeta, path, chip, constants, circuitData, scratchData, bindings) ->
  # TODO: defer processor and call execution until whole tree is evaluated?
  if chip.muted then return new RW.ChipVisitorResult()

  result = null

  # Dispatch to correct function
  for chipType, visitor of RW.chipVisitors
    if chipType of chip
      result = visitor(circuitMeta, path, chip, constants, circuitData, scratchData, bindings)
      break

  if result == null
    # Signal error
    result = new RW.ChipVisitorResult()
    result.getCircuitResults(circuitMeta.id).logMessages.push
      path: path
      circuitMeta: circuitMeta
      level: RW.logLevels.ERROR
      message: ["Board item '#{JSON.stringify(chip)}' is not understood"]

  result.getCircuitResults(circuitMeta.id).activeChipPaths.push(path)
  return result

# Starts the RW.visitChip() recursive chain with the starting parameters
RW.stimulateCircuits = (constants) -> RW.visitChip(new RW.CircuitMeta("main", "main"), [], constants.circuits.main.board, constants, {}, {}, {})

# The argument "options" can values for "circuits", "processors", "switches", "transformers", "circuitMetas", "memoryData", "ioData", "inputIoData", "outputIoData", and "establishOutput". 
# circuits is a map of a circuit names to RW.Circuit objects.
# By default, checks the io object for input data, visits the tree given in chip, and then provides output data to io.
# If outputIoData is not null, the loop is not stepped, and the data is sent directly to the io. In this case, no memory patches are returned.
# Otherwise, if inputIoData is not null, this data is used instead of asking the io.
# The memoryData and inputIoData parametersshould be frozen with RW.deepFreeze() before being sent.
# Rather than throwing errors, this function attempts to trap errors internally and return them as an "errors" attribute.
# The errors have a "stage" attribute that is "readIo", "executeChips", "patchMemory", "patchIo", and "writeIo"
# Returns a map like { memoryPatches: , inputIoData: , ioPatches: , logMessages: }
RW.stepLoop = (options) ->  
  makeErrorResponse = (stage, err) -> 
    console.error("ERROR IN STEP LOOP", stage, err)
    # Some Firefox errors have name, filename, lineNumber, and columnNumber 
    errorDescription = 
      stage: stage
      message: err.message || err.name
      path: err.path 
      stack: RW.formatStackTrace(err)
    return { errors: [errorDescription], memoryPatches: memoryPatches, inputIoData: options.inputIoData, ioPatches: ioPatches, logMessages: logMessages }

  _.defaults options, 
    circuits: 
      main: new RW.Circuit()
    circuitMetas: [new RW.CircuitMeta("main", "main")]
    processors: {}
    switches: {}
    transformers: {}
    assets: {}
    memoryData: {}
    io: {}
    inputIoData: null
    outputIoData: null 
    establishOutput: true

  # Initialize return data
  memoryPatches = {}
  ioPatches = {}
  logMessages = {}
  activeChipPaths = {}

  if options.outputIoData == null
    if options.inputIoData == null
      try
        inputIoDataByIoName = {}
        for ioName, io of options.io
          inputIoDataByIoName[ioName] = RW.cloneData(io.provideData())
        options.inputIoData = RW.reverseKeys(inputIoDataByIoName)
        # TODO: freeze options.inputIoData?
      catch e 
        return makeErrorResponse("readIo", e)

    # If any circuits are mising inputIoData, get it from the global
    # OPT: do this outside of stepLoop()
    preparedInputIoData = {}
    for circuitMeta in options.circuitMetas
      preparedInputIoData[circuitMeta.id] = options.inputIoData[circuitMeta.id] || options.inputIoData.global || {}
      for ioName of options.io
        if ioName not of preparedInputIoData[circuitMeta.id]
          preparedInputIoData[circuitMeta.id][ioName] = options.inputIoData.global[ioName]

    try
      result = RW.stimulateCircuits new RW.ChipVisitorConstants
        memoryData: options.memoryData
        processors: options.processors
        switches: options.switches
        transformers: options.transformers
        assets: options.assets
        ioData: preparedInputIoData
        circuits: options.circuits

      # If any circuits don't have results, add in empty results there
      for circuitMeta in options.circuitMetas then result.getCircuitResults(circuitMeta.id)
    catch e 
      return makeErrorResponse("executeChips", e)

    try 
      for circuitMeta in options.circuitMetas
        conflicts = RW.detectPatchConflicts(result.circuitResults[circuitMeta.id].memoryPatches)
        if conflicts.length > 0 then throw new Error("Memory patches conflict for circuit #{circuitMeta.id}: #{JSON.stringify(conflicts)}")
        memoryPatches[circuitMeta.id] = result.circuitResults[circuitMeta.id].memoryPatches
    catch e 
      return makeErrorResponse("patchMemory", e)

    try
      options.outputIoData = {}

      for circuitMeta in options.circuitMetas
        conflicts = RW.detectPatchConflicts(result.circuitResults[circuitMeta.id].ioPatches)
        if conflicts.length > 0 then throw new Error("IO patches conflict for circuit #{circuitMeta.id}: #{JSON.stringify(conflicts)}")
        ioPatches[circuitMeta.id] = result.circuitResults[circuitMeta.id].ioPatches
        options.outputIoData[circuitMeta.id] = RW.applyPatches(result.circuitResults[circuitMeta.id].ioPatches, preparedInputIoData[circuitMeta.id])
    catch e 
      return makeErrorResponse("patchIo", e)

    logMessages = RW.pluckToObject(result.circuitResults, "logMessages")
    activeChipPaths = RW.pluckToObject(result.circuitResults, "activeChipPaths")

  # TODO: check the output even if isn't established, in order to catch errors
  if options.establishOutput
    # Additional data that will be sent to IO services
    additionalData = 
      memoryData: options.memoryData
      memoryPatches: options.memoryPatches
      inputIoData: options.inputIoData
      ioPatches: ioPatches
      logMessages: logMessages

    try
      # outputIoData is keyed by circuit, we need it by io name
      outputIoDataByIoName = RW.reverseKeys(options.outputIoData)
      for ioName, io of options.io
        io.establishData(outputIoDataByIoName[ioName], additionalData)
    catch e 
      return makeErrorResponse("writeIo", e)

  return { 
    memoryPatches: memoryPatches
    inputIoData: options.inputIoData
    ioPatches: ioPatches
    logMessages: logMessages
    activeChipPaths: activeChipPaths
  }

# Compile expression source into sandboxed function of (memory, io, assets, transformers, bindings, pins) 
RW.compileExpression = (expressionText, evaluator) -> RW.compileSource("return #{expressionText};", evaluator, ["memory", "io", "assets", "transformers", "circuit", "bindings", "pins"])

# Compile expression source into sandboxed function of (memory, io, assets, transformers, bindings, pins) 
RW.compileEmitter = (expressionText, evaluator) -> RW.compileSource(expressionText, evaluator, ["memory", "io", "assets", "transformers", "circuit", "bindings"])

# Compile transformer source into a function of an "context" object that generates the transformers function,
# baking in the "transformers" pin expression of "context".
RW.compileTransformer = (expressionText, args, evaluator) -> 
  source = """
    return function(#{args.join(', ')}) { 
      var transformers = context.transformers; 
      var log = RW.transformersLogger; 
      #{expressionText} 
    };
  """
  return RW.compileSource(source, evaluator, ["context"])

# Compile processor.update() source into sandboxed function of (pins, assets, transformers, log,) 
RW.compileUpdate = (expressionText, evaluator) -> RW.compileSource(expressionText, evaluator, ["pins", "assets", "transformers", "log"])

# Compile processor listActiveChildren source into sandboxed function of (pins, children, transformers, log) 
RW.compileListActiveChildren = (expressionText, evaluator) -> RW.compileSource(expressionText, evaluator, ["pins", "children", "transformers", "log"])

# Compile processor handleSignals source into sandboxed function of (pins, children, activeChildren, signals, transformers, log) 
RW.compileHandleSignals = (expressionText, evaluator) -> RW.compileSource(expressionText, evaluator, ["pins", "children", "activeChildren", "signals", "transformers", "log"])

# Compile source into sandboxed function of parameters
RW.compileSource = (expressionText, evaluator, parameters) ->
  # Parentheses are needed around function because of strange JavaScript syntax rules
  # TODO: use "new Function" instead of eval? 
  # TODO: add "use strict"?
  # TODO: detect errors
  functionText = "(function(#{parameters.join(', ')}) {\n#{expressionText}\n})"
  expressionFunc = evaluator(functionText)
  if typeof(expressionFunc) isnt "function" then throw new Error("Expression does not evaluate as a function") 
  return expressionFunc

# Uses the RW.extensions map to find the corresponding type for the given filename 
# Else returns null
RW.determineAssetType = (url) ->
  extension = url.slice(url.lastIndexOf(".") + 1)
  for type, extensions of RW.extensions
    if extension in extensions then return type
  return null

# Returns a function that adds log messages to the result with the given path
RW.makeLogFunction = (circuitMeta, path, result) ->
  logFunction = (args...) ->
    if args.length == 0 then throw new Error("Log function requires one or more arguments")
 
    result.getCircuitResults(circuitMeta.id).logMessages.push
      path: path
      level: args[0]
      message: args[1..]
  # Create shortcut functions   
  logFunction.info = (args...) -> logFunction(RW.logLevels.INFO, args...)
  logFunction.warn = (args...) -> logFunction(RW.logLevels.WARN, args...)  
  logFunction.error = (args...) -> logFunction(RW.logLevels.ERROR, args...)  
  return logFunction

# Split address like "a.b[1].2" into ["a", "b", 1, 2]
RW.splitAddress = (address) -> _.reject(address.split(/[\.\[\]]/), (part) -> part is "")

# Join address like ["a", "b", 1, 2] into "a.b.1.2" 
RW.joinAddress = (address) -> address.join(".")

# Combine a path like ["a", "b", 1, 2] into "a/b/1/2
RW.joinPathParts = (pathParts) -> "/#{pathParts.join('/')}"

# Wrapper around RW.applyPatches to allow it apply patches within circuits
RW.applyPatchesInCircuits = (patches, data) ->
  RW.mapObject data, (circuitData, circuitId) ->
    if patches[circuitId] then RW.applyPatches(patches[circuitId], circuitData) else circuitData

# Find all references to memory and io
RW.findFunctionDependencies = (functionText, references) ->
  r = /(memory|io).(\w+)|(memory|io)\[["'](\w*)["']\]/g
  loop
    match = r.exec(code)
    if not match then break
    references.push({ transformer: match[1] || match[2] })
  return references 
