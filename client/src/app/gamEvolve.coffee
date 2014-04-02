# Get alias for the global scope
globals = @

# All will be in the "GE" namespace
GE = globals.GE ? {}
globals.GE = GE

# The logFunction can be reset before visiting each chip that calls transformers
GE.transformersLogger = null

GE.ChipVisitorConstants = class 
  # Accepts options for "memoryData", "ioData", "assets", "processors", "transformers", and "evaluator"
  constructor: (options) -> 
    _.defaults this, options,
      memoryData: {}
      ioData: {}
      assets: {}
      processors: {}
      switches: {}
      transformers: {}
      evaluator: null

GE.ChipVisitorResult = class 
  constructor: (@result = null, @memoryPatches = [], @ioPatches = [], @logMessages = []) ->

  # Return new results with combination of this and other
  appendWith: (other) ->
    # Don't touch @result
    newMemoryPatches = GE.concatenate(@memoryPatches, other.memoryPatches)
    newIoPatches = GE.concatenate(@ioPatches, other.ioPatches)
    newLogMessages = GE.concatenate(@logMessages, other.logMessages)
    return new GE.ChipVisitorResult(@result, newMemoryPatches, newIoPatches, newLogMessages)

# Class used just to "tag" a string as being a reference rather than a JSON value
GE.BindingReference = class 
  constructor: (@ref) ->

GE.extensions =
  IMAGE: ["png", "gif", "jpeg", "jpg"]
  JS: ["js"]
  CSS: ["css"]
  HTML: ["html"]

# Used to evaluate expressions against with GE.evaluateExpressionFunction
GE.makeEvaluationContext = (constants, bindings) ->
  context = 
    memory: constants.memoryData
    io: constants.ioData
    bindings: {}
  for bindingName, bindingValue of bindings
    if bindingValue instanceof GE.BindingReference
      [parent, key] = GE.getParentAndKey(context, GE.splitAddress(bindingValue.ref))
      context.bindings[bindingName] = parent[key]
    else
      context.bindings[bindingName] = bindingValue
  return context

# context is created with GE.makeEvaluationContext()
# pins are optional
GE.evaluateExpressionFunction = (constants, context, f, pins) ->
  f(context.memory, context.io, constants.assets, constants.transformers, context.bindings, pins)

# Returns address as array (like pathParts) with binding refs replaced with their full addresses (to memory or io) 
GE.resolveBindingAddresses = (bindings, pathParts) ->
  if pathParts[0] in ["memory", "io"] then return pathParts
  if pathParts[0] is "bindings"
    bindingValue = bindings[pathParts[1]]
    if bindingValue instanceof GE.BindingReference
      replacedAddress = GE.splitAddress(bindingValue.ref).concat(pathParts[2..])
      return GE.resolveBindingAddresses(bindings, replacedAddress)
    else
      throw new Error("Cannot write to constant bindings such as '#{JSON.stringify(bindingValue)}'")
  else throw new Error("Cannot resolve address '#{GE.joinPathParts(pathParts)}'")

# Reject arrays as objects
GE.isOnlyObject = (o) -> return _.isObject(o) and not _.isArray(o)

# Returns an error, setting the path of the offending chip along the way
GE.makeExecutionError = (msg, path) -> 
  e = new Error(msg)
  e.path = path
  return e

# Sets a value within an embedded object or array, creating intermediate objects if necessary
# Takes a root object/array and the "path" as an array of keys
# Returns the root
GE.deepSet = (root, pathParts, value) ->
  if pathParts.length == 0 then throw new Exception("Path is empty")
  else if pathParts.length == 1 then root[pathParts[0]] = value
  else 
    # The intermediate key is missing, so create a new array for it
    if not root[pathParts[0]]? then root[pathParts[0]] = {}
    GE.deepSet(root[pathParts[0]], _.rest(pathParts))
  return root

# Compare new object and old object to create list of patches.
# The top-level oldValue must be an object
# Using JSON patch format @ http://tools.ietf.org/html/draft-pbryan-json-patch-04
# TODO: handle arrays
# TODO: handle escape syntax
GE.makePatches = (oldValue, newValue, path = null, prefix = "", patches = []) ->
  if _.isEqual(newValue, oldValue) then return patches

  if oldValue is undefined
    patches.push { add: prefix, value: GE.cloneData(newValue), path: path }
  else if newValue is undefined 
    patches.push { remove: prefix, path: path }
  else if not _.isObject(newValue) or not _.isObject(oldValue) or typeof(oldValue) != typeof(newValue)
    patches.push { replace: prefix, value: GE.cloneData(newValue), path: path }
  else if _.isArray(oldValue) and oldValue.length != newValue.length
    # In the case that we modified an array, we need to replace the whole thing  
    patches.push { replace: prefix, value: GE.cloneData(newValue), path: path }
  else 
    # both elements are objects or arrays
    keys = _.union(_.keys(oldValue), _.keys(newValue))
    GE.makePatches(oldValue[key], newValue[key], path, "#{prefix}/#{key}", patches) for key in keys

  return patches

