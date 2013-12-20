# FUNCTIONS

# Converts input actions (with code as strings) to compiled form with code as functions.
# Leaves non-code values as they were
compileActions = (inputActions) ->
  return GE.mapObject inputActions, (value, key) ->
    compiledAction = {}
    try
      for actionKey, actionValue of value
        compiledAction[actionKey] = switch actionKey
          when "update" then GE.compileUpdate(actionValue, currentEvaluator)
          else actionValue
      return compiledAction
    catch compilationError
      throw new Error("Error compiling action '#{key}'. #{compilationError}")

# Converts input actions (with code as strings) to compiled form with code as functions
# Leaves non-code values as they were
compileProcesses = (inputProcesses) ->
  return GE.mapObject inputProcesses, (value, key) ->
    compiledProcess = {}
    try
      for processKey, processValue of value
        compiledProcess[processKey] = switch processKey
          when "listActiveChildren" then GE.compileListActiveChildren(processValue, currentEvaluator)
          when "handleSignals" then GE.compileHandleSignals(processValue, currentEvaluator)
          else processValue
      return compiledProcess
    catch compilationError
      throw new Error("Error compiling process '#{key}'. #{compilationError}")

# Converts input tools (with code as strings) to compiled form with code as functions.
# The logFunction will be provided to all tools
# Leaves non-code values as they were.
compileTools = (inputTools, logFunction) ->
  toolsContext = 
    tools: null
    log: null
  compiledTools = GE.mapObject currentTools, (value, key) -> 
    try
      toolFactory = GE.compileTool(value.body, toolsContext, value.args, currentEvaluator)
      return toolFactory(toolsContext)
    catch compilationError
      throw new Error("Error compiling tool '#{key}'. #{compilationError}")
  toolsContext.tools = compiledTools
  toolsContext.log = logFunction

destroyServices = (currentServices) ->
  for serviceName, service of currentServices
    service.destroy()

initializeServices = (serviceDefs) ->
  # Create new services
  currentServices = {}
  for serviceName, serviceDef of serviceDefs
    try
      options = _.defaults serviceDef.options || {},
        elementSelector: '#gameContent'
        size: GAME_DIMENSIONS
      currentServices[serviceName] = services[serviceDef.type](options)
    catch error
      throw new Error("Error initializing service '#{serviceName}'. #{error}")
  return currentServices

# Unload previous assets and load new ones. The given list of evaluators are initialized with any JS assets.
# Returns new assets
# TODO: move asset handling into gamEvolve.coffee. CSS could be handled by the HTML service. JS is harder.
updateAssets = (oldAssets, newAssetMap, evaluators...) ->
  # Remove old assets
  # TODO: Only update new assets
  for name, dataUrl of oldAssets
    splitUrl = splitDataUrl(dataUrl)
    if splitUrl.mimeType == "application/javascript"
      # Nothing to do, cannot unload JS!
    else if splitUrl.mimeType == "text/css"
      assetNamesToData[name].remove()
    else if splitUrl.mimeType.indexOf("image/") == 0
      URL.revokeObjectURL(assetNamesToObjectUrls[name])

  assetNamesToData = {}
  assetNamesToObjectUrls = {}

  # Create new assets
  for name, dataUrl of newAssetMap
    splitUrl = splitDataUrl(dataUrl)
    if splitUrl.mimeType == "application/javascript"
      script = atob(splitUrl.data)
      for evaluator in evaluators
        evaluator(script)
    else if splitUrl.mimeType == "text/css"
      css = atob(splitUrl.data)
      assetNamesToData[name] = $('<style type="text/css"></style>').html(css).appendTo("head")
    else if splitUrl.mimeType.indexOf("image/") == 0
      blob = Util.dataURLToBlob(dataUrl)
      objectUrl = URL.createObjectURL(blob)

      image = new Image()
      image.src = objectUrl
      # TODO: verify that images loaded correctly?

      assetNamesToObjectUrls[name] = objectUrl
      assetNamesToData[name] = image
    else
      assetNamesToData[name] = atob(splitUrl.data)

  return newAssetMap

