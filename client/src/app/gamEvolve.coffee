# Get alias for the global scope
globals = @

# All will be in the "GE" namespace
GE = globals.GE ? {}
globals.GE = GE

# The logFunction can be reset before visiting each chip that calls transformers
GE.transformersLogger = null

GE.Memory = class 
  constructor: (data = {}, @previous = null) -> 
    @data = GE.cloneFrozen(data)
    @version = if @previous? then @previous.version + 1 else 0

  setData: (data) -> return new GE.Memory(data, @)

  clonedData: -> return GE.cloneData(@data)

  atVersion: (version) -> 
    if version > version then throw new Error("Version not found")

    m = @
    while m.version > version then m = m.previous
    return m

  makePatches: (newData) -> return GE.makePatches(@data, newData)

  applyPatches: (patches) ->
    if patches.length == 0 then return @ # Nothing to do
    if GE.doPatchesConflict(patches) then throw new Error("Patches conflict")

    newData = GE.applyPatches(patches, @data)
    return new GE.Memory(newData, @)

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

# Used to compile expressions into executable functions, and to call these functions in the correct context.
GE.EvaluationContext = class 
  constructor: (@constants, bindings) ->
    @memory = GE.cloneData(@constants.memoryData)
    @io = GE.cloneData(@constants.ioData)
    @bindings = {}
    @setupBindings(bindings)

  setupBindings: (bindings) ->
    for bindingName, bindingValue of bindings
      if bindingValue instanceof GE.BindingReference
        [parent, key] = GE.getParentAndKey(@, bindingValue.ref.split("."))
        @bindings[bindingName] = parent[key]
      else
        @bindings[bindingName] = bindingValue

  compileExpression: (expression) -> GE.compileExpression(expression, @constants.evaluator)

  # Params are optional
  evaluateFunction: (f, params) -> f(@memory, @io, @constants.assets, @constants.transformers, @bindings, params)

  # Params are optional
  evaluateExpression: (expression, params) -> @evaluateFunction(@compileExpression(expression), params)

GE.extensions =
    IMAGE: ["png", "gif", "jpeg", "jpg"]
    JS: ["js"]
    CSS: ["css"]
    HTML: ["html"]

# Reject arrays as objects
GE.isOnlyObject = (o) -> return _.isObject(o) and not _.isArray(o)

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
# Using JSON patch format @ http://transformers.ietf.org/html/draft-pbryan-json-patch-04
# TODO: handle arrays
# TODO: handle escape syntax
GE.makePatches = (oldValue, newValue, prefix = "", patches = []) ->
  if _.isEqual(newValue, oldValue) then return patches

  if oldValue is undefined
    patches.push { add: prefix, value: GE.cloneData(newValue) }
  else if newValue is undefined 
    patches.push { remove: prefix }
  else if not _.isObject(newValue) or not _.isObject(oldValue) or typeof(oldValue) != typeof(newValue)
    patches.push { replace: prefix, value: GE.cloneData(newValue) }
  else if _.isArray(oldValue) and oldValue.length != newValue.length
    # In the case that we modified an array, we need to replace the whole thing  
    patches.push { replace: prefix, value: GE.cloneData(newValue) }
  else 
    # both elements are objects or arrays
    keys = _.union(_.keys(oldValue), _.keys(newValue))
    GE.makePatches(oldValue[key], newValue[key], "#{prefix}/#{key}", patches) for key in keys

  return patches

# Takes an oldValue and list of patches and creates a new value
# The top-level oldValue must be an object
# Using JSON patch format @ http://transformers.ietf.org/html/draft-pbryan-json-patch-04
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

# Returns true if more than 1 patch in the list tries to affect the same key
GE.doPatchesConflict = (patches) ->
  affectedKeys = {} # If a key is set to "FINAL" then it should not be touched by another patch
  for patch in patches
    path = patch.remove or patch.add or patch.replace
    pathParts = _.rest(path.split("/"))

    parent = affectedKeys
    for pathPart in _.initial(pathParts)
      if pathPart of parent 
        if parent[pathPart] == "FINAL" then return true # The path was not to be touched
      else
        parent[pathPart] = {}
      parent = parent[pathPart]

    # "parent" is now the last parent
    if _.last(pathParts) of parent then return true
    parent[_.last(pathParts)] = "FINAL" 

  return false

# Modifies patches by adding the given path to them
GE.addPathToPatches = (path, patches) -> 
  for patch in patches 
    patch.path = path
  return patches

# Set default values in paramDefs
GE.fillParamDefDefaults = (paramDefs) ->
  # Cannot use normal "for key, value of" loop because cannot handle replace null values
  for paramName of paramDefs
    if not paramDefs[paramName]? then paramDefs[paramName] = {}
    _.defaults paramDefs[paramName], 
      direction: "in"
  return paramDefs

