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
    children:
      named: {}
        state = ["running", "suspended", "stopped"]
        signal = *
      list: []
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
  start: (namedChildren) -> 
    # stop all children at start
    for name, child of namedChildren then child.state = B.ActionState.STOPPED
  onModelChange: (params, namedChildren) -> 
    # TODO: suspend rather than stop running child? 
    namedChildren[params.condition.oldValue].state = B.ActionState.STOPPED

    if params.condition.value of namedChildren
      namedChildren[params.condition.value].state = B.ActionState.RUNNING
      return "Activated named child"
    else if B.Signals.OTHERWISE of namedChildren
      namedChildren[params.condition.value].state = B.ActionState.RUNNING
      return "Activated the OTHERWISE case"
    else 
      return "value of condition '#{params.condition.value}' not found"
  contract: 
    "only one action is running": (namedChildren) -> 
      count = 0
      for name, child of namedChildren 
        if child.name.state == B.ActionState.RUNNING then count++
      return count <= 1
  unitTests:
    "the right action is activated":
      input:
        params:
          condition: "yes"
        namedChildren: 
          "yes": 
            state: B.ActionState.STOPPED
          "no": 
            state: B.ActionState.STOPPED
      output:
        namedChildren:
          "yes": 
            state: B.ActionState.RUNNING
          "no": 
            state: B.ActionState.STOPPED
    "the otherwise action is activated":
      input:
        params:
          condition: "maybe"
        namedChildren: 
          "yes": 
            state: B.ActionState.STOPPED
          "no": 
            state: B.ActionState.STOPPED
          "B.Signals.OTHERWISE": 
            state: B.ActionState.STOPPED
      output:
        namedChildren:
          "yes": 
            state: B.ActionState.STOPPED
          "no": 
            state: B.ActionState.STOPPED
          "B.Signals.OTHERWISE": 
            state: B.ActionState.RUNNING


B.defineAction "sequence",
  doc: "Do one action after the other"
  parameterDefs:
    loop: B.Bool(false)
    runningChild: B.Int(0)
  update: (context) -> 
    if context.children.list[context.params.runningChild.value].signal == B.Signal.DONE
      # No need to stop done child
      context.params.runningChild.value = (context.params.runningChild.value + 1) % context.children.list.length 
      context.children.list[context.params.runningChild.value].state = B.ActionState.RUNNING


B.defineTestCase "The sequence action activates the right case"