# Takes an oldValue and list of patches and creates a new value
# The top-level oldValue must be an object
# Using JSON patch format @ http://tools.ietf.org/html/draft-pbryan-json-patch-04
# TODO: handle arrays
# TODO: handle escape syntax
GE.applyPatches = (patches, oldValue, prefix = "") ->
  splitPath = (path) -> _.rest(path.split("/"))

  value = GE.cloneData(oldValue)

  for patch in patches
    if "remove" of patch
      [parent, key] = GE.getParentAndKey(value, splitPath(patch.remove))
      delete parent[key]
    else if "add" of patch
      [parent, key] = GE.getParentAndKey(value, splitPath(patch.add))
      if _.isArray(parent) then parent.splice(key, 0, patch.value)
      else parent[key] = patch.value # For object
    else if "replace" of patch
      [parent, key] = GE.getParentAndKey(value, splitPath(patch.replace))
      if key not of parent then throw new Error("No existing value to replace for patch #{patch}")
      parent[key] = patch.value

  return value

# Returns information about patches that affect the same key
GE.detectPatchConflicts = (patches) ->
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
        childIndexes = GE.concatenate(childIndexes, value.__patchIndexes__)
      childIndexes = GE.concatenate(childIndexes, findChildPatchIndexes(value))
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
        allPatchIndexes = GE.concatenate(obj.__patchIndexes__, patchIndexes) 
        conflicts.push
          path: prefix
          patches: (patches[index] for index in allPatchIndexes)
    else
      # Recurse, looking for patches
      for key, value of obj 
        conflicts = GE.concatenate(conflicts, detectConflicts(value, "#{prefix}/#{key}"))

    return conflicts

  return detectConflicts(affectedKeys)

# Creates a patch to the outputAddress of the given outputValue and appends it to either memoryPatches or ioPatches
# TODO: what an unweildy function, with more parameters than lines! Need to refactor it somehow
GE.derivePatches = (bindings, path, evaluationContext, memoryPatches, ioPatches, outputAddress, outputValue) -> 
  pathParts = GE.resolveBindingAddresses(bindings, GE.splitAddress(outputAddress))
  # Get the original value to compare the output against
  [parent, key] = GE.getParentAndKey(evaluationContext, pathParts)
  # Find which list to apply patches to (memory or io)
  destinationList = if pathParts[0] is "memory" then memoryPatches else ioPatches
  # Drop "memory" or "io" off the prefix for patches
  prefix = GE.joinPathParts(pathParts[1..])
  # Obtain patches and append them to the destination list
  GE.makePatches(parent[key], outputValue, path, prefix, destinationList)

# Set default values in pinDefs
GE.fillPinDefDefaults = (pinDefs) ->
  # Cannot use normal "for key, value of" loop because cannot handle replace null values
  for pinName of pinDefs
    if not pinDefs[pinName]? then pinDefs[pinName] = {}
    _.defaults pinDefs[pinName], 
      direction: "in"
  return pinDefs

# Returns an object mapping pin expression names to their values 
# pinFunctions is an object that contains 'in' and 'out' attributes
GE.evaluateInputPinExpressions = (path, constants, evaluationContext, pinDefs, pinFunctions) ->
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
      throw GE.makeExecutionError("Missing input pin expression function for pin '#{pinName}'", path)
    
    try
      # Get the value
      evaluatedPins[pinName] = GE.evaluateExpressionFunction(constants, evaluationContext, pinFunction)
      
      # Protect inout pins from changing buffer values directly by cloning the data
      if pinOptions.direction is "inout"
        evaluatedPins[pinName] = GE.cloneData(evaluatedPins[pinName]) 
    catch error
      throw GE.makeExecutionError("Error evaluating the input pin expression expression '#{pinFunction}' for pin '#{pinName}': #{error.stack}", path)
  return evaluatedPins

