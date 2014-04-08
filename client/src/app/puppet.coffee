# CONSTANTS

# TODO: this should be configurable
GAME_DIMENSIONS = [960, 540]


# GLOBALS

loadedGame = null
lastMemory = null

isRecording = false
recordedFrames = [] # Contains objects like {memoryPatches: [], inputIoData: {}, ioPatches: []}
recordFrameReporter = null # Callback function for recording

isPlaying = false
lastPlayedFrame = null
playFrameReporter = null # Callback function for playing

# FUNCTIONS

# Find the correct function across browsers
requestAnimationFrame = window.requestAnimationFrame || window.mozRequestAnimationFrame ||
  window.webkitRequestAnimationFrame || window.msRequestAnimationFrame

# Converts pin default values (with code as strings) to compiled form with code as functions.
# Leaves non-code values as they were
compilePinDefs = (pinDefs, evaluator) ->
  return RW.mapObject pinDefs, (value, key) ->
    compiledPinParams = {}
    try
      for pinParamKey, pinParamValue of value
        compiledPinParams[pinParamKey] = switch pinParamKey
          when "default" then RW.compileExpression(pinParamValue, evaluator)
          else pinParamValue
      return compiledPinParams
    catch compilationError
      throw new Error("Error compiling pin defaults for '#{key}'. #{compilationError}")

# Converts input processors (with code as strings) to compiled form with code as functions.
# Leaves non-code values as they were
compileProcessors = (inputProcessors, evaluator) ->
  return RW.mapObject inputProcessors, (value, key) ->
    compiledProcessor = {}
    try
      for processorKey, processorValue of value
        compiledProcessor[processorKey] = switch processorKey
          when "update" then RW.compileUpdate(processorValue, evaluator)
          when "pinDefs" then compilePinDefs(processorValue, evaluator)
          else processorValue
      return compiledProcessor
    catch compilationError
      throw new Error("Error compiling processor '#{key}'. #{compilationError}")

# Converts input processors (with code as strings) to compiled form with code as functions
# Leaves non-code values as they were
compileSwitches = (inputSwitches, evaluator) ->
  return RW.mapObject inputSwitches, (value, key) ->
    compiledSwitch = {}
    try
      for switchKey, switchValue of value
        compiledSwitch[switchKey] = switch switchKey
          when "listActiveChildren" then RW.compileListActiveChildren(switchValue, evaluator)
          when "handleSignals" then RW.compileHandleSignals(switchValue, evaluator)
          when "pinDefs" then compilePinDefs(switchValue, evaluator)
          else switchValue
      return compiledSwitch
    catch compilationError
      throw new Error("Error compiling switch '#{key}'. #{compilationError}")

# Converts input transformers (with code as strings) to compiled form with code as functions.
# Leaves non-code values as they were.
compileTransformers = (inputTransformers, evaluator) ->
  transformersContext = 
    transformers: null
  compiledTransformers = RW.mapObject inputTransformers, (value, key) -> 
    try
      transformerFactory = RW.compileTransformer(value.body, value.args, evaluator)
      return transformerFactory(transformersContext)
    catch compilationError
      throw new Error("Error compiling transformer '#{key}'. #{compilationError}")
  transformersContext.transformers = compiledTransformers
  return compiledTransformers

compileExpression = (expression, evaluator, path) ->
  try 
    return RW.compileExpression(expression, evaluator)
  catch error
    throw new Error("Error compiling expression '#{expression}' for chip [#{path.join(', ')}]. #{error}")

# Converts board expressions (with code as strings) to compiled form with code as functions.
# Leaves non-code values as they were.
compileBoard = (board, evaluator, path = []) ->
  return RW.mapObject board, (value, key) ->
    switch key
      when "emitter" then RW.mapObject(value, (expression, dest) -> compileExpression(expression, evaluator, path))
      when "pins" 
        in: if value.in then RW.mapObject(value.in, (expression, pinName) -> compileExpression(expression, evaluator, path)) else {}
        out: if value.out then RW.mapObject(value.out, (expression, dest) -> compileExpression(expression, evaluator, path)) else {}
      when "splitter" then RW.mapObject value, (splitterValue, splitterKey) -> 
        switch splitterKey
          when "where" 
            if splitterValue then compileExpression(splitterValue, evaluator, path) else splitterValue
          else splitterValue
      when "children" then _.map(value, (child, key) -> compileBoard(child, evaluator, RW.appendToArray(path, key)))
      else value