# Returns an object mapping parameter namaes to their values 
# Param expressions is an object that contains 'in' and 'out' attributes
GE.evaluateInputParameters = (evaluationContext, paramDefs, paramExpressions) ->
  evaluatedParams = {}

  # TODO: don't evaluate output parameters here!
  for paramName, paramOptions of paramDefs
    # Resolve parameter value. If the board doesn't specify a value, use the default, it it exists. Otherwise, throw exception for input values
    if paramOptions.direction in ["in", "inout"] and paramExpressions.in?[paramName] 
      paramValue = paramExpressions.in[paramName]
    else if paramOptions.direction in ["out", "inout"] and paramExpressions.out?[paramName] 
      paramValue = paramExpressions.out[paramName]
    else if paramOptions.default? 
      paramValue = paramOptions.default
    else if paramOptions.direction in ["in", "inout"]
      throw new Error("Missing input parameter value for parameter '#{paramName}'")

    try
      evaluatedParams[paramName] = evaluationContext.evaluateExpression(paramValue)
    catch error
      throw new Error("Error evaluating the input parameter expression '#{paramValue}' for parameter '#{paramName}':\n#{error.stack}")
  return evaluatedParams

# Updates the evaluation context by evaluating the output parameter expressions
# Param expressions is an object that contains 'in' and 'out' attributes
GE.evaluateOutputParameters = (evaluationContext, paramDefs, paramExpressions, evaluatedParams) ->
  # Only output parameters should be accessible
  outParams = _.pick(evaluatedParams, (paramName for paramName, paramOptions of paramDefs when paramOptions.direction in ["out", "inout"]))

  for paramName, paramValue of paramExpressions.out
    try
      outputValue = evaluationContext.evaluateExpression(paramValue, outParams)
    catch error
      throw new Error("Error evaluating the output parameter value expression '#{paramValue}' for parameter '#{paramName}':\n#{error.stack}\nOutput params were #{JSON.stringify(outParams)}.")

    [parent, key] = GE.getParentAndKey(evaluationContext, paramName.split("."))
    parent[key] = outputValue

GE.calculateBindingSet = (chip, constants, oldBindings) ->
  bindingSet = []

  # If expression is a JSON object (which includes arrays) then loop over the values. Otherwise make references to memory and io
  if _.isObject(chip.splitter.from)
    for key, value of chip.splitter.from
      # Avoid polluting old object, and avoid creating new properties
      newBindings = Object.create(oldBindings)
      newBindings[chip.splitter.bindTo] = value
      if chip.splitter.index? then newBindings["#{chip.splitter.index}"] = key

      if chip.splitter.where?
        # TODO: compile expressions ahead of time
        evaluationContext = new GE.EvaluationContext(constants, newBindings)
        try
          # If the where clause evaluates to false, don't add it
          if evaluationContext.evaluateExpression(chip.splitter.where) then bindingSet.push(newBindings)
        catch error
          throw new Error("Error evaluating the where expression '#{chip.splitter.where}' for splitter chip '#{chip}':\n#{error.stack}")
      else
        bindingSet.push(newBindings)
  else if _.isString(chip.splitter.from)
    inputContext = 
      memory: GE.cloneData(constants.memoryData)
      io: GE.cloneData(constants.ioData)

    [parent, key] = GE.getParentAndKey(inputContext, chip.splitter.from.split("."))
    boundValue = parent[key]

    for key of boundValue
      # Avoid polluting old object, and avoid creating new properties
      newBindings = Object.create(oldBindings)
      newBindings[chip.splitter.bindTo] = new GE.BindingReference("#{chip.splitter.from}.#{key}")
      if chip.splitter.index? then newBindings["#{chip.splitter.index}"] = key

      if chip.splitter.where?
        # TODO: compile expressions ahead of time
        evaluationContext = new GE.EvaluationContext(constants, newBindings)
        try
          # If the where clause evaluates to false, don't add it
          if evaluationContext.evaluateExpression(chip.splitter.where) then bindingSet.push(newBindings)
        catch error
          throw new Error("Error evaluating the where expression '#{chip.splitter.where}' for splitter chip '#{chip}':\n#{error.stack}")
      else
        bindingSet.push(newBindings)
  else
    throw new Error("Splitter 'from' must be string or a JSON object")

  return bindingSet