loadGameCode = (gameCode, callback) ->
  actions 
  try
    currentActions = JSON.parse(editors.actionsEditor.getValue())
    compiledActions = GE.mapObject currentActions, (value, key) ->
      compiledAction = {}
      try
        for actionKey, actionValue of value
          compiledAction[actionKey] = switch actionKey
            when "update" then GE.compileUpdate(actionValue, currentEvaluator)
            else actionValue
        return compiledAction
      catch compilationError
        throw new Error("Error compiling action '#{key}'. #{compilationError}")
  catch error
    logWithPrefix(GE.logLevels.ERROR, "Actions error. #{error}")
    return showMessage(MessageType.Error, "<strong>Actions error.</strong> #{error}")

  try
    currentProcesses = JSON.parse(editors.processesEditor.getValue())
    compiledProcesses = GE.mapObject currentProcesses, (value, key) ->
      compiledProcess = {}
      try
        for processKey, processValue of value
          compiledProcess[processKey] = switch processKey
            when "listActiveChildren" then GE.compileListActiveChildren(processValue, currentEvaluator)
            when "handleSignals" then GE.compileHandleSignals(processValue, currentEvaluator)
            else processValue
        return compiledProcess
      catch compilationError
        throw new Error("Error compiling process '#{key}'. #{compilationError}")
  catch error
    logWithPrefix(GE.logLevels.ERROR, "Processes error. #{error}")
    return showMessage(MessageType.Error, "<strong>Processes error.</strong> #{error}")

  try
    currentTools = JSON.parse(editors.toolsEditor.getValue())
    toolsContext = 
      tools: null
      log: null
    compiledTools = GE.mapObject currentTools, (value, key) -> 
      try
        toolFactory = GE.compileTool(value.body, toolsContext, value.args, currentEvaluator)
        return toolFactory(toolsContext)
      catch compilationError
        throw new Error("Error compiling tool '#{key}'. #{compilationError}")
    toolsContext.tools = compiledTools
    toolsContext.log = logWithPrefix
  catch error
    logWithPrefix(GE.logLevels.ERROR, "Tools error. #{error}")
    return showMessage(MessageType.Error, "<strong>Tools error.</strong> #{error}")

  try
    currentLayout = JSON.parse(editors.layoutEditor.getValue())
    # TODO: compile expressions ahead of time
  catch error
    logWithPrefix(GE.logLevels.ERROR, "Layout error. #{error}")
    return showMessage(MessageType.Error, "<strong>Layout error.</strong> #{error}")

  try
    serviceDefs = JSON.parse(editors.servicesEditor.getValue())

    # Destroy old services
    for serviceName, service of currentServices
      service.destroy()

    # Create new services
    currentServices = {}
    for serviceName, serviceDef of serviceDefs
      options = _.defaults serviceDef.options || {},
        elementSelector: '#gameContent'
        size: GAME_DIMENSIONS
      currentServices[serviceName] = services[serviceDef.type](options)
  catch error
    logWithPrefix(GE.logLevels.ERROR, "Services error. #{error}")
    return showMessage(MessageType.Error, "<strong>Services error.</strong> #{error}")

  try
    newAssets = JSON.parse(editors.assetsEditor.getValue())
    updateAssets(newAssets, currentEvaluator)
  catch error
    logWithPrefix(GE.logLevels.ERROR, "Assets error. #{error}")
    return showMessage(MessageType.Error, "<strong>Assets error.</strong> #{error}")

makeReporter = (destinationWindow, destinationOrigin) ->
  return (err, value) ->
    if err 
      destinationWindow.postMessage({ type: "error", value: value }, destinationOrigin)
    else
      destinationWindow.postMessage({ type: "done", value: value }, destinationOrigin)


# MAIN

# Dispatch incoming messages
window.addEventListener 'message', (e) ->
  # Ignore messages from self
  if e.origin == "null" then return 

  console.log("puppet received message", e)
  e.source.postMessage("your message was #{e}", e.origin)

  message = e.data
  switch message.type
    when "loadGameCode"
      loadGameCode(message.value, makeReporter(e.source, e.origin))
    else
      console.error("Unknown type for message #{message}")

