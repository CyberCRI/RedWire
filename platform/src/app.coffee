### Constants ###

globals = @

CODE_CHANGE_TIMEOUT = 1000
MODEL_FORMATTING_INDENTATION = 2
GAME_DIMENSIONS = [960, 540]

MessageType = GE.makeConstantSet("Error", "Info")

SPINNER_OPTS = 
  lines: 9
  length: 7
  width: 4
  radius: 10
  corners: 1
  rotate: 0
  color: '#000'
  speed: 1
  trail: 60
  shadow: false
  hwaccel: false
  className: 'spinner'
  zIndex: 2e9
  top: 'auto'
  left: 'auto'

EVAL_ASSETS = 
  underscore: "lib/underscore/underscore.js"
  gamEvolveCommon: "gamEvolveCommon.js"
  sylvester: "lib/sylvester/sylvester.src.js"

GAME_JSON_PROPERTY_TO_EDITOR =
  model: "modelEditor"
  assets: "assetsEditor"
  actions: "actionsEditor"
  tools: "toolsEditor"
  layout: "layoutEditor"
  services: "servicesEditor"


### Globals ###

editors = {}
log = null
evalLoadedAssets = []

services = {}

spinner = new Spinner(SPINNER_OPTS)

currentModel = new GE.Model()
currentFrame = 0
currentModelData = null
currentAssets = null
currentActions = null
currentTools = null
currentLayout = null
currentServices = null
currentEvaluator = null

assetNamesToData = {} 
assetNamesToObjectUrls = {}

compiledActions = {}
compiledTools = {}

isPlaying = false
automaticallyUpdatingModel = false
gameScreenScale = 1

# Find the correct function across browsers
requestAnimationFrame = window.requestAnimationFrame || window.mozRequestAnimationFrame ||
  window.webkitRequestAnimationFrame || window.msRequestAnimationFrame

### Functions ###

adjustEditorToSize = (editor) -> 
  session = editor.session

  editor.resize()
  if session.getUseWrapMode()
    characterWidth = editor.renderer.characterWidth
    contentWidth = editor.renderer.scroller.clientWidth

    if contentWidth > 0  
      limit = parseInt(contentWidth / characterWidth, 10)
      session.setWrapLimitRange(limit, limit)

handleResize = -> 
  # Update the ACE editors
  for editorName, editor of editors then adjustEditorToSize(editor)
  adjustEditorToSize(log)

  # Update the scale sent to stepLoop()
  screenElement = $('#gameContent')
  scale = Math.min(screenElement.parent().outerWidth() / GAME_DIMENSIONS[0], screenElement.parent().outerHeight() / GAME_DIMENSIONS[1])
  roundedScale = scale.toFixed(2)
  newSize = [
    screenElement.parent().outerWidth() - roundedScale * GAME_DIMENSIONS[0]
    screenElement.parent().outerHeight() - roundedScale * GAME_DIMENSIONS[1]
  ]
  screenElement.css 
    "-webkit-transform": "scale(#{roundedScale})"
    "transform": "scale(#{roundedScale})"
    "width": "#{newSize[0]}px"
    "height": "#{newSize[1]}px"
    "left": "#{newSize[0] / 2}px"
    "top": "#{newSize[1] / 2}px"

showMessage = (messageType, message) ->
  switch messageType
    when MessageType.Error
      $("#topAlertMessage").html(message)
      $("#topAlert").show()
    when MessageType.Info
      $("#topInfoMessage").html(message)
      $("#topInfo").show()
    else throw new Error("Incorrect messageType")

clearMessage = -> $("#topAlert, #topInfo").hide()

logWithPrefix = (logType, values...) ->
  if GE.logLevels[logType]
    log.clearSelection()
    log.navigateFileEnd()
    valueStrings = for value in values 
      if _.isString(value) then value else JSON.stringify(value)
    log.insert(logType+": "+getFormattedTime()+" "+valueStrings.join("  ")+"\n")
  else
    logWithPrefix(GE.logLevels.ERROR, "Bad logType parameter '"+logType+"' in log for message '"+message+"'")

togglePlayMode = ->
  if isPlaying
    isPlaying = false
    for editorId, editor of editors
      editor.setReadOnly(false)
      $('#'+editorId).fadeTo('slow', 1)
    $("#playButton").button "option",
      label: "Play" 
      icons: 
        primary: "ui-icon-play"
  else
    isPlaying = true
    for editorId, editor of editors
      editor.setReadOnly(true)
      $('#'+editorId).fadeTo('slow', 0.2)
    handleAnimation()
    $("#playButton").button "option",
      label: "Pause" 
      icons: 
        primary: "ui-icon-pause"

