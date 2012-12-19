# Movie example
# Written in Coffeescript

# these "declare*" functions can be called more than once, both to augment and modify current behavior

# Q: How to "package" things like the loading screen together?

B.setRootAction "movieActions.booyah"

B.declareModels
  status: new B.Object
    loading: new B.Number(0)
    paused: new B.Bool(false)
  html:
    loadingScreen: new B.String

B.declareConfig
  assetMap:
    introScreen "in"

B.declareAssets
  baseTemplate: 
    type: B.String
    url: "template.html"
  loadingScreen: "loading.html" # type auto-detection
  pauseScreen: "pause.html"
  introScreen: "intro.html"
  sceneA: "sceneA.html"
  sceneB: "sceneB.html"
  creditsScreen: "credits.html"


# allows action to be changed later
B.defineAction "ui.html.show", 
  doc: "Shows HTML in the given location"
  parameterDefs:
    html: 
      type: B.String
      required: true # or the fact there is no default value implies required (but this means the default value for each type is not used)
    location: 
      type: B.String 
      default: "body"
      constant: true # means that changes to this parameter changes will be ignored
  updateFilter: ["model"]
  requires: ["jquery"]
  update: (params) -> $(params.location).html(params.html)


B.defineAction "ui.html.jade", 
  doc: "Compiles a template using the Jade template engine"
  parameterDefs:
    template: 
      type: B.String
      constant: true
    output: B.String # shorthand syntax
    dict: B.Object({}) # shorthand syntax
  requires: ["jade"]
  start: (params) -> 
    locals.compiledTemplate = jade.compile(params.template)
  updateFilter: ["model"]
  update: (params) -> 
    params.output = temp.compiledTemplate(params.locals)
  unitTests: 
    "constant template": 
        inputParams:
          template: "h1 Hello"
        outputParams:
          output: "<h1>Hello</h1>"
    "locals in template": 
        inputParams:
          template: "h1= Hello \#{name}"
          locals:
            name: "Jesse"
        outputParams:
          output: "<h1>Hello Jesse</h1>"



B.defineAction "watch",
  doc: "Activate a branch based on a condition"
  parameterDefs:
    condition: 
      type: B.Any
  start: () -> 
    # stop all children at start
    for name of childActivation then childActivation[name] = false
  updateFilter: ["model"]
  update: (params) -> 
    childActivation[oldValue("condition")] = false

    if params.condition of childActivation
      childActivation[params.condition] = true
      return B.logInfo "Activated named child"
    else if "otherwise" of childActivation
      childActivation[params.condition].state = B.ActionState.RUNNING
      return B.logInfo "Activated the OTHERWISE case"
    else 
      return B.logWarning "value of condition '#{params.condition}' not found"
  invariant: 
    "only one action is running": (childActivation) -> 
      count = 0
      for name, child of childActivation 
        if child.name.state == B.ActionState.RUNNING then count++
      return count <= 1
  unitTests:
    "the right action is activated":
      input:
        params:
          condition: "yes"
        childActivation: 
          "yes": false
          "no": false
      output:
        childActivation: 
          "yes": true
          "no": false
    "the otherwise action is activated":
      input:
        params:
          condition: "maybe"
        childActivation: 
          "yes": false
          "no": false
          "otherwise": false
      output:
        childActivation:
          "yes": false
          "no": false
          "otherwise": true


B.defineAction "sequence",
  doc: "Do one action after the other"
  parameterDefs:
    loop: B.Bool(false)
    runningChild: B.String()
  start: () -> 
    # stop all children at start
    for name of childActivation then childActivation[name] = false
  updateFilter: ["childActivation"]
  update: (params) -> 
    keys = params.runningChild.keys[0]
    if params.runningChild == null
      params.runningChild = keys[0]
    else
      index = keys.indexOf(params.runningChild) + 1
      if params.loop
        index = index % keys.length
      else
        if index >= keys.length then return B.Action.DONE
      params.runningChild = keys[index]

    childActivation[params.runningChild].state = true


B.defineAction "audio.playMusic",
  doc: "Plays a single music track"
  parameterDefs:
    music: B.String()
    fadeTime: 
      doc: "in milliseconds"
      type: B.Int(1000)
    fading: B.Enum(["in", "out", "none"])("none") # or could be done by a "delareEnum" globally
    startFadeTime: B.Int({ allowNull: true })
  start: -> 
    locals.audio = null
    locals.fading = "none"
  stop: (params) -> 
    if locals.audio 
      params.fading = "none"
      locals.audio.pause()
  update: (params) ->
    if hasChanged("music") 
      if oldValue("music") then params.fading = "out"
      else then params.fading = "in"
      params.startFadeTime = gameTime() # or just gameTime as attribute

    if params.fading == "out"
      interpolate = (gameTime() - params.startFadeTime) / params.fadeTime
      if interpolate >= 1 
        params.fading = "in"
        params.startFadeTime = gameTime()
        locals.audio = null
      else
        locals.audio.volume = interpolate

    if params.fading == "in"
      if not locals.audio 
        locals.audio = assets.get(params.music) # or new Audio(params.music)
        locals.audio.addEventListener("ended", signalEvent("ended"))
        locals.audio.play()

      interpolate = (gameTime() - params.startFadeTime) / params.fadeTime
      if interpolate >= 1
        params.fading = "none"
        startFadeTime = null
      else
        locals.audio.volume = 1 - interpolate

    if locals.events:
      assert("is ended", locals.events[0] == "ended")
      locals.audio.play()


