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

  onModelChange: (params) -> $(params.location).html(params.html.get())


###
  context =
    params:
      param1:
        value
        hasChanged
        oldValue (if hasChanged)
      ...
    childActivation: {}
    temp: {}
###


B.defineAction "ui.html.jade", 
  doc: "Compiles a template using the Jade template engine"
  parameterDefs:
    template: 
      type: B.String
      constant: true
    output: B.String # shorthand syntax
    locals: B.Object({}) # shorthand syntax
  start: (temp) -> 
    jade = require("jade")
    temp.compiledTemplate = jade.compile(params.template.value)
  onModelChange: (params) -> 
    params.output.value = temp.compiledTemplate(params.locals.value)
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
  start: (childActivation) -> 
    # stop all children at start
    for name of childActivation then childActivation[name] = false
  onModelChange: (params, childActivation) -> 
    childActivation[params.condition.oldValue] = false

    if params.condition.value of childActivation
      childActivation[params.condition.value] = true
      return B.logInfo "Activated named child"
    else if "otherwise" of childActivation
      childActivation[params.condition.value].state = B.ActionState.RUNNING
      return B.logInfo "Activated the OTHERWISE case"
    else 
      return B.logWarning "value of condition '#{params.condition.value}' not found"
  contract: 
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
  start: (childActivation) -> 
    # stop all children at start
    for name of childActivation then childActivation[name] = false
  onChildActivationChange: (params, childActivation) -> 
    keys = params.runningChild.value.keys[0]
    if params.runningChild.value == null
      params.runningChild.value = keys[0]
    else
      index = keys.indexOf(params.runningChild.value) + 1
      if params.loop.value
        index = index % keys.length
      else
        if index >= keys.length then return B.Action.DONE
      params.runningChild.value = keys[index]

    childActivation[params.runningChild.value].state = true


B.declareDataType "audio.PlayCommand",
  volume: B.Float({range: [0, 1], default: 1})
  pan: B.Float({range: [-1, 1], default: 0})
  assetPath: B.String()


B.defineAction "audio.playSound",
  doc: "Plays an MP3 clip once"
  parameterDefs:
    sounds: B.Queue(audio.PlayCommand)
  updateFilter: ["model"]
  services: ["audio.sound"]
  update: (params, services) ->
    for sound in sounds.value:
      services["audio.sound"].play(sound.assetPath)
    sounds.empty() 


B.defineAction "audio.playMusic",
  doc: "Plays a single music track"
  parameterDefs:
    music: B.String()
    fadeTime: 
      doc: "in milliseconds"
      type: B.Int(1000)
    fading: B.Enum(["in", "out", "none"])("none") # or could be done by a "delareEnum" globally
    startFadeTime: B.Int()
    gameTime: B.Int()
  services: ["audio.sound"]
  start: (locals) -> 
    locals.currentClip = null
    locals.fading = "none"
  update: (params, services, assets, local) ->
    if params.music.hasChanged then params.fading = "out"

    if locals.fading == "in":
      volume = (params.gameTime.value - params.lastFadeTime.value) / params.fadeTime.value


    if locals.currentClip:
      # fade out

      services["audio.sound"].stop
      stop current music
      when DONE
      play new music

    for sound in sounds.value:
      services["audio.sound"].play(sound.assetPath)
    sounds.empty() 


B.defineService "audio.sound",
  doc: "Plays an MP3 via HTML5"
  service:
    start: ->
      @sounds = {}
    end: ->
      @sounds = {}
    factory: (action) -> 
      play: (assetPath) ->
        sound = assetMap[assetPath]
        runningSounds[assetPath] = sound
        sound.play()
      stop: (assetPath, callback) ->
        if not assetPath of runningSounds then callback("No sound detected")

        runningSounds[assetPath].pause()
        callback(null)
    gui: -> # TODO: make GUI component for sounds


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




B.defineService "jquery",
  doc: "Does everything"
  # RequireJS form
  service ["jquery"], ($) -> 
    factory: (action) -> $



B.defineTestCase "The sequence action activates the right case"