setupLayout = ->
  # top
  $("#saveButton")
    .button({ icons: { primary: "ui-icon-transferthick-e-w" }})
    .click( -> Games.save(Games.current))
  $("#shareButton")
    .button({ icons: { primary: "ui-icon-link" }})
    .click( -> Games.share({method:"to implement"}))

  # west
  $("#playButton").button({ icons: { primary: "ui-icon-play" }, text: false })
  $("#timeSlider").slider
    orientation: "horizontal"
    range: "min"
    min: 0
    max: 0
    step: 1
    value: 0
  $("#resetButton").button({ icons: { primary: "ui-icon-arrowreturnthick-1-w" }, text: false })

  $("#west").tabs()
  $("#south").tabs().addClass( "ui-tabs-vertical ui-helper-clearfix" )
  $("#south li").removeClass( "ui-corner-top" ).addClass( "ui-corner-left" )
  $("#south li a").click(handleResize)

  # TODO: look for a callback for tabs
  $('body').layout 
    north__resizable: false
    north__closable: false
    north__size: 50
    west__size: 300
    applyDefaultStyles: true
    onresize: handleResize

setupButtonHandlers = ->
  $("#playButton").on "click", togglePlayMode

  $("#resetButton").on "click", ->
    currentFrame = 0
    currentModel = currentModel.atVersion(0)
    resetLogContent()

    # TODO: move these handlers to MVC events
    $("#timeSlider").slider "option", 
      value: 0
      max: 0

    automaticallyUpdatingModel = true
    editors.modelEditor.setValue(JSON.stringify(currentModel.data, null, MODEL_FORMATTING_INDENTATION))
    # The new content will be selected by default
    editors.modelEditor.selection.clearSelection() 
    automaticallyUpdatingModel = false

    # Execute again
    executeCode()

  $("#timeSlider").on "slide", ->
    currentFrame = $(this).slider("value")

    # If done immediately, will block slider movement, so we postpone it
    GE.doLater ->
      automaticallyUpdatingModel = true
      editors.modelEditor.setValue(JSON.stringify(currentModel.atVersion(currentFrame).data, null, MODEL_FORMATTING_INDENTATION))
      # The new content will be selected by default
      editors.modelEditor.selection.clearSelection() 
      automaticallyUpdatingModel = false

      # Execute again
      executeCode()

# Mode should be something that ACE Editor recognizes, like "ace/mode/javascript"
setupEditor = (id, mode = "") ->
  editor = ace.edit(id)
  if mode then editor.getSession().setMode(mode)
  editor.getSession().setUseWrapMode(true)
  editor.setWrapBehavioursEnabled(true)
  return editor

reloadCode = (callback) ->
  #programId = window.location.search.slice(1)

  currentEvaluator = GE.makeEvaluator(evalLoadedAssets...)

  try
    currentModelData = JSON.parse(editors.modelEditor.getValue())
  catch error
    logWithPrefix(GE.logLevels.ERROR, "Model error. #{error}")
    return showMessage(MessageType.Error, "<strong>Model error.</strong> #{error}")

  try
    currentActions = JSON.parse(editors.actionsEditor.getValue())
    compiledActions = GE.mapObject currentActions, (value, key) ->
      compiledAction = {}
      try
        for actionKey, actionValue of value
          compiledAction[actionKey] = switch actionKey
            when "update" then GE.compileUpdate(actionValue, currentEvaluator)
            when "listActiveChildren" then GE.compileListActiveChildren(actionValue, currentEvaluator)
            when "handleSignals" then GE.compileHandleSignals(actionValue, currentEvaluator)
            else actionValue
      catch compilationError
        throw new Error("Error compiling action '#{key}'. #{compilationError}")
      return compiledAction
  catch error
    logWithPrefix(GE.logLevels.ERROR, "Actions error. #{error}")
    return showMessage(MessageType.Error, "<strong>Actions error.</strong> #{error}")

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

  # TODO: move these handlers to MVC events
  currentModel.atVersion(currentFrame).data = currentModelData

  $("#timeSlider").slider "option", 
    value: currentFrame
    max: currentFrame

  logWithPrefix(GE.logLevels.INFO, "Game updated")
  showMessage(MessageType.Info, "Game updated")
  callback(null)

# Unload previous assets and load new ones. The given list of evaluators are initialized with any JS assets.
# Updates currentAssets.
# TODO: move asset handling into gamEvolve.coffee. CSS could be handled by the HTML service. JS is harder.
updateAssets = (newAssetMap, evaluators...) ->
  # Remove old assets
  # TODO: Only update new assets
  for name, dataUrl of currentAssets
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

  currentAssets = newAssetMap

# Runs the currently loaded code on the current frame
# Returns a new model
executeCode = ->
  modelAtFrame = currentModel.atVersion(currentFrame)

  try 
    modelPatches = GE.stepLoop
      node: currentLayout
      modelData: modelAtFrame.clonedData()
      assets: assetNamesToData
      actions: compiledActions
      tools: compiledTools
      services: currentServices
      serviceConfig: 
        scale: gameScreenScale
      evaluator: currentEvaluator
      log: logWithPrefix
    if modelPatches.length > 0 then logWithPrefix(GE.logLevels.LOG, "Model patches are: #{JSON.stringify(modelPatches)}.")
    return modelAtFrame.applyPatches(modelPatches)
  catch error
    logWithPrefix(GE.logLevels.ERROR, "Error executing code: #{error}")
    showMessage(MessageType.Error, "Error executing code")
    if isPlaying then togglePlayMode() # Stop on error
    return currentModel

