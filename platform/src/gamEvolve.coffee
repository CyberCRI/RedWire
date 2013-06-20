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
GE = globals.GE

GE.Model = class Model
  constructor: (data = {}, @previous = null) -> 
    @data = GE.cloneFrozen(data)
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

GE.logToConsole = (type, message) -> window.console[type.toLowerCase()](message)

GE.NodeVisitorConstants =  class NodeVisitorConstants
  # Accepts options for "modelData", "serviceData", "assets", "actions", "tools", "evaluator", and "log"
  # The "log" function defaults to the console
  constructor: (options) -> 
    _.defaults this, options,
      modelData: {}
      serviceData: {}
      assets: {}
      actions: {}
      tools: {}
      evaluator: null
      log: GE.logToConsole

GE.NodeVisitorResult = class NodeVisitorResult
  constructor: (@result = null, @modelPatches = [], @servicePatches = []) ->

  # Return new results with combination of this and other
  appendWith: (other) ->
    # Don't touch @result
    newModelPatches = GE.concatenate(@modelPatches, other.modelPatches)
    newServicePatches = GE.concatenate(@servicePatches, other.servicePatches)
    return new NodeVisitorResult(@result, newModelPatches, newServicePatches)

GE.extensions =
    IMAGE: ["png", "gif", "jpeg", "jpg"]
    JS: ["js"]
    CSS: ["css"]

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
# The signals parameter is only used in the "handleSignals" call
GE.sandboxActionCall = (node, constants, bindings, methodName, signals = {}) ->
  action = constants.actions[node.action]
  childNames = if node.children? then [0..node.children.length - 1] else []

  # TODO: compile expressions ahead of time

  mutableModelData = GE.cloneData(constants.modelData)
  mutableServiceData = GE.cloneData(constants.serviceData)
  frozenBindings = GE.cloneFrozen(bindings)

  evaluatedParams = {}
  for paramName, paramOptions of action.paramDefs
    # Resolve parameter value. In order, try layout, bindings, and finally default. Otherwise, throw exception
    if paramOptions.direction in ["in", "inout"] and node.params?.in?[paramName] 
      paramValue = node.params.in[paramName]
    else if paramName of bindings
      paramValue = bindings[paramName]
    else if paramOptions.default? 
      paramValue = paramOptions.default
    else
      throw new Error("Missing parameter value for action: #{node.action}")

    compiledParam = GE.compileInputExpression(paramValue, constants.evaluator)
    evaluatedParams[paramName] = compiledParam(mutableModelData, mutableServiceData, constants.assets, constants.tools, frozenBindings)
    
  locals = 
    params: evaluatedParams
    children: childNames
    signals: signals
    assets: constants.assets
    tools: constants.tools
    log: constants.log
  try
    methodResult = action[methodName].apply(locals)
  catch e
    # TODO: convert exceptions to error sigals that do not create patches
    constants.log(GE.logLevels.ERROR, "Calling action #{node.action}.#{methodName} raised an exception #{e}")

  result = new GE.NodeVisitorResult(methodResult)

  outputContext = 
    model: GE.cloneData(constants.modelData)
    services: GE.cloneData(constants.serviceData)

  # Only output parameters should be accessible
  outParams = _.pick(evaluatedParams, (paramName for paramName, paramOptions of action.paramDefs when paramOptions.direction in ["out", "inout"]))

  for paramName, paramValue of node.params.out
    compiledParam = GE.compileOutputExpression(paramValue, constants.evaluator)
    outputValue = compiledParam(evaluatedParams)

    [parent, key] = GE.getParentAndKey(outputContext, paramName.split("."))
    parent[key] = outputValue

  result.modelPatches = GE.makePatches(constants.modelData, outputContext.model)
  result.servicePatches = GE.makePatches(constants.serviceData, outputContext.services)

  return result

GE.calculateBindingSet = (node, constants, oldBindings) ->
  bindingSet = []

  # TODO: multiply from values together in order to make every combination
  if "from" of node.bind
    for bindingName, bindingExpression of node.bind.from
      # Evaluate values of the "from" clauses
      # TODO: in the case of models, get reference to model rather than evaluate the data here
      bindingExpressionFunction = GE.compileInputExpression(bindingExpression, constants.evaluator)
      bindingValues = bindingExpressionFunction(constants.model, constants.services, constants.assets, constants.tools, oldBindings)
      # If bindingValues is empty, drop out 
      if bindingValues.length == 0 then return []

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
          bindingExpressionFunction = GE.compileInputExpression(value, constants.evaluator)
          newBindings[name] = bindingExpressionFunction(constants.model, constants.services, constants.assets, constants.tools, newBindings)

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

GE.visitBindNode = (node, constants, oldBindings) ->
  bindingSet = GE.calculateBindingSet(node, constants, oldBindings)
  result = new NodeVisitorResult()
  for newBindings in bindingSet
    # Continue with children
    for child in (node.children or [])
      childResult = GE.visitNode(child, constants, newBindings)
      result = result.appendWith(childResult)
  return result

GE.visitSendNode = (node, constants, bindings) ->
  outputContext = 
    model: GE.cloneData(constants.modelData)
    services: GE.cloneData(constants.serviceData)

  for dest, src of node.send
    srcExpressionFunction = GE.compileInputExpression(src, constants.evaluator)
    srcValue = srcExpressionFunction(constants.modelData, constants.serviceData, constants.assets, constants.tools, bindings)

    [parent, key] = GE.getParentAndKey(outputContext, dest.split("."))
    parent[key] = srcValue

  modelPatches = GE.makePatches(constants.modelData, outputContext.model)
  servicePatches = GE.makePatches(constants.serviceData, outputContext.services)
  
  return new GE.NodeVisitorResult(undefined, modelPatches, servicePatches)