# Updates the evaluation context by evaluating the output pin expressions
# pinFunctions is an object that contains 'in' and 'out' attributes
GE.evaluateOutputPinExpressions = (path, constants, bindings, evaluationContext, memoryPatches, ioPatches, pinDefs, pinFunctions, evaluatedPins) ->
  for pinName, pinFunction of pinFunctions?.out
    try
      outputValue = GE.evaluateExpressionFunction(constants, evaluationContext, pinFunction, evaluatedPins)
    catch error
      throw GE.makeExecutionError("Error evaluating the output pin expression '#{pinFunction}' for pin '#{pinName}': #{error.stack}\nPin values were #{JSON.stringify(evaluatedPins)}.", path)

    GE.derivePatches(bindings, path, evaluationContext, memoryPatches, ioPatches, pinName, outputValue)

GE.calculateBindingSet = (path, chip, constants, oldBindings) ->
  bindingSet = []

  # If expression is a JSON object (which includes arrays) then loop over the values. Otherwise make references to memory and io
  if _.isObject(chip.splitter.from)
    for key, value of chip.splitter.from
      # Avoid polluting old object, and avoid creating new properties
      newBindings = Object.create(oldBindings)
      newBindings[chip.splitter.bindTo] = value
      if chip.splitter.index? then newBindings["#{chip.splitter.index}"] = key

      if chip.splitter.where?
        evaluationContext = GE.makeEvaluationContext(constants, newBindings)

        try
          # If the where clause evaluates to false, don't add it
          if GE.evaluateExpressionFunction(constants, evaluationContext, chip.splitter.where) then bindingSet.push(newBindings)
        catch error
          throw GE.makeExecutionError("Error evaluating the where expression '#{chip.splitter.where}' for splitter chip '#{chip}': #{error.stack}", path)
      else
        bindingSet.push(newBindings)
  else if _.isString(chip.splitter.from)
    inputContext = 
      memory: GE.cloneData(constants.memoryData)
      io: GE.cloneData(constants.ioData)

    [parent, key] = GE.getParentAndKey(inputContext, GE.splitAddress(chip.splitter.from))
    boundValue = parent[key]

    for key of boundValue
      # Avoid polluting old object, and avoid creating new properties
      newBindings = Object.create(oldBindings)
      newBindings[chip.splitter.bindTo] = new GE.BindingReference("#{chip.splitter.from}.#{key}")
      if chip.splitter.index? then newBindings["#{chip.splitter.index}"] = key

      if chip.splitter.where?
        # TODO: compile expressions ahead of time
        evaluationContext = GE.makeEvaluationContext(constants, newBindings)
        try
          # If the where clause evaluates to false, don't add it
          if GE.evaluateExpressionFunction(constants, evaluationContext, chip.splitter.where) then bindingSet.push(newBindings)
        catch error
          throw GE.makeExecutionError("Error evaluating the where expression '#{chip.splitter.where}' for splitter chip '#{chip}': #{error.stack}", path)
      else
        bindingSet.push(newBindings)
  else
    throw new Error("Splitter 'from' must be string or a JSON object")

  return bindingSet

GE.visitProcessorChip = (path, chip, constants, bindings) ->
  if chip.processor not of constants.processors then throw GE.makeExecutionError("Cannot find processor '#{chip.processor}'", path)

  processor = constants.processors[chip.processor]

  result = new GE.ChipVisitorResult()
  GE.transformersLogger = GE.makeLogFunction(path, result.logMessages)

  evaluationContext = GE.makeEvaluationContext(constants, bindings)
  GE.fillPinDefDefaults(processor.pinDefs)
  evaluatedPins = GE.evaluateInputPinExpressions(path, constants, evaluationContext, processor.pinDefs, chip.pins)

  try
    methodResult = processor.update(evaluatedPins, constants.transformers, GE.transformersLogger)
  catch e
    # TODO: convert exceptions to error sigals that do not create patches
    GE.transformersLogger(GE.logLevels.ERROR, "Calling processor #{chip.processor}.update raised an exception #{e}. Input pins were #{JSON.stringify(evaluatedPins)}.\n#{e.stack}")

  result.result = methodResult
  GE.evaluateOutputPinExpressions(path, constants, bindings, evaluationContext, result.memoryPatches, result.ioPatches, processor.pinDefs, chip.pins, evaluatedPins)

  return result

