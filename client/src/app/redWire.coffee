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
      assets: {}
      processors: {}
      switches: {}
      transformers: {}

RW.ChipVisitorConstants = class 
  constructor: (options) -> 
    _.defaults this, options,
      circuits: 
        main: new RW.Circuit()
      memoryData: {} # Map of circuitIds to data
      ioData: {} # Map of circuitIds to data
      evaluator: null

RW.CircuitMeta = class
  constructor: (@id, @type) -> 

RW.CircuitResult = class 
  constructor: (options) -> 
    _.defaults this, options,
      memoryPatches: []
      ioPatches: []
      logMessages: []

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
        for attr in ["memoryPatches", "ioPatches", "logMessages"]
          @circuitResults[circuitId][attr] = @circuitResults[circuitId][attr].concat(other.circuitResults[circuitId][attr])

# Class used just to "tag" a string as being a reference rather than a JSON value
RW.BindingReference = class 
  constructor: (@ref) ->

# Used to evaluate expressions against with RW.evaluateExpressionFunction
RW.makeEvaluationContext = (circuitMeta, constants, bindings) ->
  context = 
    memory: constants.memoryData[circuitMeta.id]
    io: constants.ioData[circuitMeta.id]
    assets: constants.circuits[circuitMeta.type].assets
    transformers: constants.circuits[circuitMeta.type].transformers
    bindings: {}
  # Setup bindings
  for bindingName, bindingValue of bindings
    if bindingValue instanceof RW.BindingReference
      [parent, key] = RW.getParentAndKey(context, RW.splitAddress(bindingValue.ref))
      context.bindings[bindingName] = parent[key]
    else
      context.bindings[bindingName] = bindingValue
  return context

# context is created with RW.makeEvaluationContext()
# pins are optional
RW.evaluateExpressionFunction = (context, f, pins) ->
  f(context.memory, context.io, context.assets, context.transformers, context.bindings, pins)

# Returns address as array (like pathParts) with binding refs replaced with their full addresses (to memory or io) 
RW.resolveBindingAddresses = (bindings, pathParts) ->
  if pathParts[0] in ["memory", "io"] then return pathParts
  if pathParts[0] is "bindings"
    bindingValue = bindings[pathParts[1]]
    if bindingValue instanceof RW.BindingReference
      replacedAddress = RW.splitAddress(bindingValue.ref).concat(pathParts[2..])
      return RW.resolveBindingAddresses(bindings, replacedAddress)
    else
      throw new Error("Cannot write to constant bindings such as '#{JSON.stringify(bindingValue)}'")
  else throw new Error("Cannot resolve address '#{RW.joinPathParts(pathParts)}'")

# Reject arrays as objects
RW.isOnlyObject = (o) -> return _.isObject(o) and not _.isArray(o)

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
    RW.deepSet(root[pathParts[0]], _.rest(pathParts))
  return root

# Compare new object and old object to create list of patches.
# The top-level oldValue must be an object
# Using JSON patch format @ http://tools.ietf.org/html/draft-pbryan-json-patch-04
# TODO: handle arrays
# TODO: handle escape syntax
RW.makePatches = (oldValue, newValue, path = null, prefix = "", patches = []) ->
  if _.isEqual(newValue, oldValue) then return patches

  if oldValue is undefined
    patches.push { add: prefix, value: newValue, path: path }
  else if newValue is undefined 
    patches.push { remove: prefix, path: path }
  else if not _.isObject(newValue) or not _.isObject(oldValue) or typeof(oldValue) != typeof(newValue)
    patches.push { replace: prefix, value: newValue, path: path }
  else if _.isArray(oldValue) and oldValue.length != newValue.length
    # In the case that we modified an array, we need to replace the whole thing  
    patches.push { replace: prefix, value: newValue, path: path }
  else 
    # both elements are objects or arrays
    keys = _.union(_.keys(oldValue), _.keys(newValue))
    RW.makePatches(oldValue[key], newValue[key], path, "#{prefix}/#{key}", patches) for key in keys

  return patches

