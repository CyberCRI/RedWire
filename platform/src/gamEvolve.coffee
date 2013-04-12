### 
  The algorithm is as follows:
    1. Get a static view of the model at the current time, and keep track of it
    2. Go though the layout from the top-down, recursively. For each:
      1. Check validity and error out otherwise
      2. Switch on block type:
        * If bind, execute query and store param bindings for lower items
        * If set, package with model bindings and add to execution list
        * If call, package with model bindings and add to execution list
        * If action: 
          1. Package with model bindings and add to execution list
          2. Run calculateActiveChildren() and continue with those recursively 
    3. For each active bound block:
      1. Run and gather output and error/success status
        * In case of error: Store error signal
        * In case of success: 
          1. Merge model changes with others. If conflict, nothing passes
          2. If DONE is signaled, store it
    4. Starting at parents of active leaf blocks:
      1. If signals are stored for children, call handleSignals() with them
      2. If more signals are created, store them for parents
###

# Requires underscore

# Get alias for the global scope
globals = @

# All will be in the "GE" namespace
GE = {}

# Can be used to mimic enums in JS
# Since this is called by the GE namspace definition below, it must be defined first
GE.makeConstantSet = (values...) ->
  obj =
    # Checks if the value is in the set
    contains: (value) -> return value of obj
  for value in values then obj[value] = value
  return Object.freeze(obj)

GE.logLevels = GE.makeConstantSet("ERROR", "WARN", "INFO", "LOG")

GE.Model = class Model
  constructor: (data = {}, @previous = null) -> 
    @data = GE.deepFreeze(GE.cloneData(data))
    @version = if @previous? then @previous.version + 1 else 0

  setData: (data) -> return new Model(data, @)

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
    return new Model(newData, @)

GE.logToConsole = (type, message) -> window.console[logType.toLowerCase()](message)

GE.NodeVisitorConstants =  class NodeVisitorConstants
  # The log function defaults to the console
  constructor: (@modelData, @serviceData, @assets, @actions, @log = GE.logToConsole) ->

GE.NodeVisitorResult = class NodeVisitorResult
  constructor: (@result = null, @modelPatches = [], @servicePatches = []) ->

  # Return new results with combination of this and other
  appendWith: (other) ->
    # Don't touch @result
    newModelPatches = GE.concatenate(@modelPatches, other.modelPatches)
    newServicePatches = GE.concatenate(@servicePatches, other.servicePatches)
    return new NodeVisitorResult(@result, newModelPatches, newServicePatches)

GE.signals = GE.makeConstantSet("DONE", "ERROR")

GE.extensions =
    images: ["png", "gif", "jpeg", "jpg"]
    js: ["js"]

# There is probably a faster way to do this 
GE.cloneData = (o) -> JSON.parse(JSON.stringify(o))

# Reject arrays as objects
GE.isOnlyObject = (o) -> return _.isObject(o) and not _.isArray(o)

# Create new array with the value of these arrays
GE.concatenate = (rest...) -> _.flatten(rest, true)

# For accessing a value within an embedded object or array
# Takes a parent object/array and the "path" as an array
# Returns [parent, key] where parent is the array/object and key w
GE.getParentAndKey = (parent, pathParts) ->
  if pathParts.length == 0 then return [parent, null]
  if pathParts.length == 1 then return [parent, pathParts[0]]
  return GE.getParentAndKey(parent[pathParts[0]], _.rest(pathParts))

# Compare new object and old object to create list of patches.
# The top-level oldValue must be an object
# Using JSON patch format @ http://tools.ietf.org/html/draft-pbryan-json-patch-04
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
    keys = _.union _.keys(oldValue), _.keys(newValue)
    GE.makePatches(oldValue[key], newValue[key], "#{prefix}/#{key}", patches) for key in keys

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

