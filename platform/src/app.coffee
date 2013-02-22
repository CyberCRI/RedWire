Ext.application
  name: 'gamEvolve'
  launch: ->
    Ext.create 'Ext.container.Viewport', 
      layout: 'border'
      items: [
        {
          region: 'north'
          xtype: 'toolbar'
          border: false
          items: [
            {
              xtype: 'header'
              title: "gamEvolve"
              border: false
              cls: "appTitle"
            }
            '->'
            {
              text: "Save"
              icon: "images/cloud_upload_16x16.png"
            }
            {
              text: "Login to GitHub"
            }
            {
              text: "Share"
              icon: "images/link_16x16.png"
            }
          ]
        }
        {
          html: 'Left hand panel'
          region: "west"
          width: 300
          split: true
          collapsible: true
          layout: 
            type: 'accordion'
            multi: true
          items: [
            {
              title: "Time"
              layout: 'border'
              maxHeight: 60
              bodyPadding: 5
              items: [
                {
                  region: 'west'
                  xtype: 'button'
                  icon: "images/play_12x16.png"
                  id: "playButton"
                  tooltip: "Play/pause"
                }
                {
                  region: 'center'
                  xtype: 'slider'
                  margin: "0 10 0 10"
                }
                {
                  region: 'east'
                  xtype: 'button'
                  icon: "images/reload_12x14.png"
                  tooltip: "Reset"
                }
              ]
            }
            {
              title: "Model"
              html: '<div id="modelEditor" class="editor"></div>'
            }
            {
              title: "Assets"
              html: '<div id="assetsEditor" class="editor"></div>'
            }
          ]
        }
        {
          title: 'Game'
          html : '<canvas id="gameCanvas" width="960" height="540"></canvas>'
          region: 'center'
        }
        {
          region: "south"
          height: 200
          split: true
          collapsible: true
          layout: 'border'
          items: [
            {
              title: "Actions"
              html: '<div id="actionsEditor" class="editor">actions</div>'
              region: "west"
              width: 400
              collapsible: true
              split: true
            }
            {
              title: "Layout"
              region: 'center'
              html: '<div id="layoutEditor" class="editor">layout</div>'
            }
          ]
        }
      ]
    
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

    for id in ["modelEditor", "assetsEditor", "actionsEditor", "layoutEditor"]
      editor = ace.edit(id)
      editor.getSession().setMode("ace/mode/javascript")
      editor.getSession().setUseWrapMode(true)
      editor.setWrapBehavioursEnabled(true)
      editors[id] = editor

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
      

