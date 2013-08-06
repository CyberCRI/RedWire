### Constants ###

globals = @

CODE_CHANGE_TIMEOUT = 1000
MODEL_FORMATTING_INDENTATION = 2

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

EDITOR_URL_PAIRS = [
  ["modelEditor", "model.json"]
  ["assetsEditor", "assets.json"]
  ["actionsEditor", "actions.js"] 
  ["toolsEditor", "tools.js"]
  ["layoutEditor", "layout.json"]
  ["servicesEditor", "services.json"]
]


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
currentLoadedAssets = null
currentExpressionEvaluator = null

isPlaying = false
automaticallyUpdatingModel = false

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
  for editorName, editor of editors then adjustEditorToSize(editor)
  adjustEditorToSize(log)

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
  $("#saveButton").button({ icons: { primary: "ui-icon-transferthick-e-w" }})
  $("#shareButton").button({ icons: { primary: "ui-icon-link" }})

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

loadIntoEditor = (editor, url) ->
  return $.ajax
    url: url
    dataType: "text"
    cache: false
    success: (data) -> 
      editor.setValue(data)
      # The new content will be selected by default
      editor.selection.clearSelection() 

reloadCode = (callback) ->
  programId = window.location.search.slice(1)

  try
    currentAssets = JSON.parse(editors.assetsEditor.getValue())
    # Prefix the asset URLS with the location of the game files
    for name, url of currentAssets
      currentAssets[name] = programId + url
  catch error
    logWithPrefix(GE.logLevels.ERROR, "Assets error. #{error}")
    return showMessage(MessageType.Error, "<strong>Assets error.</strong> #{error}")

  try
    currentModelData = JSON.parse(editors.modelEditor.getValue())
  catch error
    logWithPrefix(GE.logLevels.ERROR, "Model error. #{error}")
    return showMessage(MessageType.Error, "<strong>Model error.</strong> #{error}")

  # We will use actionEvaluator later to evaluate all loaded JS assets
  actionsEvaluator = GE.makeEvaluator(evalLoadedAssets...)
  try
    currentActions = actionsEvaluator(editors.actionsEditor.getValue())
  catch error
    logWithPrefix(GE.logLevels.ERROR, "Actions error. #{error}")
    return showMessage(MessageType.Error, "<strong>Actions error.</strong> #{error}")

  # We will use toolsEvaluator later to evaluate all loaded JS assets
  toolsEvaluator = GE.makeEvaluator(evalLoadedAssets...)
  try
    currentTools = toolsEvaluator(editors.toolsEditor.getValue())
    currentTools.log = logWithPrefix # Expose the log() function to tools
  catch error
    logWithPrefix(GE.logLevels.ERROR, "Tools error. #{error}")
    return showMessage(MessageType.Error, "<strong>Tools error.</strong> #{error}")

  try
    currentLayout = JSON.parse(editors.layoutEditor.getValue())
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
      currentServices[serviceName] = services[serviceDef.type](serviceDef.options)
  catch error
    logWithPrefix(GE.logLevels.ERROR, "Services error. #{error}")
    return showMessage(MessageType.Error, "<strong>Services error.</strong> #{error}")

  GE.loadAssets currentAssets, (err, loadedAssets) =>
    if err? 
      logWithPrefix(GE.logLevels.ERROR, "Cannot load assets. #{err}")
      showMessage(MessageType.Error, "Cannot load assets. #{err}")
      return callback(err)

    # Execute all JS assets in the actions and tools sandbox, so that actions have access
    for name, url of currentAssets 
      if GE.determineAssetType(url) is "JS" 
        for evaluator in [actionsEvaluator, toolsEvaluator] 
          evaluator(loadedAssets[name])

    currentExpressionEvaluator = GE.makeEvaluator(evalLoadedAssets...)

    currentLoadedAssets = loadedAssets

    # TODO: move these handlers to MVC events
    currentModel.atVersion(currentFrame).data = currentModelData

    $("#timeSlider").slider "option", 
      value: currentFrame
      max: currentFrame

    logWithPrefix(GE.logLevels.INFO, "Game updated")
    showMessage(MessageType.Info, "Game updated")
    callback(null)

# Runs the currently loaded code on the current frame
# Returns a new model
executeCode = ->
  modelAtFrame = currentModel.atVersion(currentFrame)

  try 
    modelPatches = GE.stepLoop
      node: currentLayout
      modelData: modelAtFrame.clonedData()
      assets: currentLoadedAssets
      actions: currentActions
      tools: currentTools
      services: currentServices
      evaluator: currentExpressionEvaluator
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

zeroPad = (number) -> if number < 10 then "0" + number else number

getFormattedTime = ->
  date = new Date()
  return "#{zeroPad(date.getHours())}:#{zeroPad(date.getMinutes())}:#{zeroPad(date.getSeconds())}"

### Main ###

$(document).ready ->
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

  # A hash needs to be set, or we won't be able to load the code
  if not window.location.search then window.location.search = "?optics/"
  programId = window.location.search.slice(1)

  # Offer to load code from the cache if we can
  loadedCode = false
  cachedCodeJson = loadCodeFromCache(programId)
  if cachedCodeJson
    if window.confirm("You had made changes to this code. Should we load your last version?")
      setCodeFromCache(cachedCodeJson)
      loadedCode = true
    else 
      clearCodeInCache(programId)

  # Otherwise just load from a local directory
  if not loadedCode
    ajaxRequests = (loadIntoEditor(editors[id], "#{programId}#{url}") for [id, url] in EDITOR_URL_PAIRS)
    $.when(ajaxRequests...).fail(-> showMessage(MessageType.Error, "Cannot load game files")).then ->
      # Load common assets
      GE.loadAssets EVAL_ASSETS, (err, loadedAssets) ->
        if err then return showMessage(MessageType.Error, "Cannot load common assets")

        # Make this globally available
        evalLoadedAssets = (script for name, script of loadedAssets)

        # Setup event handlers on code change
        for id in ["modelEditor", "assetsEditor", "actionsEditor", "toolsEditor", "layoutEditor", "servicesEditor"]
          editors[id].getSession().on "change", -> notifyCodeChange()

        # Load code
        notifyCodeChange()

