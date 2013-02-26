globals = @

$(document).ready ->
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

  globals.editors = editors

  loadIntoEditor = (editorId, url) ->
    $.ajax
      url: url
      dataType: "text"
      cache: false
      success: (data) -> editors[editorId].setValue(data)

  loadIntoEditor("modelEditor", "optics/model.json")
  loadIntoEditor("assetsEditor", "optics/assets.json")
  loadIntoEditor("actionsEditor", "optics/actions.js")
  loadIntoEditor("layoutEditor", "optics/layout.json")

  $("#playButton").on "click", ->
    assets = JSON.parse(editors.assetsEditor.getValue())
    modelData = JSON.parse(editors.modelEditor.getValue())
    actions = eval(editors.actionsEditor.getValue())
    layout = JSON.parse(editors.layoutEditor.getValue())
    gameController = new GE.GameController(new GE.Model(modelData), assets, actions, layout)
    gameController.loadAssets (err) ->
      if err? then throw err
      gameController.step()
      