destroyIo = (currentIo) ->
  for ioName, io of currentIo
    io.destroy()

initializeIo = (ioConfig) ->
  # Create new io
  currentIo = {}
  for ioName, ioData of RW.io
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
    splitUrl = RW.splitDataUrl(dataUrl)
    if splitUrl.mimeType in ["application/javascript", "text/javascript"]
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
    splitUrl = RW.splitDataUrl(dataUrl)
    if splitUrl.mimeType in ["application/javascript", "text/javascript"]
      script = atob(splitUrl.data)
      evaluator(script)
    else if splitUrl.mimeType == "text/css"
      css = atob(splitUrl.data)
      assetNamesToData[name] = $('<style type="text/css"></style>').html(css).appendTo("head")
    else if splitUrl.mimeType.indexOf("image/") == 0
      blob = RW.dataURLToBlob(dataUrl)
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
    board: compileBoard(gameCode.board, evaluator)
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

onRecordFrame = (memory) ->
  # Freeze memory so that game code can't effect it
  RW.deepFreeze(memory) 

  return RW.stepLoop
    chip: loadedGame.board
    memoryData: memory
    assets: loadedGame.assets.data
    processors: loadedGame.processors
    switches: loadedGame.switches
    io: loadedGame.io
    transformers: loadedGame.transformers

onRepeatRecordFrame = ->
  if !isRecording then return  # Stop when requested

  result = onRecordFrame(lastMemory)
  # Log result to send back in onStopRecording()
  recordedFrames.push(result)

  if result.errors
    isRecording = false
    recordFrameReporter(new Error("Errors in recording"))
  else 
    lastMemory = RW.applyPatches(result.memoryPatches, lastMemory)
    requestAnimationFrame(onRepeatRecordFrame) # Loop!

onRepeatPlayFrame = ->
  if !isPlaying then return  # Stop when requested

  # Keep result for stopPlaying message
  lastPlayedFrame = onRecordFrame(lastMemory)

  if lastPlayedFrame.errors
    isPlaying = false
    playFrameReporter(new Error("Errors in playing"))
  else 
    lastMemory = RW.applyPatches(lastPlayedFrame.memoryPatches, lastMemory)
    requestAnimationFrame(onRepeatPlayFrame) # Loop!

playBackFrame = (outputIoData) ->
  RW.stepLoop
    chip: loadedGame.board
    assets: loadedGame.assets.data
    processors: loadedGame.processors
    switches: loadedGame.switches
    io: loadedGame.io
    transformers: loadedGame.transformers
    ioConfig: {}
    outputIoData: outputIoData 

updateFrame = (memory, inputIoData) ->
  # Freeze memory so that game code can't effect it
  RW.deepFreeze(memory)
  RW.deepFreeze(inputIoData)

  return RW.stepLoop
    chip: loadedGame.board
    memoryData: memory
    assets: loadedGame.assets.data
    processors: loadedGame.processors
    switches: loadedGame.switches
    io: loadedGame.io
    transformers: loadedGame.transformers
    inputIoData: inputIoData

# Recalculate frames with different code but the same inputIoData
# TODO: don't have stepLoop() send the output data, as an optimization
onUpdateFrames = (memory, inputIoDataFrames) ->
  results = []
  lastMemory = memory
  for inputIoData in inputIoDataFrames
    result = updateFrame(lastMemory, inputIoData)
    results.push(result)
    if results.errors then return results # Return right away

    lastMemory = RW.applyPatches(result.memoryPatches, lastMemory)
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
      when "areYouAlive"
        reporter(null) # Of course we're alive!
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
      when "startPlaying"
        lastMemory = message.value.memory
        lastPlayedFrame = null
        playFrameReporter = makeReporter(e.source, e.origin, "playing")
        isPlaying = true
        requestAnimationFrame(onRepeatPlayFrame)
        reporter(null)
      when "stopPlaying"
        isPlaying = false
        # Send back just the last frame
        lastPlayedFrame.memory = lastMemory
        reporter(null, lastPlayedFrame)
      when "recordFrame"
        results = onRecordFrame(message.value.memory)
        reporter(null, results)
      when "playBackFrame"
        playBackFrame(message.value.outputIoData)
        reporter(null)
      when "updateFrames"
        results = onUpdateFrames(message.value.memory, message.value.inputIoDataFrames)
        # TODO: check for errors and return them along with other data
        reporter(null, results)
      else
        throw new Error("Unknown type for message #{message}")
  catch error
    return reporter(error, message.operation)

