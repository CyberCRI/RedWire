# CONSTANTS

# TODO: this should be configurable
GAME_DIMENSIONS = [960, 540]


# GLOBALS

loadedGame = null
isRecording = false
lastMemory = null
recordedFrames = [] # Contains objects like {memoryPatches: [], inputIoData: {}, ioPatches: []}
recordFrameReporter = null # Callback function for onRecordFrame

# FUNCTIONS

# Find the correct function across browsers
requestAnimationFrame = window.requestAnimationFrame || window.mozRequestAnimationFrame ||
  window.webkitRequestAnimationFrame || window.msRequestAnimationFrame

# Converts input processors (with code as strings) to compiled form with code as functions.
# Leaves non-code values as they were
compileProcessors = (inputProcessors, evaluator) ->
  return GE.mapObject inputProcessors, (value, key) ->
    compiledProcessor = {}
    try
      for processorKey, processorValue of value
        compiledProcessor[processorKey] = switch processorKey
          when "update" then GE.compileUpdate(processorValue, evaluator)
          else processorValue
      return compiledProcessor
    catch compilationError
      throw new Error("Error compiling processor '#{key}'. #{compilationError}")

# Converts input processors (with code as strings) to compiled form with code as functions
# Leaves non-code values as they were
compileSwitches = (inputSwitches, evaluator) ->
  return GE.mapObject inputSwitches, (value, key) ->
    compiledSwitch = {}
    try
      for switchKey, switchValue of value
        compiledSwitch[switchKey] = switch switchKey
          when "listActiveChildren" then GE.compileListActiveChildren(switchValue, evaluator)
          when "handleSignals" then GE.compileHandleSignals(switchValue, evaluator)
          else switchValue
      return compiledSwitch
    catch compilationError
      throw new Error("Error compiling switch '#{key}'. #{compilationError}")

# Converts input transformers (with code as strings) to compiled form with code as functions.
# Leaves non-code values as they were.
compileTransformers = (inputTransformers, evaluator) ->
  transformersContext = 
    transformers: null
  compiledTransformers = GE.mapObject inputTransformers, (value, key) -> 
    try
      transformerFactory = GE.compileTransformer(value.body, value.args, evaluator)
      return transformerFactory(transformersContext)
    catch compilationError
      throw new Error("Error compiling transformer '#{key}'. #{compilationError}")
  transformersContext.transformers = compiledTransformers
  return compiledTransformers

destroyIo = (currentIo) ->
  for ioName, io of currentIo
    io.destroy()

initializeIo = (ioConfig) ->
  # Create new io
  currentIo = {}
  for ioName, ioData of GE.io
    try
      options = 
        elementSelector: '#gameContent'
        size: GAME_DIMENSIONS
      if ioData.meta.visual
        options.layers = _.object(([layer.name, index] for index, layer of ioConfig.layers when layer.type is ioName ))

      currentIo[ioName] = ioData.factory(options)
    catch error
      throw new Error("Error initializing io '#{ioName}'. #{error}")
  return currentIo

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
# TODO: move asset handling into gamEvolve.coffee. CSS could be handled by the HTML io. JS is harder.
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
    processors: compileProcessors(gameCode.processors, evaluator)
    switches: compileSwitches(gameCode.switches, evaluator)
    transformers: compileTransformers(gameCode.transformers, evaluator, logFunction)
    board: gameCode.board
    io: initializeIo(gameCode.io)
    assets: createAssets(gameCode.assets, evaluator)
    evaluator: evaluator
  }

unloadGame = (loadedGame) ->
  destroyAssets(loadedGame.assets)
  destroyIo(loadedGame.io)

makeReporter = (destinationWindow, destinationOrigin, operation) ->
  return (err, value) ->
    if err 
      destinationWindow.postMessage({ type: "error", operation: operation, error: err.stack, path: err.path }, destinationOrigin)
    else
      destinationWindow.postMessage({ type: "success", operation: operation, value: value }, destinationOrigin)

onRecordFrame = (memory, inputIoData = null) ->
  return GE.stepLoop
    chip: loadedGame.board
    memoryData: memory
    assets: loadedGame.assets.data
    processors: loadedGame.processors
    switches: loadedGame.switches
    io: loadedGame.io
    transformers: loadedGame.transformers
    evaluator: eval
    ioConfig: {}
    log: null
    inputIoData: inputIoData
    outputIoData: null 

onRepeatRecordFrame = ->
  if !isRecording then return  # Stop when requested

  try
    result = onRecordFrame(lastMemory)

    # Log result to send back in onStopRecording()
    recordedFrames.push(result)
    lastMemory = GE.applyPatches(result.memoryPatches, lastMemory)

    requestAnimationFrame(onRepeatRecordFrame) # Loop!
  catch e
    # TODO: send back current frame results, even if they conflict or other error arises
    isRecording = false
    recordFrameReporter(e)

onPlayFrame = (outputIoData) ->
  GE.stepLoop
    chip: loadedGame.board
    assets: loadedGame.assets.data
    processors: loadedGame.processors
    switches: loadedGame.switches
    io: loadedGame.io
    transformers: loadedGame.transformers
    ioConfig: {}
    outputIoData: outputIoData 

# Recalculate frames with different code but the same inputIoData
# TODO: don't have stepLoop() send the output data, as an optimization
onUpdateFrames = (memory, inputIoDataFrames) ->
  results = []
  lastMemory = memory
  for inputIoData in inputIoDataFrames
    result = onRecordFrame(lastMemory, inputIoData)
    results.push(result)
    if results.errors then return results # Return right away

    lastMemory = GE.applyPatches(result.memoryPatches, lastMemory)
  return results

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
      when "startRecording"
        lastMemory = message.value.memory
        recordedFrames = []
        recordFrameReporter = makeReporter(e.source, e.origin, "recording")
        isRecording = true
        requestAnimationFrame(onRepeatRecordFrame)
        reporter(null)
      when "stopRecording"
        isRecording = false
        reporter(null, recordedFrames)
      when "recordFrame"
        results = onRecordFrame(message.value.memory)
        reporter(null, results)
      when "playFrame"
        onPlayFrame(message.value.outputIoData)
        reporter(null)
      when "updateFrames"
        results = onUpdateFrames(message.value.memory, message.value.inputIoDataFrames)
        # TODO: check for errors and return them along with other data
        reporter(null, results)
      else
        throw new Error("Unknown type for message #{message}")
  catch error
    return reporter(error, message.operation)