# Returns true if more than 1 patch in the list tries to touch the same model parameters
GE.doPatchesConflict = (patches) ->
  affectedKeys = {}
  for patch in patches
    key = patch.remove or patch.add or patch.replace
    if key of affectedKeys then return true
    affectedKeys[key] = true

# Catches all errors in the function 
# The signals paramter is only used in the "handleSignals" call
GE.sandboxActionCall = (node, constants, bindings, methodName, signals = {}) ->
  action = constants.actions[node.action]
  childNames = if node.children? then [0..node.children.length - 1] else []

  # TODO: insure that all params values are POD
  # TODO: allow paramDefs to be missing
  compiledParams = {}
  evaluatedParams = {}
  for paramName, defaultValue of action.paramDefs
    # Resolve parameter value. In order, try layout, bindings, and finally default
    if node.params and paramName of node.params
      paramValue = node.params[paramName]
    else if paramName of bindings
      paramValue = bindings[paramName]
    else 
      paramValue = defaultValue

    compiledParams[paramName] = GE.compileParameter(paramValue, constants, bindings)
    value = compiledParams[paramName].get()
    
    # Let undefined or non-serializable values go through. 
    # Otherwise there is no way for missing parameters, or native components to be passed. 
    # TODO: Could be source of silent errors
    try 
      evaluatedParams[paramName] = GE.cloneData(value)
    catch e
      evaluatedParams[paramName] = value

  locals = 
    params: evaluatedParams
    children: childNames
    signals: signals
    assets: constants.assets
    log: constants.log
  try
    methodResult = action[methodName].apply(locals)
  catch e
    # TODO: convert exceptions to error sigals that do not create patches
    constants.log(GE.logLevels.ERROR, "Calling action #{node.action}.#{methodName} raised an exception #{e}")

  result = new GE.NodeVisitorResult(methodResult)

  # Call set() on all parameter functions, bringing in service and model patches
  for paramName, paramValue of compiledParams
    result = result.appendWith(paramValue.set(evaluatedParams[paramName]))

  return result

GE.calculateBindingSet = (node, constants, oldBindings) ->
  bindingSet = []

  # TODO: multiply from values together in order to make every combination
  if "from" of node.bind
    for bindingName, bindingExpression of node.bind.from
      # Evaluate values of the "from" clauses
      # TODO: in the case of models, get reference to model rather than evaluate the data here
      bindingValues = GE.compileParameter(bindingExpression, constants, oldBindings).get()
      index = 0
      for bindingIndex in [0..bindingValues.length - 1]
        # Avoid polluting old object, and avoid creating new properties
        newBindings = Object.create(oldBindings)
        newBindings["#{bindingName}Index"] = index
        index++
        if _.isString(bindingExpression)
          # WRONG: Works for models, but maybe not for other things
          newBindings[bindingName] = "#{bindingExpression}.#{bindingIndex}"
        else
          # Evaluate immediately
          newBindings[bindingName] = bindingValues[bindingIndex]

        # Handle select
        for name, value of node.select
          newBindings[name] = GE.compileParameter(value, constants, newBindings).get()

        bindingSet.push(newBindings)
  else
    # Avoid polluting old object, and avoid creating new properties
    newBindings = Object.create(oldBindings)
    # Handle select
    for name, value of node.bind.select
      newBindings[name] = value
    bindingSet.push(newBindings)

  return bindingSet

GE.visitActionNode = (node, constants, bindings) ->
  if node.action not of constants.actions then throw new Error("Cannot find action '#{node.action}'")

  if "update" of constants.actions[node.action]
    result = GE.sandboxActionCall(node, constants, bindings, "update")
  else
    result = new GE.NodeVisitorResult()

  # check which children should be activated
  if "listActiveChildren" of constants.actions[node.action]
    activeChildrenResult = GE.sandboxActionCall(node, constants, bindings, "listActiveChildren")
    activeChildren = activeChildrenResult.result
  else
    # By default, all children are considered active
    activeChildren = if node.children? then [0..node.children.length - 1] else []

  # Continue with children
  childSignals = []
  for childIndex in activeChildren
    child = node.children[childIndex]
    childResult = GE.visitNode(child, constants, bindings)
    childSignals[childIndex] = childResult.result
    result = result.appendWith(childResult)

  # Handle signals
  # TODO: if handler not defined, propogate error signals upwards? How to merge them?
  if "handleSignals" of constants.actions[node.action]
    errorResult = GE.sandboxActionCall(node, constants, bindings, "handleSignals", childSignals)
    result.result = errorResult
    result = result.appendWith(errorResult)

  return result

