# Get alias for the global scope
globals = @

# All will be in the "GE" namespace
GE = globals.GE ? {}
globals.GE = GE

GE.Model = class 
  constructor: (data = {}, @previous = null) -> 
    @data = GE.cloneFrozen(data)
    @version = if @previous? then @previous.version + 1 else 0

  setData: (data) -> return new GE.Model(data, @)

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
    return new GE.Model(newData, @)

GE.logToConsole = (type, message) -> window.console[type.toLowerCase()](message)

GE.NodeVisitorConstants = class 
  # Accepts options for "modelData", "serviceData", "assets", "actions", "tools", "evaluator", and "log"
  # The "log" function defaults to the console
  constructor: (options) -> 
    _.defaults this, options,
      modelData: {}
      serviceData: {}
      assets: {}
      actions: {}
      processes: {}
      tools: {}
      evaluator: null
      log: GE.logToConsole

GE.NodeVisitorResult = class 
  constructor: (@result = null, @modelPatches = [], @servicePatches = []) ->

  # Return new results with combination of this and other
  appendWith: (other) ->
    # Don't touch @result
    newModelPatches = GE.concatenate(@modelPatches, other.modelPatches)
    newServicePatches = GE.concatenate(@servicePatches, other.servicePatches)
    return new GE.NodeVisitorResult(@result, newModelPatches, newServicePatches)

# Class used just to "tag" a string as being a reference rather than a JSON value
GE.BindingReference = class 
  constructor: (@ref) ->

# Used to compile expressions into executable functions, and to call these functions in the correct context.
GE.EvaluationContext = class 
  constructor: (@constants, bindings) ->
    @model = GE.cloneData(@constants.modelData)
    @services = GE.cloneData(@constants.serviceData)
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
  evaluateFunction: (f, params) -> f(@model, @services, @constants.assets, @constants.tools, @bindings, params)

  # Params are optional
  evaluateExpression: (expression, params) -> @evaluateFunction(@compileExpression(expression), params)

GE.extensions =
    IMAGE: ["png", "gif", "jpeg", "jpg"]
    JS: ["js"]
    CSS: ["css"]
    HTML: ["html"]

# Reject arrays as objects
GE.isOnlyObject = (o) -> return _.isObject(o) and not _.isArray(o)

# For accessing a value within an embedded object or array
# Takes a parent object/array and the "path" as an array
# Returns [parent, key] where parent is the array/object and key w
GE.getParentAndKey = (parent, pathParts) ->
  if pathParts.length is 0 then return [parent, null]
  if pathParts.length is 1 then return [parent, pathParts[0]]
  if pathParts[0] of parent then return GE.getParentAndKey(parent[pathParts[0]], _.rest(pathParts))
  throw new Error("Cannot find intermediate key '#{pathParts[0]}'")

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
    keys = _.union(_.keys(oldValue), _.keys(newValue))
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
    # Resolve parameter value. If the layout doesn't specify a value, use the default, it it exists. Otherwise, throw exception for input values
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

GE.calculateBindingSet = (node, constants, oldBindings) ->
  bindingSet = []

  # If expression is a JSON object (which includes arrays) then loop over the values. Otherwise make references to model and services
  if _.isObject(node.foreach.from)
    for key, value of node.foreach.from
      # Avoid polluting old object, and avoid creating new properties
      newBindings = Object.create(oldBindings)
      newBindings[node.foreach.bindTo] = value
      if node.foreach.index? then newBindings["#{node.foreach.index}"] = key

      if node.foreach.where?
        # TODO: compile expressions ahead of time
        evaluationContext = new GE.EvaluationContext(constants, newBindings)
        try
          # If the where clause evaluates to false, don't add it
          if evaluationContext.evaluateExpression(node.foreach.where) then bindingSet.push(newBindings)
        catch error
          throw new Error("Error evaluating the where expression '#{node.foreach.where}' for foreach node '#{node}':\n#{error.stack}")
      else
        bindingSet.push(newBindings)
  else if _.isString(node.foreach.from)
    inputContext = 
      model: GE.cloneData(constants.modelData)
      services: GE.cloneData(constants.serviceData)

    [parent, key] = GE.getParentAndKey(inputContext, node.foreach.from.split("."))
    boundValue = parent[key]

    for key of boundValue
      # Avoid polluting old object, and avoid creating new properties
      newBindings = Object.create(oldBindings)
      newBindings[node.foreach.bindTo] = new GE.BindingReference("#{node.foreach.from}.#{key}")
      if node.foreach.index? then newBindings["#{node.foreach.index}"] = key

      if node.foreach.where?
        # TODO: compile expressions ahead of time
        evaluationContext = new GE.EvaluationContext(constants, newBindings)
        try
          # If the where clause evaluates to false, don't add it
          if evaluationContext.evaluateExpression(node.foreach.where) then bindingSet.push(newBindings)
        catch error
          throw new Error("Error evaluating the where expression '#{node.foreach.where}' for foreach node '#{node}':\n#{error.stack}")
      else
        bindingSet.push(newBindings)
  else
    throw new Error("Foreach 'from' must be string or a JSON object")

  return bindingSet