# Takes an oldValue and list of patches and creates a new value
# The top-level oldValue must be an object
# Using JSON patch format @ http://tools.ietf.org/html/draft-pbryan-json-patch-04
# TODO: handle arrays
# TODO: handle escape syntax
RW.applyPatches = (patches, oldValue, prefix = "") ->
  splitPath = (path) -> _.rest(path.split("/"))

  value = RW.cloneData(oldValue)

  for patch in patches
    if "remove" of patch
      [parent, key] = RW.getParentAndKey(value, splitPath(patch.remove))
      delete parent[key]
    else if "add" of patch
      [parent, key] = RW.getParentAndKey(value, splitPath(patch.add))
      if _.isArray(parent) then parent.splice(key, 0, patch.value)
      else parent[key] = patch.value # For object
    else if "replace" of patch
      [parent, key] = RW.getParentAndKey(value, splitPath(patch.replace))
      if key not of parent then throw new Error("No existing value to replace for patch #{patch}")
      parent[key] = patch.value

  return value

# Returns information about patches that affect the same key
RW.detectPatchConflicts = (patches) ->
  # First, mark what patches affect what keys. 
  # Set all patches that affect a certain key to the index of that patch in the list
  affectedKeys = {} 
  for index, patch of patches
    path = patch.remove or patch.add or patch.replace
    pathParts = _.rest(path.split("/"))

    # Go down the keys in the patch, created objects under affectedKeys as necessary
    parent = affectedKeys
    for pathPart in pathParts
      if pathPart not of parent then parent[pathPart] = { }
      parent = parent[pathPart]

    # "parent" is now the last parent
    if "__patchIndexes__" not of parent then parent.__patchIndexes__ = []
    parent.__patchIndexes__.push(index)

  # Find child 
  findChildPatchIndexes = (obj) ->
    childIndexes = []
    for key, value of obj when key isnt "__patchIndexes__"
      if value.__patchIndexes__ 
        childIndexes = RW.concatenate(childIndexes, value.__patchIndexes__)
      childIndexes = RW.concatenate(childIndexes, findChildPatchIndexes(value))
    return childIndexes

  detectConflicts = (obj, prefix = "") ->
    conflicts = []
    if obj.__patchIndexes__
      # Can't have more than one patch modifying a value
      if obj.__patchIndexes__.length > 1 
        conflicts.push
          path: prefix
          patches: (patches[index] for index in obj.__patchIndexes__)

      # No child values should be modified
      for patchIndexes in findChildPatchIndexes(obj)
        allPatchIndexes = RW.concatenate(obj.__patchIndexes__, patchIndexes) 
        conflicts.push
          path: prefix
          patches: (patches[index] for index in allPatchIndexes)
    else
      # Recurse, looking for patches
      for key, value of obj 
        conflicts = RW.concatenate(conflicts, detectConflicts(value, "#{prefix}/#{key}"))

    return conflicts

  return detectConflicts(affectedKeys)

# Creates a patch to the outputAddress of the given outputValue and appends it to the result
# TODO: what an unweildy function, with more parameters than lines! Need to refactor it somehow
RW.derivePatches = (circuitMeta, path, bindings, evaluationContext, result, outputAddress, outputValue) -> 
  pathParts = RW.resolveBindingAddresses(bindings, RW.splitAddress(outputAddress))
  # Get the original value to compare the output against
  [parent, key] = RW.getParentAndKey(evaluationContext, pathParts)
  # Find which list to apply patches to (memory or io)
  destinationList = if pathParts[0] is "memory" then result.getCircuitResults(circuitMeta.id).memoryPatches else result.getCircuitResults(circuitMeta.id).ioPatches
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
      throw RW.makeExecutionError("Missing input pin expression function for pin '#{pinName}'", ciruitMeta, path)
    
    try
      # Get the value
      evaluatedPins[pinName] = RW.evaluateExpressionFunction(evaluationContext, pinFunction)
      
      # Protect inout pins from changing buffer values directly by cloning the data
      if pinOptions.direction is "inout"
        evaluatedPins[pinName] = RW.cloneData(evaluatedPins[pinName]) 
    catch error
      throw RW.makeExecutionError("Error evaluating the input pin expression expression '#{pinFunction}' for pin '#{pinName}': #{RW.formatStackTrace(error)}", ciruitMeta, path)
  return evaluatedPins

# Updates the evaluation context by evaluating the output pin expressions
# pinFunctions is an object that contains 'in' and 'out' attributes
RW.evaluateOutputPinExpressions = (circuitMeta, path, constants, bindings, evaluationContext, result, pinDefs, pinFunctions, evaluatedPins) ->
  for pinName, pinFunction of pinFunctions?.out
    try
      outputValue = RW.evaluateExpressionFunction(evaluationContext, pinFunction, evaluatedPins)
    catch error
      throw RW.makeExecutionError("Error evaluating the output pin expression '#{pinFunction}' for pin '#{pinName}': #{RW.formatStackTrace(error)}\nPin values were #{JSON.stringify(evaluatedPins)}.", ciruitMeta, path)

    RW.derivePatches(circuitMeta, path, bindings, evaluationContext, result, pinName, outputValue)

