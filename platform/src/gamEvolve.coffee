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

# Class used just to "tag" a string as being a reference rather than a JSON value
GE.BindingReference = class BindingReference
  constructor: (@ref) ->

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

# Catches all errors in the function 
# The signals parameter is only used in the "handleSignals" call
GE.sandboxActionCall = (node, constants, bindings, methodName, signals = {}) ->
  action = constants.actions[node.action]
  childNames = if node.children? then (child.name ? index.toString()) for index, child of node.children else []

  # TODO: compile expressions ahead of time

  evaluationContext = 
    model: GE.cloneData(constants.modelData)
    services: GE.cloneData(constants.serviceData)
    bindings: {}

  # Setup bindings. Some are simple values, others point to data in model and services  
  for bindingName, bindingValue of bindings
    if bindingValue instanceof GE.BindingReference
      [parent, key] = GE.getParentAndKey(evaluationContext, bindingValue.ref.split("."))
      evaluationContext.bindings[bindingName] = parent[key]
    else
      evaluationContext.bindings[bindingName] = bindingValue

  # Set default paramOptions
  # Cannot use normal "for key, value of" loop because cannot handle replace null values
  for paramName of action.paramDefs
    if not action.paramDefs[paramName]? then action.paramDefs[paramName] = {}
    _.defaults action.paramDefs[paramName], 
      direction: "in"

  evaluatedParams = {}

  for paramName, paramOptions of action.paramDefs
    # Resolve parameter value. If the layout doesn't specify a value, use the default, it it exists. Otherwise, throw exception for input values
    if paramOptions.direction in ["in", "inout"] and node.params?.in?[paramName] 
      paramValue = node.params.in[paramName]
    else if paramOptions.direction in ["out", "inout"] and node.params?.out?[paramName] 
      paramValue = node.params.out[paramName]
    else if paramOptions.default? 
      paramValue = paramOptions.default
    else if paramOptions.direction in ["in", "inout"]
      throw new Error("Missing input parameter value for action: #{node.action}")

    try
      compiledParam = GE.compileInputExpression(paramValue, constants.evaluator)
      evaluatedParams[paramName] = compiledParam(evaluationContext.model, evaluationContext.services, constants.assets, constants.tools, evaluationContext.bindings)
    catch error
      throw new Error("Error evaluating the input parameter expression '#{paramValue}' for node '#{node.action}': #{error}")

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

  # Only output parameters should be accessible
  outParams = _.pick(evaluatedParams, (paramName for paramName, paramOptions of action.paramDefs when paramOptions.direction in ["out", "inout"]))

  for paramName, paramValue of node.params.out
    try
      compiledParam = GE.compileOutputExpression(paramValue, constants.evaluator)
      outputValue = compiledParam(evaluatedParams)
    catch error
      throw new Error("Error evaluating the output parameter expression '#{paramValue}' for node '#{node.action}': #{error}")

    [parent, key] = GE.getParentAndKey(evaluationContext, paramName.split("."))
    parent[key] = outputValue

  result.modelPatches = GE.makePatches(constants.modelData, evaluationContext.model)
  result.servicePatches = GE.makePatches(constants.serviceData, evaluationContext.services)

  return result

GE.calculateBindingSet = (node, constants, oldBindings) ->
  bindingSet = []

  # If expression is a JSON object (which includes arrays) then loop over the values. Otherwise make references to model and services
  if _.isObject(node.foreach.from)
    for key, value of node.foreach.from
      # TODO: test "where" guard expression

      # Avoid polluting old object, and avoid creating new properties
      newBindings = Object.create(oldBindings)
      newBindings[node.foreach.bindTo] = value
      if node.foreach.index? then newBindings["#{node.foreach.index}"] = key
      bindingSet.push(newBindings)
  else if _.isString(node.foreach.from)
    inputContext = 
      model: GE.cloneData(constants.modelData)
      services: GE.cloneData(constants.serviceData)

    [parent, key] = GE.getParentAndKey(inputContext, node.foreach.from.split("."))
    boundValue = parent[key]

    for key of boundValue
      # TODO: test "where" guard expression

      # Avoid polluting old object, and avoid creating new properties
      newBindings = Object.create(oldBindings)
      newBindings[node.foreach.bindTo] = new GE.BindingReference("#{node.foreach.from}.#{key}")
      if node.foreach.index? then newBindings["#{node.foreach.index}"] = key
      bindingSet.push(newBindings)
  else
    throw new Error("Foreach 'from' must be string or a JSON object")

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
    activeChildren = if node.children? then (child.name ? index.toString()) for index, child of node.children else []
    

  findChild = (name) ->
    for id,child of node.children
      if child.name == name || id.toString() == name
        return child

  # Continue with children
  childSignals = []
  for childName in activeChildren
    child = findChild(childName)
    childResult = GE.visitNode(child, constants, bindings)
    childSignals[childName] = childResult.result
    result = result.appendWith(childResult)

  # Handle signals
  # TODO: if handler not defined, propogate error signals upwards? How to merge them?
  if "handleSignals" of constants.actions[node.action]
    errorResult = GE.sandboxActionCall(node, constants, bindings, "handleSignals", childSignals)
    result.result = errorResult
    result = result.appendWith(errorResult)

  return result

GE.visitForeachNode = (node, constants, oldBindings) ->
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
  
  # Return "DONE" signal, so it can be put in sequences
  return new GE.NodeVisitorResult(GE.signals.DONE, modelPatches, servicePatches)

GE.nodeVisitors =
  "action": GE.visitActionNode
  "foreach": GE.visitForeachNode
  "send": GE.visitSendNode

# Constants are modelData, assets, actions, and serviceData
GE.visitNode = (node, constants, bindings = {}) ->
  # TODO: defer action and call execution until whole tree is evaluated?
  # TODO: handle children as object in addition to array

  for nodeType, visitor of GE.nodeVisitors
    if nodeType of node
      return visitor(node, constants, bindings)

  constants.log(GE.logLevels.ERROR, "Layout item '#{JSON.stringify(node)}' is not understood")

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
    
    if GE.doPatchesConflict(result.modelPatches) then throw new Error("Model patches conflict: #{JSON.stringify(result.modelPatches)}")
    modelPatches = result.modelPatches

    if GE.doPatchesConflict(result.servicePatches) then throw new Error("Service patches conflict: #{JSON.stringify(result.servicePatches)}")
    options.outputServiceData = GE.applyPatches(result.servicePatches, options.inputServiceData)

  for serviceName, service of options.services
    service.establishData(options.outputServiceData[serviceName], options.assets)

  return modelPatches

# Compile expression into sanboxed function that will produces an input value
GE.compileInputExpression = (expressionText, evaluator) ->
  # Parentheses are needed around function because of strange JavaScript syntax rules
  # TODO: use "new Function" instead of eval? 
  # TODO: add "use strict"?
  # TODO: detect errors
  functionText = "(function(model, services, assets, tools, bindings) { return #{expressionText}; })"
  expressionFunc = evaluator(functionText)
  if typeof(expressionFunc) isnt "function" then throw new Error("Expression does not evaluate as a function") 
  return expressionFunc

# Compile expression into sanboxed function that produces an output value
GE.compileOutputExpression = (expressionText, evaluator) ->
  # Parentheses are needed around function because of strange JavaScript syntax rules
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