GE.visitActionNode = (path, node, constants, bindings) ->
  if node.action not of constants.actions then throw new Error("Cannot find action '#{node.action}'")

  action = constants.actions[node.action]

  # TODO: compile expressions ahead of time
  evaluationContext = new GE.EvaluationContext(constants, bindings)
  GE.fillParamDefDefaults(action.paramDefs)
  evaluatedParams = GE.evaluateInputParameters(evaluationContext, action.paramDefs, node.params)

  try
    methodResult = action.update(evaluatedParams, constants.tools, constants.log)
  catch e
    # TODO: convert exceptions to error sigals that do not create patches
    constants.log(GE.logLevels.ERROR, "Calling action #{node.action}.update raised an exception #{e}. Input params were #{JSON.stringify(evaluatedParams)}. Children are #{JSON.stringify(childNames)}.\n#{e.stack}")

  result = new GE.NodeVisitorResult(methodResult)

  GE.evaluateOutputParameters(evaluationContext, action.paramDefs, node.params, evaluatedParams)

  result.modelPatches = GE.addPathToPatches(path, GE.makePatches(constants.modelData, evaluationContext.model))
  result.servicePatches = GE.addPathToPatches(path, GE.makePatches(constants.serviceData, evaluationContext.services))

  return result

GE.visitProcessNode = (path, node, constants, bindings) ->
  if node.process not of constants.processes then throw new Error("Cannot find process '#{node.process}'")

  process = constants.processes[node.process]
  childNames = if node.children? then (child.name ? index.toString()) for index, child of node.children else []

  # TODO: compile expressions ahead of time
  evaluationContext = new GE.EvaluationContext(constants, bindings)
  GE.fillParamDefDefaults(process.paramDefs)
  evaluatedParams = GE.evaluateInputParameters(evaluationContext, process.paramDefs, node.params)

  # check which children should be activated
  if "listActiveChildren" of process
    try
      activeChildren = process.listActiveChildren(evaluatedParams, childNames, constants.tools, constants.log)
      if not _.isArray(activeChildren) then throw new Error("Calling listActiveChildren() on node '#{node.process}' did not return an array")
    catch e
      # TODO: convert exceptions to error sigals that do not create patches
      constants.log(GE.logLevels.ERROR, "Calling process #{node.process}.listActiveChildren raised an exception #{e}. Input params were #{JSON.stringify(evaluatedParams)}. Children are #{JSON.stringify(childNames)}.\n#{e.stack}")
  else
    # By default, all children are considered active
    activeChildren = childNames

  result = new GE.NodeVisitorResult()

  # Continue with children
  childSignals = new Array(node.children.length)
  for childIndex in activeChildren
    childResult = GE.visitNode(GE.appendToArray(path, childIndex), node.children[childIndex], constants, bindings)
    childSignals[childIndex] = childResult.result
    result = result.appendWith(childResult)

  # Handle signals
  # TODO: if handler not defined, propogate error signals upwards? How to merge them?
  if "handleSignals" of process
    try
      signalsResult = process.handleSignals(evaluatedParams, childNames, activeChildren, childSignals, constants.tools, constants.log)

      GE.evaluateOutputParameters(evaluationContext, process.paramDefs, node.params, evaluatedParams)
      modelPatches = GE.addPathToPatches(path, GE.makePatches(constants.modelData, evaluationContext.model))
      servicePatches = GE.addPathToPatches(path, GE.makePatches(constants.serviceData, evaluationContext.services))

      result = result.appendWith(new GE.NodeVisitorResult(signalsResult, modelPatches, servicePatches))
      result.result = signalsResult # appendWith() does not affect result
    catch e
      # TODO: convert exceptions to error sigals that do not create patches
      constants.log(GE.logLevels.ERROR, "Calling process #{node.process}.handleSignals raised an exception #{e}. Input params were #{JSON.stringify(evaluatedParams)}. Children are #{JSON.stringify(childNames)}.\n#{e.stack}")

  return result

GE.visitForeachNode = (path, node, constants, oldBindings) ->
  bindingSet = GE.calculateBindingSet(node, constants, oldBindings)
  result = new GE.NodeVisitorResult()
  for newBindings in bindingSet
    # Continue with children
    for childIndex, child of (node.children or [])
      childResult = GE.visitNode(GE.appendToArray(path, childIndex), child, constants, newBindings)
      result = result.appendWith(childResult)
  return result

