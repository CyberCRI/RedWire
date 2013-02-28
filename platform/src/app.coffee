globals = @

CODE_CHANGE_TIMEOUT = 1000

$(document).ready ->
  MessageType = GE.makeConstantSet("Error", "Info")

  canvas = $("#gameCanvas")
  context = canvas[0].getContext("2d")
  context.setFillColor("black")
  context.fillRect(0, 0, canvas.width(), canvas.height())

  editors = {}
  onResize = -> 
    for editorName, editor of editors
      session = editor.session

      editor.resize()
      if session.getUseWrapMode()
          characterWidth = editor.renderer.characterWidth
          contentWidth = editor.renderer.scroller.clientWidth

          if contentWidth > 0  
            limit = parseInt(contentWidth / characterWidth, 10)
            session.setWrapLimitRange(limit, limit)
  window.onresize = onResize

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

  # top
  $("#saveButton").button({ icons: { primary: "ui-icon-transferthick-e-w" }})
  $("#shareButton").button({ icons: { primary: "ui-icon-link" }})

  # west
  $("#playButton").button({ icons: { primary: "ui-icon-play" }, text: false })
  $("#timeSlider").slider
    orientation: "horizontal"
    range: "min"
    min: 0
    max: 10
    step: 1
    value: 0
  $("#resetButton").button({ icons: { primary: "ui-icon-arrowreturnthick-1-w" }, text: false })

  # Based on http://layout.jquery-dev.net/demos/accordion.html

  $("#west").tabs()
  $("#south").tabs().addClass( "ui-tabs-vertical ui-helper-clearfix" )
  $("#south li").removeClass( "ui-corner-top" ).addClass( "ui-corner-left" )
  $("#south li a").click(onResize)

  # TODO: look for a callback for tabs
  $('body').layout 
    north__resizable: false
    north__closable: false
    north__size: 50
    west__size: 300
    applyDefaultStyles: true
    onresize:  onResize

  for id in ["modelEditor", "assetsEditor", "actionsEditor", "layoutEditor"]
    editor = ace.edit(id)
    editor.getSession().setMode("ace/mode/javascript")
    editor.getSession().setUseWrapMode(true)
    editor.setWrapBehavioursEnabled(true)
    editors[id] = editor

    editor.getSession().on "change", -> notifyCodeChange()

  # TODO: find another way to include global data
  globals.editors = editors

  loadIntoEditor = (editorId, url) ->
    $.ajax
      url: url
      dataType: "text"
      cache: false
      success: (data) -> 
        editors[editorId].setValue(data)
        # The new contect will be selected by default
        editors[editorId].selection.clearSelection() 

  loadIntoEditor("modelEditor", "optics/model.json")
  loadIntoEditor("assetsEditor", "optics/assets.json")
  loadIntoEditor("actionsEditor", "optics/actions.js")
  loadIntoEditor("layoutEditor", "optics/layout.json")

  runStep = ->
    try
      assets = JSON.parse(editors.assetsEditor.getValue())
    catch error
      return showMessage(MessageType.Error, "<strong>Assets error.</strong> #{error}")

    try
      modelData = JSON.parse(editors.modelEditor.getValue())
    catch error
      return showMessage(MessageType.Error, "<strong>Model error.</strong> #{error}")

    try
      actions = eval(editors.actionsEditor.getValue())
    catch error
      return showMessage(MessageType.Error, "<strong>Actions error.</strong> #{error}")

    try
      layout = JSON.parse(editors.layoutEditor.getValue())
    catch error
      return showMessage(MessageType.Error, "<strong>Assets error.</strong> #{error}")

    showMessage(MessageType.Info, "Game updated")

    gameController = new GE.GameController(new GE.Model(modelData), assets, actions, layout)
    gameController.loadAssets (err) ->
      if err? then throw err
      gameController.step()

  lastCodeChangeTimeoutId = null
  notifyCodeChange = ->
    timeoutCallback = ->
      spinner.stop()
      runStep()

    spinner.spin($("#north")[0]) 
    clearMessage()

    # cancel previous timeout
    if lastCodeChangeTimeoutId 
      window.clearTimeout(lastCodeChangeTimeoutId)
      lastCodeChangeTimeoutId = null

    # TODO: catch exceptions here?
    window.setTimeout(timeoutCallback, CODE_CHANGE_TIMEOUT)

  $(window).on 'beforeunload', -> 'If you leave the page, you will lose unsaved changes'

  # TODO: 
  # use requestAnimationFrame
  # wait a bit before updating code (to avoid multiple changes)
  # in play mode, advance when timer calls
  # update slider when number of models changes
  # every time code changes, recompile it and run step (listen to events)
  # lock code down in play mode so it can't be changed

  $("#playButton").on "click", ->
    if $(this).text() == "Play"
      $(this).button "option",
        label: "Pause" 
        icons: 
          primary: "ui-icon-pause"
    else
      $(this).button "option",
        label: "Play" 
        icons: 
          primary: "ui-icon-play"

  spinnerOpts = 
    lines: 9,
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
  spinner = new Spinner(spinnerOpts)

  notifyCodeChange()