# Catches all errors in the function 
GE.visitCallNode = (node, constants, bindings) ->
  compiledParams = (GE.compileParameter(parameter, constants, bindings) for parameter in node.params)
  evaluatedParams = (param.get() for param in compiledParams)

  try
    globals[node.call].apply({}, evaluatedParams)
  catch e
    constants.log(GE.logLevels.ERROR, "Calling function #{functionName} raised an exception #{e}")

  return new GE.NodeVisitorResult()
  
GE.visitBindNode = (node, constants, oldBindings) ->
  bindingSet = GE.calculateBindingSet(node, constants, oldBindings)
  result = new NodeVisitorResult()
  for newBindings in bindingSet
    # Continue with children
    for child in (node.children or [])
      childResult = GE.visitNode(child, constants, newBindings)
      result = result.appendWith(childResult)
  return result

GE.visitSetModelNode = (node, constants, bindings) ->
  result = new GE.NodeVisitorResult()

  for name, value of node.setModel
    evaluatedParam = GE.compileParameter(value, constants, bindings).get()
    result = result.appendWith(GE.makeModelEvaluator(constants, name).set(evaluatedParam))
    
  return result

GE.nodeVisitors =
  "action": GE.visitActionNode
  "call": GE.visitCallNode
  "bind": GE.visitBindNode
  "setModel": GE.visitSetModelNode

# Constants are modelData, assets, actions, and serviceData
GE.visitNode = (node, constants, bindings = {}) ->
  # TODO: defer action and call execution until whole tree is evaluated?
  # TODO: handle children as object in addition to array

  for nodeType, visitor of GE.nodeVisitors
    if nodeType of node
      return visitor(node, constants, bindings)

  constants.log(GE.logLevels.ERROR, "Layout item is not understood")

  return new NodeVisitorResult()

# By default, checks the services object for input data, visits the tree given in node, and then provides output data to services.
# If outputServiceData is not null, the loop is not stepped, and the data is sent directly to the services. In this case, no model patches are returned.
# Otherwise, if inputServiceData is not null, this data is used instead of asking the services.
# Returns a list of model patches.
# TODO: refactor to accept a parameter object rather than a long list of parameters
GE.stepLoop = (node, modelData, assets, actions, services, log = null, inputServiceData = null, outputServiceData = null) ->
  if outputServiceData != null
    modelPatches = []
  else
    if inputServiceData == null
      inputServiceData = {}
      for serviceName, service of services
        inputServiceData[serviceName] = service.provideData(assets)

    result = GE.visitNode(node, new GE.NodeVisitorConstants(modelData, inputServiceData, assets, actions, log))
    modelPatches = result.modelPatches
    outputServiceData = GE.applyPatches(result.servicePatches, inputServiceData)

  for serviceName, service of services
    service.establishData(outputServiceData[serviceName], assets)

  return modelPatches

# Parameter names are always strings
GE.makeModelEvaluator = (constants, name) -> 
  if not name? then throw new Error("Model evaluator requires a name")

  return {
    get: -> 
      [parent, key] = GE.getParentAndKey(constants.modelData, name.split("."))
      return parent[key]

    set: (x) -> 
      # TODO: create patch directly, rather than by comparison
      newData = GE.cloneData(constants.modelData)
      [parent, key] = GE.getParentAndKey(newData, name.split("."))
      parent[key] = x
      return new GE.NodeVisitorResult(null, GE.makePatches(constants.modelData, newData))
  }

