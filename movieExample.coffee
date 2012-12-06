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

  action: (params) ->
    init: -> $(params.location).html(params.html.get())
    destroy: -> $(params.location).html("")
    update: ->


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

  action: (params, children, temp) ->
    init: -> 
      jade = require("jade")
      @compiledTemplate = jade.compile(params.template.value)
    destroy: ->
    update: -> 
      # in case params don't change, do nothing
      if not params.locals.value.hasChanged then return 

      params.output.value = temp.compiledTemplate(params.locals.value)


B.defineAction "watch",
  doc: "Activate a branch based on a condition"
  parameterDefs:
    condition: 
      type: B.Any
  start: (namedChildren) -> 
    # stop all children at start
    for name, child of namedChildren then child.state = B.ActionState.STOPPED
  update: (params, namedChildren) -> 
    if not params.condition.hasChanged then return 

    # TODO: assert only one action is running

    # TODO: suspend rather than stop running child? 
    namedChildren[params.condition.oldValue].state = B.ActionState.STOPPED

    if params.condition.value of namedChildren
      namedChildren[params.condition.value] = B.ActionState.RUNNING
    else if B.Signals.OTHERWISE of namedChildren
      namedChildren[params.condition.value] = B.ActionState.RUNNING
    else
      throw new B.Abort("value of condition '#{params.condition.value}' not found")



    # TODO: assert only one action is running

B.defineAction "sequence",
  doc: "Do one action after the other"
  parameterDefs:
    loop: B.Bool(false)
    runningChild: B.Int(0)
  action: 
    update: (context) -> 
      if context.children.list[context.params.runningChild.value].signal == B.Signal.DONE
        # No need to stop done child
        context.params.runningChild.value = (context.params.runningChild.value + 1) % context.children.list.length 
        context.children.list[context.params.runningChild.value].state = B.ActionState.RUNNING



# TODO: do "define" action