GE.visitProcessorChip = (path, chip, constants, bindings) ->
  if chip.processor not of constants.processors then throw new Error("Cannot find processor '#{chip.processor}'")

  processor = constants.processors[chip.processor]

  # TODO: compile expressions ahead of time
  evaluationContext = new GE.EvaluationContext(constants, bindings)
  GE.fillParamDefDefaults(processor.paramDefs)
  evaluatedParams = GE.evaluateInputParameters(evaluationContext, processor.paramDefs, chip.params)

  result = new GE.ChipVisitorResult()
  GE.transformersLogger = GE.makeLogFunction(path, result.logMessages)

  try
    methodResult = processor.update(evaluatedParams, constants.transformers, GE.transformersLogger)
  catch e
    # TODO: convert exceptions to error sigals that do not create patches
    GE.transformersLogger(GE.logLevels.ERROR, "Calling processor #{chip.processor}.update raised an exception #{e}. Input params were #{JSON.stringify(evaluatedParams)}.\n#{e.stack}")

  GE.evaluateOutputParameters(evaluationContext, processor.paramDefs, chip.params, evaluatedParams)

  result.result = methodResult
  result.memoryPatches = GE.addPathToPatches(path, GE.makePatches(constants.memoryData, evaluationContext.memory))
  result.ioPatches = GE.addPathToPatches(path, GE.makePatches(constants.ioData, evaluationContext.io))

  return result

GE.visitSwitchChip = (path, chip, constants, bindings) ->
  if chip.switch not of constants.switches then throw new Error("Cannot find switch '#{chip.switch}'")

  switchChip = constants.switches[chip.switch]
  childNames = if chip.children? then (child.name ? index.toString()) for index, child of chip.children else []

  # TODO: compile expressions ahead of time
  evaluationContext = new GE.EvaluationContext(constants, bindings)
  GE.fillParamDefDefaults(switchChip.paramDefs)
  evaluatedParams = GE.evaluateInputParameters(evaluationContext, switchChip.paramDefs, chip.params)

  result = new GE.ChipVisitorResult()
  GE.transformersLogger = GE.makeLogFunction(path, result.logMessages)

  # check which children should be activated
  if "listActiveChildren" of switchChip
    try
      activeChildren = switchChip.listActiveChildren(evaluatedParams, childNames, constants.transformers, GE.transformersLogger)
      if not _.isArray(activeChildren) then throw new Error("Calling listActiveChildren() on chip '#{chip.switch}' did not return an array")
    catch e
      # TODO: convert exceptions to error sigals that do not create patches
      GE.transformersLogger(GE.logLevels.ERROR, "Calling switch #{chip.switch}.listActiveChildren raised an exception #{e}. Input params were #{JSON.stringify(evaluatedParams)}. Children are #{JSON.stringify(childNames)}.\n#{e.stack}")
  else
    # By default, all children are considered active
    activeChildren = childNames

  # Continue with children
  childSignals = new Array(chip.children.length)
  for childIndex in activeChildren
    childResult = GE.visitChip(GE.appendToArray(path, childIndex), chip.children[childIndex], constants, bindings)
    childSignals[childIndex] = childResult.result
    result = result.appendWith(childResult)

  # Handle signals
  # TODO: if handler not defined, propogate error signals upwards? How to merge them?
  if "handleSignals" of switchChip
    try
      signalsResult = switchChip.handleSignals(evaluatedParams, childNames, activeChildren, childSignals, constants.transformers, GE.transformersLogger)

      GE.evaluateOutputParameters(evaluationContext, switchChip.paramDefs, chip.params, evaluatedParams)
      memoryPatches = GE.addPathToPatches(path, GE.makePatches(constants.memoryData, evaluationContext.memory))
      ioPatches = GE.addPathToPatches(path, GE.makePatches(constants.ioData, evaluationContext.io))

      result = result.appendWith(new GE.ChipVisitorResult(signalsResult, memoryPatches, ioPatches))
      result.result = signalsResult # appendWith() does not affect result
    catch e
      # TODO: convert exceptions to error sigals that do not create patches
      GE.transformersLogger(GE.logLevels.ERROR, "Calling switch #{chip.switch}.handleSignals raised an exception #{e}. Input params were #{JSON.stringify(evaluatedParams)}. Children are #{JSON.stringify(childNames)}.\n#{e.stack}")

  return result

GE.visitSplitterChip = (path, chip, constants, oldBindings) ->
  bindingSet = GE.calculateBindingSet(chip, constants, oldBindings)
  result = new GE.ChipVisitorResult()
  for newBindings in bindingSet
    # Continue with children
    for childIndex, child of (chip.children or [])
      childResult = GE.visitChip(GE.appendToArray(path, childIndex), child, constants, newBindings)
      result = result.appendWith(childResult)
  return result

