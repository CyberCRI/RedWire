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

spinner = new Spinner(SPINNER_OPTS)

currentModel = new GE.Model()
currentLogger = new GE.Logger()
currentFrame = 0
currentModelData = null
currentAssets = null
currentActions = null
currentLayout = null
currentConsole = null
currentLoadedAssets = null

isPlaying = false
automaticallyUpdatingModel = false

### Functions ###

initCanvas = ->
  canvas = $("#gameCanvas")
  context = canvas[0].getContext("2d")
  context.setFillColor("black")
  context.fillRect(0, 0, canvas.width(), canvas.height())

adjustEditorToSize = (editor) -> 
  session = editor.session

  editor.resize()
  if session.getUseWrapMode()
    characterWidth = editor.renderer.characterWidth
    contentWidth = editor.renderer.scroller.clientWidth

    if contentWidth > 0  
      limit = parseInt(contentWidth / characterWidth, 10)
      session.setWrapLimitRange(limit, limit)

handleResize = -> for editorName, editor of editors then adjustEditorToSize(editor)

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
      for editorId, editor of editors then editor.setReadOnly(false)
      $(this).button "option",
        label: "Play" 
        icons: 
          primary: "ui-icon-play"
    else
      isPlaying = true
      for editorId, editor of editors then editor.setReadOnly(true)
      handleAnimation()
      $(this).button "option",
        label: "Pause" 
        icons: 
          primary: "ui-icon-pause"

  $("#resetButton").on "click", ->
    currentFrame = 0
    currentModel = currentModel.atVersion(0)
    currentLogger.logWarning("reset button: on click;")
    resetConsoleContent()

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

setupEditor = (id) ->
  editor = ace.edit(id)
  editor.getSession().setMode("ace/mode/javascript")
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
    return showMessage(MessageType.Error, "<strong>Assets error.</strong> #{error}")

  try
    currentModelData = JSON.parse(editors.modelEditor.getValue())
  catch error
    return showMessage(MessageType.Error, "<strong>Model error.</strong> #{error}")

  try
    currentActions = eval(editors.actionsEditor.getValue())
  catch error
    return showMessage(MessageType.Error, "<strong>Actions error.</strong> #{error}")

  try
    currentLayout = JSON.parse(editors.layoutEditor.getValue())
  catch error
    return showMessage(MessageType.Error, "<strong>Assets error.</strong> #{error}")

  GE.loadAssets currentAssets, (err, loadedAssets) =>
    if err? 
      showMessage(MessageType.Error, "Cannot load assets")
      callback(err)

    currentLoadedAssets = loadedAssets

    # TODO: move these handlers to MVC events
    currentModel.atVersion(currentFrame).data = currentModelData

    $("#timeSlider").slider "option", 
      value: currentFrame
      max: currentFrame

    showMessage(MessageType.Info, "Game updated")
    callback(null)

# Runs the currently loaded code on the current frame
# Returns a new model
executeCode = ->
  modelAtFrame = currentModel.atVersion(currentFrame)
  [result, patches] = GE.runStep(modelAtFrame, currentLoadedAssets, currentActions, currentLayout)
  return modelAtFrame.applyPatches(patches)

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

# Reset console content
resetConsoleContent = ->
  currentLogger.logWarning("resetConsoleContent")
  editors.console.setValue("");
  editors.console.selection.clearSelection();
  editors.console.setReadOnly(true);

### Main ###

$(document).ready ->
  initCanvas()
  setupLayout()
  setupButtonHandlers()

  for id in ["modelEditor", "assetsEditor", "actionsEditor", "layoutEditor", "console"]
    editor = setupEditor(id)
    editors[id] = editor

  prefixedLog = (prefix) ->
    (text) ->
      editors.console.selection.clearSelection()
      editors.console.navigateFileEnd()
      editors.console.insert(prefix+": "+text)

  # Connect console to logging
  currentLogger = new GE.Logger(prefixedLog("err"),\
                                prefixedLog("warn"),\
                                prefixedLog("info"),\
                                prefixedLog("log"))

  resetConsoleContent()

  currentLogger.logWarning("Main: document ready, prepared console")

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
                      ["layoutEditor", "optics/layout.json"]]
      loadIntoEditor(editors[id], url)

  for id in ["modelEditor", "assetsEditor", "actionsEditor", "layoutEditor"]
    editors[id].getSession().on "change", -> notifyCodeChange()

  # TODO: find another way to include global data
  globals.editors = editors

  # Setup event handlers
  $(window).on "onresize", handleResize

  # Load code
  notifyCodeChange()

