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

# Since this is called by the GE namspace definition below, it must be defined first
makeConstantSet = (values...) ->
  obj = {}
  for value in values then obj[value] = value
  return Object.freeze(obj)


# All will be in the "GE" namespace
GE =

  logLevels: makeConstantSet("ERROR", "WARN", "INFO", "LOG")
  logger:
    log:   (logType, message) -> if logLevels[logType] then console[logType](message)

  # The model copies itself as you call functions on it, like a Crockford-style monad
  Model: class Model
    constructor: (data = {}, @previous = null) ->
      @data = GE.cloneData(data)
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

  signals: makeConstantSet("DONE", "ERROR")

  extensions:
    images: ["png", "gif", "jpeg", "jpg"]
    js: ["js"]

  GameController: class GameController
    constructor: (@model, @assets, @actions, @layout) ->

    loadAssets: (callback) ->
      GE.loadAssets @assets, (err, loadedAssets) =>
        if err? then return callback(err)

        @loadedAssets = loadedAssets
        callback(null)

    # Does not apply changes
    dryStep: -> 
      GE.runStep(@model, @loadedAssets, @actions, @layout)
    
    # Applies changes to model, if possible
    step: ->
      [result, patches] = GE.runStep(@model, @loadedAssets, @actions, @layout)
      @model = @model.applyPatches(patches)

  makeConstantSet: makeConstantSet

  # There is probably a faster way to do this 
  cloneData: (o) -> JSON.parse(JSON.stringify(o))

  # Reject arrays as objects
  isOnlyObject: (o) -> return _.isObject(o) and not _.isArray(o)

  # For accessing a value within an embedded object or array
  # Takes a parent object/array and the "path" as an array
  # Returns [parent, key] where parent is the array/object and key w
  getParentAndKey: (parent, pathParts) ->
    if pathParts.length == 0 then return [parent, null]
    if pathParts.length == 1 then return [parent, pathParts[0]]
    return GE.getParentAndKey(parent[pathParts[0]], _.rest(pathParts))

  # Compare new object and old object to create list of patches.
  # Using JSON patch format @ http://tools.ietf.org/html/draft-pbryan-json-patch-04
  # TODO: handle arrays
  # TODO: handle escape syntax
  makePatches: (oldValue, newValue, prefix = "", patches = []) ->
    if _.isEqual(newValue, oldValue) then return patches

    if oldValue is undefined
      patches.push { add: prefix, value: GE.cloneData(newValue) }
    else if newValue is undefined 
      patches.push { remove: prefix }
    else if not _.isObject(newValue) or not _.isObject(oldValue) or typeof(oldValue) != typeof(newValue)
      patches.push { replace: prefix, value: GE.cloneData(newValue) }
    else 
      # both elements are objects or 
      keys = _.union _.keys(oldValue), _.keys(newValue)
      GE.makePatches(oldValue[key], newValue[key], "#{prefix}/#{key}", patches) for key in keys

    return patches

  # Takes an oldValue and list of patches and creates a new value
  # Using JSON patch format @ http://tools.ietf.org/html/draft-pbryan-json-patch-04
  # TODO: handle arrays
  # TODO: handle escape syntax
  applyPatches: (patches, oldValue, prefix = "") ->
    splitPath = (path) -> _.rest(path.split("/"))

    value = GE.cloneData(oldValue)

    for patch in patches
      if "remove" of patch
        [parent, key] = GE.getParentAndKey(value, splitPath(patch.remove))
        delete parent[key]
      else if "add" of patch
        [parent, key] = GE.getParentAndKey(value, splitPath(patch.add))
        parent[key] = patch.value
      else if "replace" of patch
        [parent, key] = GE.getParentAndKey(value, splitPath(patch.replace))
        if key not of parent then throw new Error("No existing value to replace for patch #{patch}")
        parent[key] = patch.value

    return value

  # Returns true if more than 1 patch in the list tries to touch the same model parameters
  doPatchesConflict: (patches) ->
    affectedKeys = {}
    for patch in patches
      key = patch.remove or patch.add or patch.replace
      if key of affectedKeys then return true
      affectedKeys[key] = true

  # Catches all errors in the function 
  sandboxFunctionCall: (model, assets, bindings, functionName, parameters) ->
    modelData = model.clonedData()
    compiledParams = (GE.compileParameter(modelData, assets, bindings, parameter) for parameter in parameters)
    evaluatedParams = (param.get() for param in compiledParams)

    try
      globals[functionName].apply({}, evaluatedParams)
    catch e
      GE.logger.log(GE.logLevels.WARN, "Calling function #{functionName} raised an exception #{e}")
    
  # Catches all errors in the function 
  sandboxActionCall: (model, assets, bindings, actions, actionName, methodName, layoutParameters, childNames, signals) ->
    action = actions[actionName]

    # TODO: insure that all params values are POD
    # TODO: allow paramDefs to be missing

    modelData = model.clonedData()
    compiledParams = {}
    evaluatedParams = {}
    for paramName, defaultValue of action.paramDefs
      # Resolve parameter value. In order, try layout, bindings, and finally default
      if layoutParameters and paramName of layoutParameters
        paramValue = layoutParameters[paramName]
      else if paramName of bindings
        paramValue = bindings[paramName]
      else 
        paramValue = defaultValue

      compiledParams[paramName] = GE.compileParameter(modelData, assets, bindings, paramValue)
      evaluatedParams[paramName] = compiledParams[paramName].get()
    locals = 
      params: evaluatedParams
      children: childNames
      signals: signals
      assets: assets
    try
      result = action[methodName].apply(locals)
    catch e
      # TODO: convert exceptions to error sigals that do not create patches
      GE.logger.log(GE.logLevels.WARN, "Calling action #{action}.#{methodName} raised an exception #{e}")

    # Call set() on all parameter functions
    for paramName, paramValue of compiledParams
      paramValue.set(evaluatedParams[paramName])

    # return result and patches, if any
    return [result, model.makePatches(modelData)]

  calculateBindingSet: (modelData, assets, oldBindings, bindingLayout) ->
    bindingSet = []

    # TODO: multiply from values together in order to make every combination
    if "from" of bindingLayout
      for bindingName, bindingExpression of bindingLayout.from
        # Evaluate values of the "from" clauses
        # TODO: in the case of models, get reference to model rather than evaluate the data here
        bindingValues = GE.compileParameter(modelData, assets, oldBindings, bindingExpression).get()
        for bindingIndex in [0..bindingValues.length - 1]
          # Avoid polluting old object, and avoid creating new properties
          newBindings = Object.create(oldBindings)
          if _.isString(bindingExpression)
            # WRONG: Works for models, but maybe not for other things
            newBindings[bindingName] = "#{bindingExpression}.#{bindingIndex}"
          else
            # Evaluate immediately
            newBindings[bindingName] = bindingValues[bindingIndex]

          # Handle select
          for name, value of bindingLayout.select
            newBindings[name] = GE.compileParameter(modelData, assets, newBindings, value).get()

          bindingSet.push(newBindings)
    else
      # Avoid polluting old object, and avoid creating new properties
      newBindings = Object.create(oldBindings)
      # Handle select
      for name, value of bindingLayout.select
        newBindings[name] = value
      bindingSet.push(newBindings)

    return bindingSet

  handleSetModel: (model, assets, bindings, setModelLayout) ->
    modelData = model.clonedData()

    # TODO: handle bindings?
    for name, value of setModelLayout
      evaluatedParam = GE.compileParameter(modelData, assets, bindings, value).get()
      GE.makeModelEvaluator(modelData, name).set(evaluatedParam) 
      
    return model.makePatches(modelData)

  runStep: (model, assets, actions, layout, bindings = {}) ->
    # TODO: defer action and call execution until whole tree is evaluated?
    # TODO: handle children as object in addition to array

    # List of patches to apply, across all actions
    patches = []
    result = undefined

    if "action" of layout
      if layout.action not of actions then throw new Error("Cannot find action '#{layout.action}'")

      childNames = if layout.children? then [0..layout.children.length - 1] else []

      if "update" of actions[layout.action]
        [result, actionPatches] = GE.sandboxActionCall(model, assets, bindings, actions, layout.action, "update", layout.params, childNames)
        # Concatenate patches array in place
        patches.push(actionPatches...) 

      # check which children should be activated
      if "listActiveChildren" of actions[layout.action]
        [activeChildren, __] = GE.sandboxActionCall(model, assets, bindings, actions, layout.action, "listActiveChildren", layout.params, childNames)
      else
        # By default, all children are considered active
        activeChildren = childNames

      # Continue with children
      childSignals = []
      for childIndex in activeChildren
        child = layout.children[childIndex]
        [childSignals[childIndex], childPatches] = GE.runStep(model, assets, actions, child, bindings)
        # Concatenate patches array in place
        patches.push(childPatches...) 

      # Handle signals
      # TODO: if handler not defined, propogate error signals upwards? How to merge them?
      if "handleSignals" of actions[layout.action]
        [result, actionPatches] = GE.sandboxActionCall(model, assets, bindings, actions, layout.action, "handleSignals", layout.params, childNames, childSignals)
        # Concatenate patches array in place
        patches.push(actionPatches...) 
    else if "call" of layout
      GE.sandboxFunctionCall(model, assets, bindings, layout.call, layout.params, bindings)
    else if "bind" of layout
      bindingSet = GE.calculateBindingSet(model.data, assets, bindings, layout.bind)
      for newBindings in bindingSet
        # Continue with children
        for child in (layout.children or [])
          [__, childPatches] = GE.runStep(model, assets, actions, child, newBindings)
          # Concatenate patches array in place
          patches.push(childPatches...) 
    else if "setModel" of layout
      setModelPatches = GE.handleSetModel(model, assets, bindings, layout.setModel)
      # Concatenate the array in place
      patches.push(setModelPatches...) 
    else
      GE.logError("Layout item is not understood")

    return [result, patches]

  # Parameter names are always strings
  makeModelEvaluator: (modelData, name) -> 
    if not name? then throw new Error("Model evaluator requires a name")

    [parent, key] = GE.getParentAndKey(modelData, name.split("."))
    return {
      get: -> return parent[key]
      set: (x) -> parent[key] = x
    }

  makeAssetEvaluator: (assets, name) ->
    if not name? then throw new Error("Asset evaluator requires a name")

    return {
      get: -> return assets[name]
      set: (x) -> # Noop. Cannot set asset
    }

  makeConstantEvaluator: (value) ->
    return {
      get: -> return value
      set: -> # Noop. Cannot set constant value
    }


  # Compile parameter text into 'executable' object containing get()/set() methods
  # TODO: include piping expressions
  # TODO: insure that parameter constants are only JSON
  compileParameter: (modelData, assets, bindings, layoutParameter) ->
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
          return GE.makeConstantEvaluator(bindingKey)

      if layoutParameter[0] == "@"
        # The argument is optional
        # TODO: include multiple arguments? As list or map?
        [matcherName, argument] = layoutParameter.slice(1).split(":")
        switch matcherName
          when "model" then return GE.makeModelEvaluator(modelData, argument)
          when "asset" then return GE.makeAssetEvaluator(assets, argument)
          else throw new Error("Cannot handle evaluator #{matcherName}")
      # Nope, just a string. Fall through...

    # Return as a constant value
    return GE.makeConstantEvaluator(layoutParameter)

  # Load all the assets in the given object (name: url) and then call callback with the results, or error
  # TODO: have cache-busting be configurable
  loadAssets: (assets, callback) ->
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
  doLater: (f) -> setTimeout(f, 0)

# Install the GE namespace in the global scope
globals.GE = GE








