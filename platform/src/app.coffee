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


### Globals ###

editors = {}
log = null

services = {}

spinner = new Spinner(SPINNER_OPTS)

currentModel = new GE.Model()
currentFrame = 0
currentModelData = null
currentAssets = null
currentActions = null
currentLayout = null
currentServices = null
currentLoadedAssets = null

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

logWithPrefix = (logType, message, newLine = true) ->
  if GE.logLevels[logType]
    log.clearSelection()
    log.navigateFileEnd()
    log.insert(logType+": "+getFormattedTime()+" "+message+if newLine then "\n" else "")
  else
    logWithPrefix(GE.logLevels.ERROR, "Bad logType parameter '"+logType+"' in log for message '"+message+"'")

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
  # TODO: lock code down in play mode so it can't be changed

  $("#playButton").on "click", ->
    if isPlaying
      isPlaying = false
      for editorId, editor of editors
        editor.setReadOnly(false)
        $('#'+editorId).fadeTo('slow', 1)
      $(this).button "option",
        label: "Play" 
        icons: 
          primary: "ui-icon-play"
    else
      isPlaying = true
      for editorId, editor of editors
        editor.setReadOnly(true)
        $('#'+editorId).fadeTo('slow', 0.2)
      handleAnimation()
      $(this).button "option",
        label: "Pause" 
        icons: 
          primary: "ui-icon-pause"

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
  $.ajax
    url: url
    dataType: "text"
    cache: false
    success: (data) -> 
      editor.setValue(data)
      # The new content will be selected by default
      editor.selection.clearSelection() 

reloadCode = (callback) ->
  try
    currentAssets = JSON.parse(editors.assetsEditor.getValue())
  catch error
    logWithPrefix(GE.logLevels.ERROR, "Assets error. #{error}")
    return showMessage(MessageType.Error, "<strong>Assets error.</strong> #{error}")

  try
    currentModelData = JSON.parse(editors.modelEditor.getValue())
  catch error
    logWithPrefix(GE.logLevels.ERROR, "Model error. #{error}")
    return showMessage(MessageType.Error, "<strong>Model error.</strong> #{error}")

  try
    currentActions = eval(editors.actionsEditor.getValue())
  catch error
    logWithPrefix(GE.logLevels.ERROR, "Actions error. #{error}")
    return showMessage(MessageType.Error, "<strong>Actions error.</strong> #{error}")

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
      logWithPrefix(GE.logLevels.ERROR, "Cannot load assets")
      showMessage(MessageType.Error, "Cannot load assets")
      callback(err)

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

  # GE.stepLoop = (node, modelData, assets, actions, services, log, inputServiceData = null, outputServiceData = null) 
  modelPatches = GE.stepLoop(currentLayout, modelAtFrame.clonedData(), currentLoadedAssets, currentActions, currentServices, logWithPrefix)

  return modelAtFrame.applyPatches(modelPatches)

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
saveCodeToCache = ->
  programId = window.location.hash.slice(1)
  if !programId then throw new Error("No program ID to save")

  # TODO: should check that currentFrame == 0 before saving model
  codeToCache = {}
  for id, editor of editors
    codeToCache[id] = editor.getValue()

  cachedCodeJson = JSON.stringify(codeToCache)
  localStorage.setItem(programId, cachedCodeJson)

# Loads all editor contents from LocalStorage as JSON and returns it
# If nothing was stored, returns null
loadCodeFromCache = ->
  programId = window.location.hash.slice(1)
  if !programId then throw new Error("No program ID to load")

  return localStorage.getItem(programId)

# Sets cached code in the editors
setCodeFromCache = (cachedCodeJson) ->
  cachedCode = JSON.parse(cachedCodeJson)

  for id, editor of editors
    editor.setValue(cachedCode[id])
    # The new contect will be selected by default
    editor.selection.clearSelection() 

# Remove code in LocalStorage
clearCodeInCache = -> 
  programId = window.location.hash.slice(1)
  if !programId then throw new Error("No program ID to remove")

  localStorage.removeItem(programId)

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

  # Create all the JSON and JS editors
  for id in ["modelEditor", "assetsEditor", "actionsEditor", "layoutEditor", "servicesEditor"]
    editors[id] = setupEditor(id, "ace/mode/javascript")

  # Create the log, which is plain text
  log = setupEditor("log")
  log.setReadOnly(true)
  resetLogContent()

  # A hash needs to be set, or we won't be able to load the code
  if not window.location.hash then window.location.hash = "optics"

  # Offer to load code from the cache if we can
  loadedCode = false
  cachedCodeJson = loadCodeFromCache()
  if cachedCodeJson
    if window.confirm("You had made changes to this code. Should we load your last version?")
      setCodeFromCache(cachedCodeJson)
      loadedCode = true
    else 
      clearCodeInCache()

  # Otherwise just load from the default "optics" directory
  if not loadedCode
    for [id, url] in [["modelEditor", "optics/model.json"], 
                      ["assetsEditor", "optics/assets.json"], 
                      ["actionsEditor", "optics/actions.js"],
                      ["layoutEditor", "optics/layout.json"],
                      ["servicesEditor", "optics/services.json"]]
      loadIntoEditor(editors[id], url)

  for id in ["modelEditor", "assetsEditor", "actionsEditor", "layoutEditor", "servicesEditor"]
    editors[id].getSession().on "change", -> notifyCodeChange()

  # TODO: find another way to include global data
  globals.editors = editors

  # Setup event handlers
  $(window).on "onresize", handleResize

  # Load code
  notifyCodeChange()