GE.visitSendNode = (path, node, constants, bindings) ->
  modelPatches = []
  servicePatches = []

  for dest, src of node.send  
    evaluationContext = new GE.EvaluationContext(constants, bindings)

    try
      outputValue = evaluationContext.evaluateExpression(src)
    catch error
      throw new Error("Error evaluating the output parameter value expression '#{src}' for send node:\n#{error.stack}")

    [parent, key] = GE.getParentAndKey(evaluationContext, dest.split("."))
    parent[key] = outputValue

    modelPatches = GE.concatenate(modelPatches, GE.addPathToPatches(path, GE.makePatches(constants.modelData, evaluationContext.model)))
    servicePatches = GE.concatenate(servicePatches, GE.addPathToPatches(path, GE.makePatches(constants.serviceData, evaluationContext.services)))
  
  # Return "DONE" signal, so it can be put in sequences
  return new GE.NodeVisitorResult(GE.signals.DONE, modelPatches, servicePatches)

GE.nodeVisitors =
  "action": GE.visitActionNode
  "process": GE.visitProcessNode
  "foreach": GE.visitForeachNode
  "send": GE.visitSendNode

# Constants are modelData, assets, actions, processes and serviceData
# The path is an array of the indices necessary to access the children
GE.visitNode = (path, node, constants, bindings = {}) ->
  # TODO: defer action and call execution until whole tree is evaluated?
  # TODO: handle children as object in addition to array
  for nodeType, visitor of GE.nodeVisitors
    if nodeType of node
      return visitor(path, node, constants, bindings)

  constants.log(GE.logLevels.ERROR, "Layout item '#{JSON.stringify(node)}' is not understood")

  return new GE.NodeVisitorResult()

# The argument "options" can values for "node", modelData", "assets", "actions", "processes", "tools", "services", "serviceConfig", and "evaluator".
# By default, checks the services object for input data, visits the tree given in node, and then provides output data to services.
# If outputServiceData is not null, the loop is not stepped, and the data is sent directly to the services. In this case, no model patches are returned.
# Otherwise, if inputServiceData is not null, this data is used instead of asking the services.
# Returns { modelPatches: [...], inputServiceData: {...}, servicePatches: [...] }
GE.stepLoop = (options) ->
  _.defaults options, 
    node: null
    modelData: {}
    assets: {}
    actions: {}
    processes: {}
    services: {}
    serviceConfig: {}
    evaluator: eval
    log: null
    inputServiceData: null
    outputServiceData: null 

  if options.outputServiceData != null
    modelPatches = []
    servicePatches = []
  else
    if options.inputServiceData == null
      options.inputServiceData = {}
      for serviceName, service of options.services
        options.inputServiceData[serviceName] = service.provideData(options.serviceConfig, options.assets)

    result = GE.visitNode [], options.node, new GE.NodeVisitorConstants
      modelData: options.modelData
      serviceData: options.inputServiceData
      assets: options.assets
      actions: options.actions
      processes: options.processes
      tools: options.tools
      evaluator: options.evaluator
      log: options.log
    
    if GE.doPatchesConflict(result.modelPatches) then throw new Error("Model patches conflict: #{JSON.stringify(result.modelPatches)}")
    modelPatches = result.modelPatches

    if GE.doPatchesConflict(result.servicePatches) then throw new Error("Service patches conflict: #{JSON.stringify(result.servicePatches)}")
    servicePatches = result.servicePatches
    options.outputServiceData = GE.applyPatches(result.servicePatches, options.inputServiceData)

  for serviceName, service of options.services
    service.establishData(options.outputServiceData[serviceName], options.serviceConfig, options.assets)

  return { modelPatches: modelPatches, inputServiceData: options.inputServiceData, servicePatches: servicePatches }

# Compile expression source into sandboxed function of (model, services, assets, tools, bindings, params) 
GE.compileExpression = (expressionText, evaluator) -> GE.compileSource("return #{expressionText};", evaluator, ["model", "services", "assets", "tools", "bindings", "params"])

# Compile tool source into sandboxed function of args..., "baking in" the "tools" and "log" parameters of "context" 
GE.compileTool = (expressionText, context, args, evaluator) -> 
  source = """
    return function(#{args.join(', ')}) { 
      var tools = context.tools; 
      var log = context.log; 
      #{expressionText} 
    };
  """
  return GE.compileSource(source, evaluator, ["context"])

# Compile action.update() source into sandboxed function of (params, tools, log) 
GE.compileUpdate = (expressionText, evaluator) -> GE.compileSource(expressionText, evaluator, ["params", "tools", "log"])

# Compile action listActiveChildren source into sandboxed function of (params, children, tools, log) 
GE.compileListActiveChildren = (expressionText, evaluator) -> GE.compileSource(expressionText, evaluator, ["params", "children", "tools", "log"])

# Compile action handleSignals source into sandboxed function of (params, children, activeChildren, signals, tools, log) 
GE.compileHandleSignals = (expressionText, evaluator) -> GE.compileSource(expressionText, evaluator, ["params", "children", "activeChildren", "signals", "tools", "log"])

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