# Parameter names are always strings
GE.makeServiceEvaluator = (constants, name) -> 
  if not name? then throw new Error("Service evaluator requires a name")

  return {
    get: -> 
      [parent, key] = GE.getParentAndKey(constants.serviceData, name.split("."))
      return GE.cloneData(parent[key])

    set: (x) -> 
      # TODO: create patch directly, rather than by comparison
      newData = GE.cloneData(constants.serviceData)
      [parent, key] = GE.getParentAndKey(newData, name.split("."))
      parent[key] = x
      return new GE.NodeVisitorResult(null, [], GE.makePatches(constants.serviceData, newData))
  }

GE.makeAssetEvaluator = (constants, name) ->
  if not name? then throw new Error("Asset evaluator requires a name")

  return {
    get: -> return constants.assets[name]
    set: (x) -> return new GE.NodeVisitorResult() # Noop. Cannot set asset
  }

GE.makeConstantEvaluator = (constants, value) ->
  return {
    get: -> return value
    set: -> return new GE.NodeVisitorResult() # Noop. Cannot set constant value
  }

GE.parameterEvaluators = 
  "model": GE.makeModelEvaluator
  "asset": GE.makeAssetEvaluator
  "service": GE.makeServiceEvaluator
  "constant": GE.makeConstantEvaluator

# Compile parameter text into 'executable' object containing get()/set() methods
# The set() function returns a NodeVisitorResult, containing patches
# TODO: support expressions
# TODO: insure that parameter constants are only JSON
GE.compileParameter = (layoutParameter, constants, bindings) ->
  if _.isString(layoutParameter) and layoutParameter.length > 0
    # It might be an binding to be evaluated
    if layoutParameter[0] == "$"
      layoutParameter = layoutParameter.slice(1)

      # Only evaluate up to a "special" character
      endChar = layoutParameter.search(/\./)
      if endChar == -1 then endChar = layoutParameter.length
      bindingKey = bindings[layoutParameter.slice(0, endChar)]

      if _.isString(bindingKey)
        layoutParameter = "#{bindingKey}#{layoutParameter.slice(endChar)}" 
      else
        # WRONG: This is a hack, but will not work for more complex expressions
        return GE.makeConstantEvaluator(constants, bindingKey)

    if layoutParameter[0] == "@"
      # The argument is optional
      # TODO: include multiple arguments? As list or map?
      [matcherName, argument] = layoutParameter.slice(1).split(":")
      if not matcherName of GE.parameterEvaluators
        throw new Error("Cannot handle evaluator #{matcherName}")
      return GE.parameterEvaluators[matcherName](constants, argument)

  # Return as a constant value
  return GE.makeConstantEvaluator(constants, layoutParameter)

# Load all the assets in the given object (name: url) and then call callback with the results, or error
# TODO: have cache-busting be configurable
GE.loadAssets = (assets, callback) ->
  results = {}
  loadedCount = 0 

  onLoad = -> if ++loadedCount == _.size(assets) then callback(null, results)
  onError = -> callback(new Error(arguments))

  for name, url of assets
    extension = url.slice(url.lastIndexOf(".") + 1)

    if extension in GE.extensions.images
      results[name] = new Image()
      results[name].onload = onLoad 
      results[name].onabort = onError
      results[name].onerror = onError
      results[name].src = url + "?_=#{new Date().getTime()}"
    else if extension in GE.extensions.js
      # TODO: use script loader instead?
      $.ajax
        url: url
        dataType: "script"
        cache: false
        success: onLoad
        error: onError
    else 
      return callback(new Error("Do not know how to load #{url}"))

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

# Adds value to the given object, associating it with an unique (and meaningless) key
GE.addUnique = (obj, value) -> obj[_.uniqueId()] = value

# Install the GE namespace in the global scope
globals.GE = GE
