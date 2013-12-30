# CONSTANTS

# TODO: this should be configurable
GAME_DIMENSIONS = [960, 540]


# GLOBALS

loadedGame = null
isRecording = false
lastModel = null
recordedFrames = [] # Contains objects like {modelPatches: [], inputServiceData: {}, servicePatches: []}
recordFrameReporter = null # Callback function for onRecordFrame


# FUNCTIONS

# Find the correct function across browsers
requestAnimationFrame = window.requestAnimationFrame || window.mozRequestAnimationFrame ||
  window.webkitRequestAnimationFrame || window.msRequestAnimationFrame

# Converts input actions (with code as strings) to compiled form with code as functions.
# Leaves non-code values as they were
compileActions = (inputActions, evaluator) ->
  return GE.mapObject inputActions, (value, key) ->
    compiledAction = {}
    try
      for actionKey, actionValue of value
        compiledAction[actionKey] = switch actionKey
          when "update" then GE.compileUpdate(actionValue, evaluator)
          else actionValue
      return compiledAction
    catch compilationError
      throw new Error("Error compiling action '#{key}'. #{compilationError}")

# Converts input actions (with code as strings) to compiled form with code as functions
# Leaves non-code values as they were
compileProcesses = (inputProcesses, evaluator) ->
  return GE.mapObject inputProcesses, (value, key) ->
    compiledProcess = {}
    try
      for processKey, processValue of value
        compiledProcess[processKey] = switch processKey
          when "listActiveChildren" then GE.compileListActiveChildren(processValue, evaluator)
          when "handleSignals" then GE.compileHandleSignals(processValue, evaluator)
          else processValue
      return compiledProcess
    catch compilationError
      throw new Error("Error compiling process '#{key}'. #{compilationError}")

# Converts input tools (with code as strings) to compiled form with code as functions.
# The logFunction will be provided to all tools
# Leaves non-code values as they were.
compileTools = (inputTools, evaluator, logFunction) ->
  toolsContext = 
    tools: null
    log: null
  compiledTools = GE.mapObject inputTools, (value, key) -> 
    try
      toolFactory = GE.compileTool(value.body, toolsContext, value.args, evaluator)
      return toolFactory(toolsContext)
    catch compilationError
      throw new Error("Error compiling tool '#{key}'. #{compilationError}")
  toolsContext.tools = compiledTools
  toolsContext.log = logFunction
  return compiledTools

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
      currentServices[serviceName] = GE.services[serviceDef.type](options)
    catch error
      throw new Error("Error initializing service '#{serviceName}'. #{error}")
  return currentServices

destroyAssets = (oldAssets) ->
  for name, dataUrl of oldAssets.urls
    splitUrl = GE.splitDataUrl(dataUrl)
    if splitUrl.mimeType == "application/javascript"
      # Nothing to do, cannot unload JS!
    else if splitUrl.mimeType == "text/css"
      oldAssets.data[name].remove()
    else if splitUrl.mimeType.indexOf("image/") == 0
      URL.revokeObjectURL(oldAssets.objectUrls[name])

# The evaluator is initialized with any JS assets.
# Returns object containing three maps: { urls: , data: , objectUrls: }
# TODO: move asset handling into gamEvolve.coffee. CSS could be handled by the HTML service. JS is harder.
createAssets = (inputAssets, evaluator) ->
  assetNamesToData = {}
  assetNamesToObjectUrls = {}

  # Create new assets
  for name, dataUrl of inputAssets
    splitUrl = GE.splitDataUrl(dataUrl)
    if splitUrl.mimeType == "application/javascript"
      script = atob(splitUrl.data)
      evaluator(script)
    else if splitUrl.mimeType == "text/css"
      css = atob(splitUrl.data)
      assetNamesToData[name] = $('<style type="text/css"></style>').html(css).appendTo("head")
    else if splitUrl.mimeType.indexOf("image/") == 0
      blob = GE.dataURLToBlob(dataUrl)
      objectUrl = URL.createObjectURL(blob)

      image = new Image()
      image.src = objectUrl
      # TODO: verify that images loaded correctly?

      assetNamesToObjectUrls[name] = objectUrl
      assetNamesToData[name] = image
    else
      assetNamesToData[name] = atob(splitUrl.data)

  return { urls: inputAssets, data: assetNamesToData, objectUrls: assetNamesToObjectUrls }

loadGameCode = (gameCode, logFunction) ->
  evaluator = eval
  return {
    actions: compileActions(gameCode.actions, evaluator)
    processes: compileProcesses(gameCode.processes, evaluator)
    tools: compileTools(gameCode.tools, evaluator, logFunction)
    layout: gameCode.layout
    services: initializeServices(gameCode.services)
    assets: createAssets(gameCode.assets, evaluator)
    evaluator: evaluator
  }

unloadGame = (loadedGame) ->
  destroyAssets(loadedGame.assets)
  destroyServices(loadedGame.services)

makeReporter = (destinationWindow, destinationOrigin, operation) ->
  return (err, value) ->
    if err 
      destinationWindow.postMessage({ type: "error", operation: operation, error: err.stack }, destinationOrigin)
    else
      destinationWindow.postMessage({ type: "success", operation: operation, value: value }, destinationOrigin)

onRecordFrame = ->
  if !isRecording then return  # Stop when requested

  try
    result = GE.stepLoop
      node: loadedGame.layout
      modelData: lastModel
      assets: loadedGame.assets.data
      actions: loadedGame.actions
      processes: loadedGame.processes
      services: loadedGame.services
      tools: loadedGame.tools
      evaluator: eval
      serviceConfig: {}
      log: null
      inputServiceData: null
      outputServiceData: null 

    # Log result to send back in onStopRecording()
    recordedFrames.push(result)
    lastModel = GE.applyPatches(result.modelPatches, lastModel)

    requestAnimationFrame(onRecordFrame) # Loop!
  catch e
    # TODO: send back current frame results, even if they conflict or other error arises
    isRecording = false
    recordFrameReporter(e)


# MAIN

# Dispatch incoming messages
window.addEventListener 'message', (e) ->
  # Ignore messages from self
  if e.origin == "null" then return 

  message = e.data
  reporter = makeReporter(e.source, e.origin, message.operation)

  try 
    switch message.operation
      when "changeScale"
        $("#gameContent").css 
          "-webkit-transform": "scale(#{message.value})"
          "transform": "scale(#{message.value})"
        reporter(null)
      when "loadGameCode"
        if loadedGame? then unloadGame(loadedGame)
        loadedGame = loadGameCode(message.value)
        reporter(null)
      when "stepLoop"
        result = GE.stepLoop
          node: loadedGame.layout
          modelData: message.value.model
          assets: loadedGame.assets.data
          actions: loadedGame.actions
          processes: loadedGame.processes
          services: loadedGame.services
          tools: loadedGame.tools
          evaluator: eval
          serviceConfig: {}
          log: null
          inputServiceData: null
          outputServiceData: null 
        reporter(null, result)
      when "startRecording"
        lastModel = message.value.model
        recordedFrames = []
        recordFrameReporter = makeReporter(e.source, e.origin, "recording")
        isRecording = true
        requestAnimationFrame(onRecordFrame)
        reporter(null, result)
      when "stopRecording"
        isRecording = false
        reporter(null, recordedFrames)
      else
        throw new Error("Unknown type for message #{message}")
  catch error
    return reporter(error, message.operation)