GE.nodeVisitors =
  "action": GE.visitActionNode
  "bind": GE.visitBindNode
  "send": GE.visitSendNode

# Constants are modelData, assets, actions, and serviceData
GE.visitNode = (node, constants, bindings = {}) ->
  # TODO: defer action and call execution until whole tree is evaluated?
  # TODO: handle children as object in addition to array

  for nodeType, visitor of GE.nodeVisitors
    if nodeType of node
      return visitor(node, constants, bindings)

  constants.log(GE.logLevels.ERROR, "Layout item is not understood")

  return new NodeVisitorResult()

# The argument "options" can values for "node", modelData", "assets", "actions", "tools", "services", and "evaluator".
# By default, checks the services object for input data, visits the tree given in node, and then provides output data to services.
# If outputServiceData is not null, the loop is not stepped, and the data is sent directly to the services. In this case, no model patches are returned.
# Otherwise, if inputServiceData is not null, this data is used instead of asking the services.
# Returns a list of model patches.
# TODO: refactor to accept a parameter object rather than a long list of parameters
GE.stepLoop = (options) ->
  _.defaults options, 
    node: null
    modelData: {}
    assets: {}
    actions: {}
    log: null
    inputServiceData: null
    outputServiceData: null 

  if options.outputServiceData != null
    modelPatches = []
  else
    if options.inputServiceData == null
      options.inputServiceData = {}
      for serviceName, service of options.services
        options.inputServiceData[serviceName] = service.provideData(options.assets)

    result = GE.visitNode options.node, new GE.NodeVisitorConstants
      modelData: options.modelData
      serviceData: options.inputServiceData
      assets: options.assets
      actions: options.actions
      tools: options.tools
      evaluator: options.evaluator
      log: options.log
    
    if GE.doPatchesConflict(result.modelPatches) then throw new Error("Model patches conflict: #{result.modelPatches}")
    modelPatches = result.modelPatches

    if GE.doPatchesConflict(result.servicePatches) then throw new Error("Service patches conflict: #{result.servicePatches}")
    options.outputServiceData = GE.applyPatches(result.servicePatches, options.inputServiceData)

  for serviceName, service of options.services
    service.establishData(options.outputServiceData[serviceName], options.assets)

  return modelPatches

# Compile expression into sanboxed function that will produces an input value
GE.compileInputExpression = (expressionText, evaluator) ->
  # Parentheses are needed around function because of strange JavaScript rules
  # TODO: use "new Function" instead of eval? 
  # TODO: add "use strict"?
  # TODO: detect errors
  functionText = "(function(model, services, assets, tools, bindings) { return #{expressionText}; })"
  expressionFunc = evaluator(functionText)
  if typeof(expressionFunc) isnt "function" then throw new Error("Expression does not evaluate as a function") 
  return expressionFunc

# Compile expression into sanboxed function that produces an output value
GE.compileOutputExpression = (expressionText, evaluator) ->
  # Parentheses are needed around function because of strange JavaScript rules
  # TODO: use "new Function" instead of eval? 
  # TODO: add "use strict"?
  # TODO: detect errors
  functionText = "(function(params) { return #{expressionText}; })"
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

# Load all the assets in the given object (name: url) and then call callback with the results, or error
# TODO: have cache-busting be configurable
GE.loadAssets = (assets, callback) ->
  results = {}
  loadedCount = 0 

  onLoad = -> if ++loadedCount == _.size(assets) then callback(null, results)
  onError = -> callback(new Error(arguments))

  for name, url of assets
    do (name, url) -> # The `do` is needed because of asnyc requests below
      switch GE.determineAssetType(url)
        when "IMAGE"
          results[name] = new Image()
          results[name].onload = onLoad 
          results[name].onabort = onError
          results[name].onerror = onError
          results[name].src = url + "?_=#{new Date().getTime()}"
        when "JS"
          $.ajax
            url: url
            dataType: "text"
            cache: false
            error: onError
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
            error: onError
            success: (css) ->
              $('<style type="text/css"></style>').html(css).appendTo("head")
              onLoad()
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

# Shortcut to clone and then freeze result
GE.cloneFrozen = (o) -> return GE.deepFreeze(GE.cloneData(o))

# Adds value to the given object, associating it with an unique (and meaningless) key
GE.addUnique = (obj, value) -> obj[_.uniqueId()] = value

# Creates and returns an eval function that runs within an iFrame sandbox
# Automatically runs all the scripts provided before returning the evaluator
# Based on https://github.com/josscrowcroft/javascript-sandbox-console/blob/master/src/sandbox-console.js
# This is not secure, given that the iframe still has access to the parent
# TODO: Improve security using the sandbox attribute and postMessage() as described at http://www.html5rocks.com/en/tutorials/security/sandboxed-iframes/
GE.makeEvaluator = (scriptsToRun...) ->
  sandboxFrame = $("<iframe width='0' height='0' />").css({visibility : 'hidden'}).appendTo("body")
  evaluator = sandboxFrame[0].contentWindow.eval 
  sandboxFrame.remove()

  for script in scriptsToRun then evaluator(script)
  return evaluator

# Install the GE namespace in the global scope
globals.GE = GE