RW.calculateBindingSet = (circuitMeta, path, chip, constants, oldBindings) ->
  bindingSet = []

  # If expression is a JSON object (which includes arrays) then loop over the values. Otherwise make references to memory and io
  if _.isObject(chip.splitter.from)
    for key, value of chip.splitter.from
      # Avoid polluting old object, and avoid creating new properties
      newBindings = Object.create(oldBindings)
      newBindings[chip.splitter.bindTo] = value
      if chip.splitter.index? then newBindings["#{chip.splitter.index}"] = key

      if chip.splitter.where?
        evaluationContext = RW.makeEvaluationContext(circuitMeta, constants, newBindings)

        try
          # If the where clause evaluates to false, don't add it
          if RW.evaluateExpressionFunction(evaluationContext, chip.splitter.where) then bindingSet.push(newBindings)
        catch error
          throw RW.makeExecutionError("Error evaluating the where expression '#{chip.splitter.where}' for splitter chip '#{chip}': #{RW.formatStackTrace(error)}", ciruitMeta, path)
      else
        bindingSet.push(newBindings)
  else if _.isString(chip.splitter.from)
    inputContext = 
      memory: constants.memoryData[circuitMeta.id]
      io: constants.ioData[circuitMeta.id]

    [parent, key] = RW.getParentAndKey(inputContext, RW.splitAddress(chip.splitter.from))
    boundValue = parent[key]

    for key of boundValue
      # Avoid polluting old object, and avoid creating new properties
      newBindings = Object.create(oldBindings)
      newBindings[chip.splitter.bindTo] = new RW.BindingReference("#{chip.splitter.from}.#{key}")
      if chip.splitter.index? then newBindings["#{chip.splitter.index}"] = key

      if chip.splitter.where?
        # TODO: compile expressions ahead of time
        evaluationContext = RW.makeEvaluationContext(circuitMeta, constants, newBindings)
        try
          # If the where clause evaluates to false, don't add it
          if RW.evaluateExpressionFunction(evaluationContext, chip.splitter.where) then bindingSet.push(newBindings)
        catch error
          throw RW.makeExecutionError("Error evaluating the where expression '#{chip.splitter.where}' for splitter chip '#{chip}': #{RW.formatStackTrace(error)}", ciruitMeta, path)
      else
        bindingSet.push(newBindings)
  else
    throw new Error("Splitter 'from' must be string or a JSON object")

  return bindingSet

RW.visitProcessorChip = (circuitMeta, path, chip, constants, bindings) ->
  if chip.processor not of constants.circuits[circuitMeta.type].processors then throw RW.makeExecutionError("Cannot find processor '#{chip.processor}'", ciruitMeta, path)

  processor = constants.circuits[circuitMeta.type].processors[chip.processor]

  result = new RW.ChipVisitorResult()
  RW.transformersLogger = RW.makeLogFunction(circuitMeta, path, result)

  evaluationContext = RW.makeEvaluationContext(circuitMeta, constants, bindings)
  RW.fillPinDefDefaults(processor.pinDefs)
  evaluatedPins = RW.evaluateInputPinExpressions(circuitMeta, path, constants, evaluationContext, processor.pinDefs, chip.pins)

  try
    result.signal = processor.update(evaluatedPins, constants.circuits[circuitMeta.id].transformers, RW.transformersLogger)
    RW.evaluateOutputPinExpressions(circuitMeta, path, constants, bindings, evaluationContext, result, processor.pinDefs, chip.pins, evaluatedPins)
  catch e
    result.signal = RW.signals.ERROR
    RW.transformersLogger(RW.logLevels.ERROR, "Calling processor #{chip.processor}.update raised an exception #{e}. Input pins were #{JSON.stringify(evaluatedPins)}.\n#{RW.formatStackTrace(e)}")

  return result

