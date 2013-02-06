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

  # Reject arrays as objects
  isOnlyObject: (o) -> return _.isObject(o) and not _.isArray(o)

  # Logging functions could be used later 
  logError: (x) -> console.error(x)

  logWarning: (x) -> console.warn(x)

  # Compare new object and old object to create list of patches.
  # Using JSON patch format @ http://tools.ietf.org/html/draft-pbryan-json-patch-04
  # TODO: handle arrays
  # TODO: handle escape syntax
  makePatches: (oldValue, newValue, prefix = "", patches = []) ->
    if _.isEqual(newValue, oldValue) then return patches

    if oldValue is undefined
      patches.push { add: prefix, value: GE.clone(newValue) }
    else if newValue is undefined 
      patches.push { remove: prefix }
    else if not GE.isOnlyObject(newValue) or not GE.isOnlyObject(oldValue) 
      patches.push { replace: prefix, value: GE.clone(newValue) }
    else 
      # both elements are objects
      keys = _.union _.keys(oldValue), _.keys(newValue)
      GE.makePatches(oldValue[key], newValue[key], "#{prefix}/#{key}", patches) for key in keys

    return patches

  # For accessing a value within an embedded object or array
  # Takes a parent object/array and the "path" as an array
  # Returns [parent, key] where parent is the array/object and key w
  getParentAndKey: (parent, pathParts) ->
    if pathParts.length == 0 then return [parent, null]
    if pathParts.length == 1 then return [parent, pathParts[0]]
    return GE.getParentAndKey(parent[pathParts[0]], _.rest(pathParts))

  # Takes an oldValue and list of patches and creates a new value
  # Using JSON patch format @ http://tools.ietf.org/html/draft-pbryan-json-patch-04
  # TODO: handle arrays
  # TODO: handle escape syntax
  applyPatches: (patches, oldValue, prefix = "") ->
    splitPath = (path) -> _.rest(path.split("/"))

    value = GE.clone(oldValue)

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

  # The model copies itself as you call functions on it, like a Crockford-style monad
  Model: class Model
    constructor: (data = {}, @previous = null) -> 
      @data = GE.clone(data)
      @version = if @previous? then @previous.version + 1 else 0

    applyPatches: (patches) ->
      if GE.doPatchesConflict(patches) then throw new Error("Patches conflict")

      newData = GE.applyPatches(patches, @data)
      return new Model(newData, @)

  # Catches all errors in the function 
  sandboxFunctionCall: (model, functionName, parameters) ->
    try
      evaluatedParams = (GE.getParameterValue(model, GE.convertParameter(parameter)) for parameter in parameters)
      globals[functionName].apply({}, evaluatedParams)
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
      GE.sandboxFunctionCall(model, layout.call, layout.params)
    else
      GE.logError("Layout item must be action or call")

  # Parameter names are always strings
  matchers: 
    model: (name) -> 
      if not name? then throw new Error("Model matcher requires a name")

      return {
        get: -> 
          [parent, key] = GE.getParentAndKey(@modelData, name.split("."))
          return parent[key]
        set: (x) ->
          [parent, key] = GE.getParentAndKey(@modelData, name.split("."))
          parent[key] = x
      }

    binding: (name) -> 
      if not name? then throw new Error("Binding matcher requires a name")

      return {
        get: -> return @bindings[name]
        set: (x) -> @bindings[name] = x
      }

  # TODO: include piping expressions
  # TODO: insure that parameters are only JSON
  convertParameter: (layoutParameter) ->
    if _.isString(layoutParameter) and layoutParameter.length > 0
      # it might be an expression
      if layoutParameter[0] == "$"
        return GE.matchers.binding(layoutParameter.slice(1))

      if layoutParameter[0] == "@"
        # The parameter is optional
        # TODO: include multiple parameters?
        [matcherName, parameter] = layoutParameter.slice(1).split(":")

        return GE.matchers[matcherName](parameter)

      # Nope, just a string. Fall through...

    # Return as a constant value
    return layoutParameter

  # Parameters that have get functions are evaluated
  getParameterValue: (model, parameter) ->
    if GE.isOnlyObject(parameter) and "get" of parameter and "set" of parameter
      locals = 
        modelData: model.data
      return parameter.get.apply(locals)

    # Already a constant value
    return parameter


# Install the GE namespace in the global scope
globals.GE = GE