GE.visitSwitchChip = (path, chip, constants, bindings) ->
  if chip.switch not of constants.switches then throw GE.makeExecutionError("Cannot find switch '#{chip.switch}'", path)

  switchChip = constants.switches[chip.switch]
  # Keys of arrays are given as strings, so we need to convert them back to numbers
  childNames = if chip.children? then (child.name ? parseInt(index)) for index, child of chip.children else []

  result = new GE.ChipVisitorResult()
  GE.transformersLogger = GE.makeLogFunction(path, result.logMessages)

  evaluationContext = new GE.makeEvaluationContext(constants, bindings)
  GE.fillPinDefDefaults(switchChip.pinDefs)
  evaluatedPins = GE.evaluateInputPinExpressions(path, constants, evaluationContext, switchChip.pinDefs, chip.pins)

  # check which children should be activated
  activeChildren = null
  if "listActiveChildren" of switchChip
    try
      activeChildren = switchChip.listActiveChildren(evaluatedPins, childNames, constants.transformers, GE.transformersLogger, path)
      if not activeChildren? or not _.isArray(activeChildren) 
        throw GE.makeExecutionError("Calling listActiveChildren() on chip '#{chip.switch}' did not return an array", path)
    catch e
      # TODO: convert exceptions to error sigals that do not create patches
      GE.transformersLogger(GE.logLevels.ERROR, "Calling switch #{chip.switch}.listActiveChildren raised an exception #{e}. Input pins were #{JSON.stringify(evaluatedPins)}. Children are #{JSON.stringify(childNames)}.\n#{e.stack}")
 
  # By default, all children are considered active
  if activeChildren is null then activeChildren = _.range(childNames.length)
 
  # Continue with children
  childSignals = new Array(childNames.length)
  for activeChildName in activeChildren
    childIndex = GE.indexOf(childNames, activeChildName)
    if childIndex is -1 then throw new GE.makeExecutionError("Switch referenced a child '#{activeChildName}' that doesn't exist", path)
    childResult = GE.visitChip(GE.appendToArray(path, childIndex.toString()), chip.children[childIndex], constants, bindings)
    childSignals[childIndex] = childResult.result
    result = result.appendWith(childResult)

  # Handle signals
  # TODO: if handler not defined, propogate error signals upwards? How to merge them?
  if "handleSignals" of switchChip
    try
      signalsResult = switchChip.handleSignals(evaluatedPins, childNames, activeChildren, childSignals, constants.transformers, GE.transformersLogger)
      temporaryResult = new GE.ChipVisitorResult(signalsResult)

      GE.evaluateOutputPinExpressions(path, constants, bindings, evaluationContext, result.memoryPatches, result.ioPatches, switchChip.pinDefs, chip.pins, evaluatedPins)

      result = result.appendWith(temporaryResult)
      result.result = signalsResult # appendWith() does not affect result
    catch e
      # TODO: convert exceptions to error sigals that do not create patches
      GE.transformersLogger(GE.logLevels.ERROR, "Calling switch #{chip.switch}.handleSignals raised an exception #{e}. Input pins were #{JSON.stringify(evaluatedPins)}. Children are #{JSON.stringify(childNames)}.\n#{e.stack}")

  return result

GE.visitSplitterChip = (path, chip, constants, oldBindings) ->
  bindingSet = GE.calculateBindingSet(path, chip, constants, oldBindings)
  result = new GE.ChipVisitorResult()
  for newBindings in bindingSet
    # Continue with children
    for childIndex, child of (chip.children or [])
      childResult = GE.visitChip(GE.appendToArray(path, childIndex), child, constants, newBindings)
      result = result.appendWith(childResult)
  return result

GE.visitEmitterChip = (path, chip, constants, bindings) ->
  evaluationContext = GE.makeEvaluationContext(constants, bindings)

  # Return "DONE" signal, so it can be put in sequences
  result = new GE.ChipVisitorResult(GE.signals.DONE)  
  GE.transformersLogger = GE.makeLogFunction(path, result.logMessages)

  for dest, expressionFunction of chip.emitter  
    try
      outputValue = GE.evaluateExpressionFunction(constants, evaluationContext, expressionFunction)
    catch error
      throw GE.makeExecutionError("Error executing the output pin expression '#{expressionFunction}' --> '#{dest}' for emitter chip: #{error.stack}", path)

    GE.derivePatches(bindings, path, evaluationContext, result.memoryPatches, result.ioPatches, dest, outputValue)
  
  return result

GE.chipVisitors =
  "processor": GE.visitProcessorChip
  "switch": GE.visitSwitchChip
  "splitter": GE.visitSplitterChip
  "emitter": GE.visitEmitterChip