RW.visitSwitchChip = (circuitMeta, path, chip, constants, bindings) ->
  if chip.switch not of constants.circuits[circuitMeta.type].switches then throw RW.makeExecutionError("Cannot find switch '#{chip.switch}'", circuitMeta, path)

  switchChip = constants.circuits[circuitMeta.type].switches[chip.switch]
  # Keys of arrays are given as strings, so we need to convert them back to numbers
  childNames = if chip.children? then (child.name ? parseInt(index)) for index, child of chip.children else []

  result = new RW.ChipVisitorResult()
  RW.transformersLogger = RW.makeLogFunction(circuitMeta, path, result)

  evaluationContext = new RW.makeEvaluationContext(circuitMeta, constants, bindings)
  RW.fillPinDefDefaults(switchChip.pinDefs)
  evaluatedPins = RW.evaluateInputPinExpressions(circuitMeta, path, constants, evaluationContext, switchChip.pinDefs, chip.pins)

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
      if childIndex is -1 then throw new RW.makeExecutionError("Switch referenced a child '#{activeChildName}' that doesn't exist", ciruitMeta, path)
      childResult = RW.visitChip(circuitMeta, RW.appendToArray(path, childIndex.toString()), chip.children[childIndex], constants, bindings)
      childSignals[childIndex] = childResult.signal
      result.append(childResult)
  catch e
    RW.transformersLogger(RW.logLevels.ERROR, "Cannot run switch children.\n#{RW.formatStackTrace(e)}")
    result.signal = RW.signals.ERROR
    return result # return early

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

RW.visitSplitterChip = (circuitMeta, path, chip, constants, oldBindings) ->
  bindingSet = RW.calculateBindingSet(circuitMeta, path, chip, constants, oldBindings)
  result = new RW.ChipVisitorResult()
  for newBindings in bindingSet
    # Continue with children
    for childIndex, child of (chip.children or [])
      childResult = RW.visitChip(circuitMeta, RW.appendToArray(path, childIndex), child, constants, newBindings)
      result.append(childResult)
  return result

RW.visitEmitterChip = (circuitMeta, path, chip, constants, bindings) ->
  evaluationContext = RW.makeEvaluationContext(circuitMeta, constants, bindings)

  # Return "DONE" signal, so it can be put in sequences
  result = new RW.ChipVisitorResult(RW.signals.DONE)  
  RW.transformersLogger = RW.makeLogFunction(circuitMeta, path, result)

  for dest, expressionFunction of chip.emitter  
    try
      outputValue = RW.evaluateExpressionFunction(evaluationContext, expressionFunction)
    catch error
      throw RW.makeExecutionError("Error executing the output pin expression '#{expressionFunction}' --> '#{dest}' for emitter chip: #{RW.formatStackTrace(error)}", ciruitMeta, path)

    RW.derivePatches(circuitMeta, path, bindings, evaluationContext, result, dest, outputValue)
  
  return result

RW.visitCircuitChip = (circuitMeta, path, chip, constants, bindings) ->
  # Expect data like { circuit: circuitType, id: circuitId: , children: , pins: }
  # Look up chip
  circuit = constants.circuits[chip.circuit]
  # TODO: continue to visit children
  # TODO: handle parameters for circuit
  return RW.visitChip(new RW.CircuitMeta(chip.id, chip.circuit), [], circuit.board, constants, {})

RW.chipVisitors =
  "processor": RW.visitProcessorChip
  "switch": RW.visitSwitchChip
  "splitter": RW.visitSplitterChip
  "emitter": RW.visitEmitterChip
  "circuit": RW.visitCircuitChip

# The path is an array of the indices necessary to access the children
RW.visitChip = (circuitMeta, path, chip, constants, bindings = {}) ->
  # TODO: defer processor and call execution until whole tree is evaluated?
  if chip.muted then return new RW.ChipVisitorResult()

  # Dispatch to correct function
  for chipType, visitor of RW.chipVisitors
    if chipType of chip
      return visitor(circuitMeta, path, chip, constants, bindings)

  # Signal error
  result = new RW.ChipVisitorResult()
  result.getCircuitResults(circuitMeta.id).logMessages.push
    path: path
    circuitMeta: circuitMeta
    level: RW.logLevels.ERROR
    message: ["Board item '#{JSON.stringify(chip)}' is not understood"]
  return result

# Starts the RW.visitChip() recursive chain with the starting parameters
RW.stimulateCircuits = (constants) -> RW.visitChip(new RW.CircuitMeta("main", "main"), [], constants.circuits.main.board, constants, {})