GE.visitEmitterChip = (path, chip, constants, bindings) ->
  memoryPatches = []
  ioPatches = []

  # Return "DONE" signal, so it can be put in sequences
  result = new GE.ChipVisitorResult(GE.signals.DONE)
  GE.transformersLogger = GE.makeLogFunction(path, result.logMessages)

  for dest, src of chip.emitter  
    evaluationContext = new GE.EvaluationContext(constants, bindings)

    try
      outputValue = evaluationContext.evaluateExpression(src)
    catch error
      throw new Error("Error evaluating the output parameter value expression '#{src}' for emitter chip:\n#{error.stack}")

    [parent, key] = GE.getParentAndKey(evaluationContext, dest.split("."))
    parent[key] = outputValue

    memoryPatches = GE.concatenate(memoryPatches, GE.addPathToPatches(path, GE.makePatches(constants.memoryData, evaluationContext.memory)))
    ioPatches = GE.concatenate(ioPatches, GE.addPathToPatches(path, GE.makePatches(constants.ioData, evaluationContext.io)))
  
  result.memoryPatches = memoryPatches
  result.ioPatches = ioPatches
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
  # TODO: handle children as object in addition to array
  for chipType, visitor of GE.chipVisitors
    if chipType of chip
      return visitor(path, chip, constants, bindings)

  result.logMessages.push
    path: path
    level: GE.logLevels.ERROR
    message: ["Board item '#{JSON.stringify(chip)}' is not understood"]

  return new GE.ChipVisitorResult()

# The argument "options" can values for "chip", memoryData", "assets", "processors", "switches", "transformers", "io", "ioConfig", and "evaluator".
# By default, checks the io object for input data, visits the tree given in chip, and then provides output data to io.
# If outputIoData is not null, the loop is not stepped, and the data is sent directly to the io. In this case, no memory patches are returned.
# Otherwise, if inputIoData is not null, this data is used instead of asking the io.
# Returns { memoryPatches: [...], inputIoData: {...}, ioPatches: [...], logMessages: [...] }
GE.stepLoop = (options) ->
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

  if options.outputIoData != null
    memoryPatches = []
    ioPatches = []
    logMessages = []
  else
    if options.inputIoData == null
      options.inputIoData = {}
      for ioName, io of options.io
        options.inputIoData[ioName] = io.provideData(options.ioConfig, options.assets)

    result = GE.visitChip [], options.chip, new GE.ChipVisitorConstants
      memoryData: options.memoryData
      ioData: options.inputIoData
      assets: options.assets
      processors: options.processors
      switches: options.switches
      transformers: options.transformers
      evaluator: options.evaluator
    
    if GE.doPatchesConflict(result.memoryPatches) then throw new Error("Memory patches conflict: #{JSON.stringify(result.memoryPatches)}")
    memoryPatches = result.memoryPatches

    if GE.doPatchesConflict(result.ioPatches) then throw new Error("IO patches conflict: #{JSON.stringify(result.ioPatches)}")
    ioPatches = result.ioPatches
    options.outputIoData = GE.applyPatches(result.ioPatches, options.inputIoData)

    logMessages = result.logMessages

  for ioName, io of options.io
    io.establishData(options.outputIoData[ioName], options.ioConfig, options.assets)

  return { memoryPatches: memoryPatches, inputIoData: options.inputIoData, ioPatches: ioPatches, logMessages: logMessages }

# Compile expression source into sandboxed function of (memory, io, assets, transformers, bindings, params) 
GE.compileExpression = (expressionText, evaluator) -> GE.compileSource("return #{expressionText};", evaluator, ["memory", "io", "assets", "transformers", "bindings", "params"])

# Compile transformer source into a function of an "context" object that generates the transformers function,
# baking in the "transformers" parameter of "context".
GE.compileTransformer = (expressionText, args, evaluator) -> 
  source = """
    return function(#{args.join(', ')}) { 
      var transformers = context.transformers; 
      var log = GE.transformersLogger; 
      #{expressionText} 
    };
  """
  return GE.compileSource(source, evaluator, ["context"])

# Compile processor.update() source into sandboxed function of (params, transformers, log) 
GE.compileUpdate = (expressionText, evaluator) -> GE.compileSource(expressionText, evaluator, ["params", "transformers", "log"])

# Compile processor listActiveChildren source into sandboxed function of (params, children, transformers, log) 
GE.compileListActiveChildren = (expressionText, evaluator) -> GE.compileSource(expressionText, evaluator, ["params", "children", "transformers", "log"])

# Compile processor handleSignals source into sandboxed function of (params, children, activeChildren, signals, transformers, log) 
GE.compileHandleSignals = (expressionText, evaluator) -> GE.compileSource(expressionText, evaluator, ["params", "children", "activeChildren", "signals", "transformers", "log"])

# Compile source into sandboxed function of params
GE.compileSource = (expressionText, evaluator, params) ->
  # Parentheses are needed around function because of strange JavaScript syntax rules
  # TODO: use "new Function" instead of eval? 
  # TODO: add "use strict"?
  # TODO: detect errors
  functionText = "(function(#{params.join(', ')}) {\n#{expressionText}\n})"
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
  return (args...) ->
    if args.length == 0 then throw new Error("Log function requires one or more arguments")
 
    logMessages.push
      path: path
      level: args[0]
      message: args[1..]

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
