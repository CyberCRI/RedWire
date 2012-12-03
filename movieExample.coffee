# Movie example
# Written in Coffeescript

# these "declare*" functions can be called more than once, both to augment and modify current behavior

# Q: How to "package" things like the loading screen together?

B.setRootAction
  doInSequence : [
    "init page": ui.html.show 
      location: "body"
      html: B.asset("baseTemplate") 

    # Q: did our "define" lose the doInSequence action above?
    define location: "main", [
      "format loading screen": ui.html.jade 
        template: B.asset("loadingScreen")
        output: B.model("loadingScreen")
        locals: 
          loadingPercent: B.model("status.loading")

      "show loading screen": ui.html.show { html: B.model("loadingScreen") } 
      "load assets": B.loadAssets
        toLoad: "ALL"
        loadingPercent: B.model("status.loading")

      "show game": B.if 
        condition: B.model("status.paused") # or could be a function
        then: 
          "show pause screen": ui.html.show
            html: B.asset("pauseScreen") 
        else: 
          doInSequence { loop: true }, [
            "show intro": ui.html.show 
              location: "main"
              html: B.asset("introScreen")
            "show scene a": ui.html.show B.asset("introScreen")
            "show scene b": ui.html.show B.asset("introScreen")
            "show credits": ui.html.show B.asset("creditsScreen")
          ]
      ]
  ]


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


B.defineAction "ui.html.jade", 
  doc: "Compiles a template using the Jade template engine"
  parameterDefs:
    template: 
      type: B.String
      constant: true
    output: B.String # shorthand syntax
    locals: B.Object({}) # shorthand syntax

  action: (temp, params) ->
    init: -> 
      jade = require("jade")
      temp.compiledTemplate = jade.compile(params.template.value)
    destroy: ->
    update: -> 
      # in case params don't change, do nothing
      if not params.locals.value.hasChanged then return 

      params.output.value = temp.compiledTemplate(params.locals.value)

