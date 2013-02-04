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
GE = 
  # Use Underscore's clone method
  clone: _.clone

  # Logging functions could be used later 
  logError: (x) -> console.error(x)

  logWarning: (x) -> console.warn(x)

  # Compare new object and old object to create list of patches.
  # Using JSON patch format @ http://tools.ietf.org/html/draft-pbryan-json-patch-04
  makePatches: (oldValue, newValue, prefix = "", patches = []) ->
    if _.isEqual(newValue, oldValue) then return patches

    if oldValue is undefined
      patches.push { add: prefix, value: GE.clone(newValue) }
    else if newValue is undefined 
      patches.push { remove: prefix }
    else if not isObject(newValue) or not isObject(oldValue) 
      patches.push { replace: prefix, value: GE.clone(newValue) }
    else 
      # both elements are objects
      keys = _.union _.keys(oldValue), _.keys(newValue)
      makePatchList(oldValue[key], newValue[key], "#{prefix}/#{key}", patches) for key in keys

    return patches

  # Takes an oldValue and list of patches and creates a new value
  # Using JSON patch format @ http://tools.ietf.org/html/draft-pbryan-json-patch-04
  applyPatches: (patches, oldValue, prefix = "") ->
    splitPath = (path) -> _.rest(path.split("/"))

    getParentAndKey = (parent, pathParts) ->
      if pathParts.length == 0 then return [parent, null]
      if pathParts.length == 1 then return [parent, pathParts[1]]
      return getParentAndKey(_.first(parent[first]), _.rest(pathParts))

    value = GE.clone(originalValue)

    for patch in patches
      if "remove" of patch
        [parent, key] = getParentAndKey(value, splitPath(patch.remove))
        delete parent[key]
      else if "add" of patch
        [parent, key] = getParentAndKey(value, splitPath(patch.add))
        parent[key] = patch.value
      else if "replace" of patch
        [parent, key] = getParentAndKey(value, splitPath(patch.replace))
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

  # The model copies itself as you call functions on it, like a Crockford-style monad
  Model: class Model
    constructor: (@previous = null, @data = {}) -> 
      version = if @previous? then @previous.version + 1 else 0

    applyPatches: (patches) ->
      if GE.doPatchesConflict(patches) then throw new Error("Patches conflict")

      newData = GE.applyPatches(@data)
      return new Model(@, newData)


  # Catches all errors in the function 
  sandboxFunctionCall: (functionName, args) ->
    try
      globals[functionName].apply({}, args)
    catch e
      GE.logWarning("Calling function #{functionName} raised an exception #{e}")
    
  # Catches all errors in the function 
  sandboxActionCall: (actions, actionName, params) ->
    action = actions[actionName]

    # TODO: merge default param values
    # TODO: evaluate all functions, then insure that all params are POD
    # TODO: allow paramDefs to be missing
    if(not _.isEqual(_.keys(action.paramDefs), _.keys(params)))
      return GE.logError("Parameters given to action #{actionName} do not match definitions")

    try
      locals = 
        params: params
      action.update.apply(locals)
    catch e
      GE.logWarning("Calling action #{action} raised an exception #{e}")

  runStep: (model, actions, layout) ->
    # TODO: defer action and call execution until whole tree is evaluated?

    if "action" of layout
      GE.sandboxActionCall(actions, layout.action, layout.params)
      # continute with children
      if "children" not of layout then return

      for child in layout.children
        GE.runStep(model, actions, child)
    else if "call" of layout
      GE.sandboxFunctionCall(layout.call, layout.params)
    else
      GE.logError("Layout item must be action or call")


# Install the GE namespace in the global scope
globals.GE = GE