B.defineAction "audio.playSound",
  doc: "Plays an MP3 clip once"
  parameterDefs:
    sounds: B.Queue(B.String())
  updateFilter: ["model"]
  update: (params) ->
    for sound in params.sounds:
      assets.get(sound).play()
      # or new Audio(sound).play()
    sounds.empty() 


B.defineAction "html.handleButton",
  doc: "" # TODO
  ports:
    selector: B.String()
    status: B.Enum(["disabled", "enabled", "pressed", "hover"])
  requires: [{ "jquery" : "$" }]
  start: ->
  stop: ->
    if oldValue("selector") 
      $(oldValue("selector")).off("click mouseover mouseout", handler("onMouseEvent"))
  update: (values) ->
    if hasChanged("selector")
      $(oldValue("selector")).on("click mouseover mouseout", handler("onMouseEvent"))

    if hasChanged("status")
      switch values.status
        when "disabled" then $(values.selector)).attr("disabled", "disabled")
        when "enabled" then $(values.selector)).removeAttr("disabled")
    
    if locals.status
      values.status = locals.status
      delete locals.status
  handlers:
    onMouseEvent: (event) ->
      switch event.type
        when "click" then locals.status = "pressed"
        when "mouseover" then locals.status = "hover"
        when "mouseout" then locals.status = "enabled"


B.defineService "canvas",
  doc: "Detects all changes made to canvases"
  requires: ["jquery"]
  start: -> 
  stop: ->
  beforeLoop: ->
    locals.actionToPixels = {}
    locals.pixelToActions = {}
  afterLoop: ->
  beforeAction: (action) -> 
    for canvas in $("canvas")
      # store canvas
      locals.imageData[canvas.id] = canvas.getImageData(canvas.width, canvas.height)
  afterAction: (action) ->
    for canvas in $("canvas")
      oldImage = locals.imageData[canvas.id] 
      if locals.mode == "restore"
        canvas.setImageData(oldImage)
      else if locals.mode == "compare"
        # compare canvas
        newImage = canvas.getImageData(canvas.width, canvas.height)
        for i in [0..oldImage.data.length]
          if oldImage.data[i] != newImage.data[i]
            locals.actionToPixels[action.id].push(i)
            locals.pixelToActions[i].push(action.id)
  drawGui: -> # TODO


B.defineService "audio",
  doc: "Detects all changes made to JS audio objects"
  start: -> 
  stop: ->
  assetCreated: (audio) ->
    locals.audioClips[audio.id] = 
      status: "loaded"
      progress: 0
      duration: 0
      actions: {}
    audio.addEventListener("ended", (event) -> locals.audioClips[audio.id].status = "ended")
    audio.addEventListener "playing", (event) -> 
      if locals.mode == "restore"
        audio.play()
      else if locals.mode == "compare"
        locals.audioClips[audio.id].status = "playing"
        locals.audioClips[audio.id].actions[audio.id] =
          change: "played"
        locals.actionToAudios[locals.currentAction].push audio.id
    audio.addEventListener "paused", (event) -> 
      locals.audioClips[audio.id].status = "paused"
      locals.audioClips[audio.id].actions[audio.id] =
        change: "paused"
        locals.actionToAudios[locals.currentAction].push audio.id
    # ... for progress as well
  beforeLoop: ->
    locals.audioClips = {}
    locals.audioToActions = {}
  afterLoop: ->
  beforeAction: (action) -> locals.currentAction = action
  afterAction: (action) ->
  drawGui: -> # TODO


B.defineAction "net.twitter.followers",
  doc: "Fetches a list of twitter followers"
  parameterDefs:
    username: B.String()
    followers: B.Array(B.String())
  requires: ["jquery"]
  start: (params) -> 
  stop: (params) -> 
  updateFilter = ["change:username", "handler"]
  update: (params) ->
    if hasChanged("username") and params.username != ""
      # TODO: cancel current request if username changes in the meantime
      $.ajax("http://twitter.com/...").done handler("response")

    if locals.data
      params.followers = data
      delete locals.data
  handlers:
    response: (data) -> locals.usernames = data