# The argument "options" can values for "circuits", "memoryData", "ioData", "evaluator", "inputIoData", "outputIoData", and "establishOutput". 
# circuits is a map of a circuit names to RW.Circuit objects.
# By default, checks the io object for input data, visits the tree given in chip, and then provides output data to io.
# If outputIoData is not null, the loop is not stepped, and the data is sent directly to the io. In this case, no memory patches are returned.
# Otherwise, if inputIoData is not null, this data is used instead of asking the io.
# The memoryData and inputIoData parametersshould be frozen with RW.deepFreeze() before being sent.
# Rather than throwing errors, this function attempts to trap errors internally and return them as an "errors" attribute.
# The errors have a "stage" attribute that is "readIo", "executeChips", "patchMemory", "patchIo", and "writeIo"
# Returns a map of circuit IDs to RW.CircuitResult objects
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
    memoryData: {}
    io: {}
    evaluator: eval
    inputIoData: null
    outputIoData: null 
    establishOutput: true

  # OPT: circuitIds could be provided as input rather than calculated here
  circuitIds = RW.findCircuitIds(options.circuits)
  assetsByCircuit = RW.pluckToObject(options.circuits, "assets")

  # Initialize return data
  memoryPatches = {}
  ioPatches = {}
  logMessages = {}

  if options.outputIoData == null
    if options.inputIoData == null
      try
        inputIoDataByIoName = {}
        for ioName, io of options.io
          inputIoDataByIoName[ioName] = RW.cloneData(io.provideData(assetsByCircuit))
        options.inputIoData = RW.reverseKeys(inputIoDataByIoName)
      catch e 
        return makeErrorResponse("readIo", e)

    try
      result = RW.stimulateCircuits new RW.ChipVisitorConstants
        memoryData: options.memoryData
        ioData: options.inputIoData
        circuits: options.circuits
        evaluator: options.evaluator
    catch e 
      return makeErrorResponse("executeChips", e)

    try 
      for circuitId in circuitIds
        conflicts = RW.detectPatchConflicts(result.circuitResults[circuitId].memoryPatches)
        if conflicts.length > 0 then throw new Error("Memory patches conflict for circuit #{circuitId}: #{JSON.stringify(conflicts)}")
        memoryPatches[circuitId] = result.circuitResults[circuitId].memoryPatches
    catch e 
      return makeErrorResponse("patchMemory", e)

    try
      options.outputIoData = {}

      for circuitId in circuitIds
        conflicts = RW.detectPatchConflicts(result.circuitResults[circuitId].ioPatches)
        if conflicts.length > 0 then throw new Error("IO patches conflict for circuit #{circuitId}: #{JSON.stringify(conflicts)}")
        ioPatches[circuitId] = result.circuitResults[circuitId].ioPatches
        options.outputIoData[circuitId] = RW.applyPatches(result.circuitResults[circuitId].ioPatches, options.inputIoData[circuitId])
    catch e 
      return makeErrorResponse("patchIo", e)

    logMessages = RW.pluckToObject(result.circuitResults, "logMessages")

  # TODO: check the output even if isn't established, in order to catch errors
  if options.establishOutput
    try
      # outputIoData is keyed by circuit, we need it by io name
      outputIoDataByIoName = RW.reverseKeys(options.outputIoData)
      for ioName, io of options.io
        io.establishData(outputIoDataByIoName[ioName], assetsByCircuit)
    catch e 
      return makeErrorResponse("writeIo", e)

  return { memoryPatches: memoryPatches, inputIoData: options.inputIoData, ioPatches: ioPatches, logMessages: logMessages }

# Compile expression source into sandboxed function of (memory, io, assets, transformers, bindings, pins) 
RW.compileExpression = (expressionText, evaluator) -> RW.compileSource("return #{expressionText};", evaluator, ["memory", "io", "assets", "transformers", "bindings", "pins"])

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

# Compile processor.update() source into sandboxed function of (pins, transformers, log) 
RW.compileUpdate = (expressionText, evaluator) -> RW.compileSource(expressionText, evaluator, ["pins", "transformers", "log"])

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

# Combine a path like ["a", "b", 1, 2] into "a/b/1/2
RW.joinPathParts = (pathParts) -> "/#{pathParts.join('/')}"

# Search through the board, looking for all circuitIds that are 
RW.findCircuitIds = (circuits) -> 
  searchRecursive = (chip, circuitIds = []) -> 
    if "circuit" of chip 
      circuitIds.push(chip.id)
      searchRecursive(circuits[chip.circuit].board, circuitIds)
    if "children" of chip 
      for child in chip.children then searchRecursive(child, circuitIds)

  circuitIds = ["main"]
  searchRecursive(circuits.main.board, circuitIds)
  return circuitIds 
