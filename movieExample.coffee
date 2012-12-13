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


B.defineService "play",
  doc: "Plays an MP3"
  parameterDefs:
    loop: B.Bool(false)
    volume: B.Float({range: [0, 1]})
    pan: B.Float({range: [-1, 1]})
    sounds: B.Queue(B.String())
    assetMap: B.Object()
  updateFilter: ["model"]
  update: (params) ->
    for sound in sounds:
      a = new Audio(params.assetMap.value[sound])
      # TODO: look into how the asset storing might work in HTML5 for sounds, audio, etc.
      # also look into local storage
      a.play()
    sounds.empty() 
  # or ...
  soundsIn: (sound, params) ->
    a = Audio(params.assetMap.value[sound])
    a.play()


B.defineTestCase "The sequence action activates the right case"