notifyCodeChange = ->
  if automaticallyUpdatingModel then return false

  timeoutCallback = ->
    spinner.stop()
    saveCodeToCache()
    reloadCode (err) -> if !err then executeCode()

  spinner.spin($("#north")[0]) 
  clearMessage()

  # cancel previous timeout
  if notifyCodeChange.timeoutId 
    window.clearTimeout(notifyCodeChange.timeoutId)
    notifyCodeChange.timeoutId = null

  # TODO: catch exceptions here?
  notifyCodeChange.timeoutId = window.setTimeout(timeoutCallback, CODE_CHANGE_TIMEOUT)

handleAnimation = ->
  if not isPlaying then return false

  currentModel = executeCode()
  currentFrame++

  $("#timeSlider").slider "option", 
    value: currentFrame
    max: currentFrame

  automaticallyUpdatingModel = true
  editors.modelEditor.setValue(JSON.stringify(currentModel.data, null, MODEL_FORMATTING_INDENTATION))
  # The new contect will be selected by default
  editors.modelEditor.selection.clearSelection() 
  automaticallyUpdatingModel = false

  requestAnimationFrame(handleAnimation)

# Saves all editor contents to LocalStorage
saveCodeToCache = (programId) ->
  # TODO: should check that currentFrame == 0 before saving model
  codeToCache = {}
  for id, editor of editors
    codeToCache[id] = editor.getValue()

  cachedCodeJson = JSON.stringify(codeToCache)
  localStorage.setItem(programId, cachedCodeJson)

# Loads all editor contents from LocalStorage as JSON and returns it
# If nothing was stored, returns null
loadCodeFromCache = (programId) -> return localStorage.getItem(programId)

# Sets cached code in the editors
setCodeFromCache = (cachedCodeJson) ->
  cachedCode = JSON.parse(cachedCodeJson)

  for id, editor of editors
    editor.setValue(cachedCode[id])
    # The new contect will be selected by default
    editor.selection.clearSelection() 

# Remove code in LocalStorage
clearCodeInCache = (programId) -> localStorage.removeItem(programId)

# Add the factory so it can be used later
registerService = (name, factory) -> services[name] = factory

# TODO: find a better way to export functions
globals.registerService = registerService

# Reset log content
resetLogContent = ->
  logWithPrefix(GE.logLevels.WARN, "Log content is being reset")
  log.setValue("");
  log.clearSelection();
  
  logWithPrefix(GE.logLevels.INFO, "Reset log")

# Add a leading zero if necessary to have a number take 2 digits
zeroPad = (number) -> if number < 10 then "0" + number else number

getFormattedTime = ->
  date = new Date()
  return "#{zeroPad(date.getHours())}:#{zeroPad(date.getMinutes())}:#{zeroPad(date.getSeconds())}"

# Returns an object { mimeType: String, base64: Bool, data: String}
splitDataUrl = (url) -> 
  matches = url.match(/data:([^;]+);([^,]*),(.*)/)
  return {
    mimeType: matches[1]
    base64: matches[2] == "base64"
    data: matches[3]
  }


### Main ###

$(document).ready ->
  # A hash needs to be set, or we won't be able to load the code
  if not window.location.search 
    # Reload the page
    return window.location.search = "?optics"

  setupLayout()
  setupButtonHandlers()

  $(window).on "onresize", handleResize

  # Create all the JSON and JS editors
  for id in ["modelEditor", "assetsEditor", "actionsEditor", "toolsEditor", "layoutEditor", "servicesEditor"]
    editors[id] = setupEditor(id, "ace/mode/javascript")

  # Create the log, which is plain text
  log = setupEditor("log")
  log.setReadOnly(true)
  resetLogContent()
  handleResize()

  # Offer to load code from the cache if we can
  loadedCode = false
  # TODO: re-enable cache 
  ### 
  cachedCodeJson = loadCodeFromCache(programId)
  if cachedCodeJson
    if window.confirm("You had made changes to this code. Should we load your last version?")
      setCodeFromCache(cachedCodeJson)
      loadedCode = true
    else 
      clearCodeInCache(programId)
  ###

  # Otherwise just load from a URL
  if not loadedCode
    gameName = window.location.search.slice(1)
    Games.loadJson gameName, (gameJson) ->
      Games.current = gameJson
      for property, editorId of GAME_JSON_PROPERTY_TO_EDITOR
        editor = editors[editorId]
        editor.setValue(gameJson[property])
        # The new content will be selected by default
        editor.selection.clearSelection()

      # Load common script assets
      GE.loadAssets EVAL_ASSETS, (err, loadedAssets) ->
        if err then return showMessage(MessageType.Error, "Cannot load common assets")

        # Make this globally available
        evalLoadedAssets = (script for name, script of loadedAssets)

        # Setup event handlers on code change
        for id in ["modelEditor", "assetsEditor", "actionsEditor", "toolsEditor", "layoutEditor", "servicesEditor"]
          editors[id].getSession().on "change", -> notifyCodeChange()

        # Load code
        notifyCodeChange()