# Constants are memoryData, assets, processors, switches and ioData
# The path is an array of the indices necessary to access the children
GE.visitChip = (path, chip, constants, bindings = {}) ->
  # TODO: defer processor and call execution until whole tree is evaluated?
  if chip.muted then return new GE.ChipVisitorResult()

  # Dispatch to correct function
  for chipType, visitor of GE.chipVisitors
    if chipType of chip
      return visitor(path, chip, constants, bindings)

  # Signal error
  result = new GE.ChipVisitorResult()
  result.logMessages.push
    path: path
    level: GE.logLevels.ERROR
    message: ["Board item '#{JSON.stringify(chip)}' is not understood"]
  return result

# The argument "options" can values for "chip", memoryData", "assets", "processors", "switches", "transformers", "io", "ioConfig", and "evaluator".
# By default, checks the io object for input data, visits the tree given in chip, and then provides output data to io.
# If outputIoData is not null, the loop is not stepped, and the data is sent directly to the io. In this case, no memory patches are returned.
# Otherwise, if inputIoData is not null, this data is used instead of asking the io.
# The options memoryData and inputIoData should be frozen with GE.deepFreeze() before being sent.
# Rather than throwing errors, this function attempts to trap errors internally and return them as an "errors" attribute.
# The errors have a "stage" attribute that is "readIo", "executeChips", "patchMemory", "patchIo", and "writeIo"
# Returns { memoryPatches: [...], inputIoData: {...}, ioPatches: [...], logMessages: [...], errors: [...] }
GE.stepLoop = (options) ->  
  makeErrorResponse = (stage, err) -> 
    errorDescription = 
      stage: stage
      message: err.message
      path: err.path
      stack: err.stack
    return { errors: [errorDescription], memoryPatches: memoryPatches, inputIoData: options.inputIoData, ioPatches: ioPatches, logMessages: logMessages }

  _.defaults options, 
    chip: null
    memoryData: {}
    assets: {}
    processors: {}
    switches: {}
    io: {}
    ioConfig: {}
    evaluator: eval
    inputIoData: null
    outputIoData: null 
    establishOutput: true

  # Initialize return data
  memoryPatches = []
  ioPatches = []
  logMessages = []

  if options.outputIoData == null
    if options.inputIoData == null
      options.inputIoData = {}
      try
        for ioName, io of options.io
          options.inputIoData[ioName] = GE.cloneData(io.provideData(options.ioConfig, options.assets))
      catch e 
        return makeErrorResponse("readIo", e)

    try
      result = GE.visitChip [], options.chip, new GE.ChipVisitorConstants
        memoryData: options.memoryData
        ioData: options.inputIoData
        assets: options.assets
        processors: options.processors
        switches: options.switches
        transformers: options.transformers
        evaluator: options.evaluator
    catch e 
      return makeErrorResponse("executeChips", e)
    
    try 
      conflicts = GE.detectPatchConflicts(result.memoryPatches)
      if conflicts.length > 0 then throw new Error("Memory patches conflict: #{JSON.stringify(conflicts)}")
      memoryPatches = result.memoryPatches
    catch e 
      return makeErrorResponse("patchMemory", e)

    try
      conflicts = GE.detectPatchConflicts(result.ioPatches)
      if conflicts.length > 0 then throw new Error("IO patches conflict: #{JSON.stringify(conflicts)}")
      ioPatches = result.ioPatches
      options.outputIoData = GE.applyPatches(result.ioPatches, options.inputIoData)
    catch e 
      return makeErrorResponse("patchIo", e)

    logMessages = result.logMessages

  # TODO: check the output even if isn't established, in order to catch errors
  if options.establishOutput
    try
      for ioName, io of options.io
        io.establishData(options.outputIoData[ioName], options.ioConfig, options.assets)
    catch e 
      return makeErrorResponse("writeIo", e)

  return { memoryPatches: memoryPatches, inputIoData: options.inputIoData, ioPatches: ioPatches, logMessages: logMessages }

# Compile expression source into sandboxed function of (memory, io, assets, transformers, bindings, pins) 
GE.compileExpression = (expressionText, evaluator) -> GE.compileSource("return #{expressionText};", evaluator, ["memory", "io", "assets", "transformers", "bindings", "pins"])

# Compile transformer source into a function of an "context" object that generates the transformers function,
# baking in the "transformers" pin expression of "context".
GE.compileTransformer = (expressionText, args, evaluator) -> 
  source = """
    return function(#{args.join(', ')}) { 
      var transformers = context.transformers; 
      var log = GE.transformersLogger; 
      #{expressionText} 
    };
  """
  return GE.compileSource(source, evaluator, ["context"])

# Compile processor.update() source into sandboxed function of (pins, transformers, log) 
GE.compileUpdate = (expressionText, evaluator) -> GE.compileSource(expressionText, evaluator, ["pins", "transformers", "log"])

# Compile processor listActiveChildren source into sandboxed function of (pins, children, transformers, log) 
GE.compileListActiveChildren = (expressionText, evaluator) -> GE.compileSource(expressionText, evaluator, ["pins", "children", "transformers", "log"])

# Compile processor handleSignals source into sandboxed function of (pins, children, activeChildren, signals, transformers, log) 
GE.compileHandleSignals = (expressionText, evaluator) -> GE.compileSource(expressionText, evaluator, ["pins", "children", "activeChildren", "signals", "transformers", "log"])

# Compile source into sandboxed function of parameters
GE.compileSource = (expressionText, evaluator, parameters) ->
  # Parentheses are needed around function because of strange JavaScript syntax rules
  # TODO: use "new Function" instead of eval? 
  # TODO: add "use strict"?
  # TODO: detect errors
  functionText = "(function(#{parameters.join(', ')}) {\n#{expressionText}\n})"
  expressionFunc = evaluator(functionText)
  if typeof(expressionFunc) isnt "function" then throw new Error("Expression does not evaluate as a function") 
  return expressionFunc

# Uses the GE.extensions map to find the corresponding type for the given filename 
# Else returns null
GE.determineAssetType = (url) ->
  extension = url.slice(url.lastIndexOf(".") + 1)
  for type, extensions of GE.extensions
    if extension in extensions then return type
  return null

# Returns a function that adds to logMessages with the given path
GE.makeLogFunction = (path, logMessages) ->
  logFunction = (args...) ->
    if args.length == 0 then throw new Error("Log function requires one or more arguments")
 
    logMessages.push
      path: path
      level: args[0]
      message: args[1..]
  # Create shortcut functions   
  logFunction.info = (args...) -> logFunction(GE.logLevels.INFO, args...)
  logFunction.warn = (args...) -> logFunction(GE.logLevels.WARN, args...)  
  logFunction.error = (args...) -> logFunction(GE.logLevels.ERROR, args...)  
  return logFunction

# Split address like "a.b[1].2" into ["a", "b", 1, 2]
GE.splitAddress = (address) -> _.reject(address.split(/[\.\[\]]/), (part) -> part is "")

# Combine a path like ["a", "b", 1, 2] into "a/b/1/2
GE.joinPathParts = (pathParts) -> "/#{pathParts.join('/')}"

# Load all the assets in the given object (name: url) and then call callback with the results, or error
# TODO: have cache-busting be configurable
# TODO: use promises rather than a counter
GE.loadAssets = (assets, callback) ->
  if _.size(assets) == 0 then return callback(null, {})

  results = {}
  loadedCount = 0 

  onLoad = -> if ++loadedCount == _.size(assets) then callback(null, results)
  onError = (text) -> callback(new Error(text))

  for name, url of assets
    do (name, url) -> # The `do` is needed because of asnyc requests below
      switch GE.determineAssetType(url)
        when "IMAGE"
          results[name] = new Image()
          results[name].onload = onLoad 
          results[name].onabort = onError
          results[name].onerror = -> onError("Cannot load image '#{name}'")
          results[name].src = url + "?_=#{new Date().getTime()}"
        when "JS"
          $.ajax
            url: url
            dataType: "text"
            cache: false
            error: -> onError("Cannot load JavaScript '#{name}'")
            success: (text) ->
              results[name] = text
              onLoad()
        when "HTML"
          $.ajax
            url: url
            dataType: "text"
            cache: false
            error: -> onError("Cannot load HTML '#{name}'")
            success: (text) ->
              results[name] = text
              onLoad()
        when "CSS"
          # Based on http://stackoverflow.com/a/805406/209505
          # TODO: need way to remove loaded styles later
          $.ajax
            url: url
            dataType: "text"
            cache: false
            error: -> onError("Cannot load CSS '#{name}'")
            success: (css) ->
              $('<style type="text/css"></style>').html(css).appendTo("head")
              onLoad()
        else 
          return callback(new Error("Do not know how to load #{url} for asset #{name}"))
