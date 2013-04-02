# Define keyboard input service
registerService "Keyboard", (options) ->
  options = _.defaults options,
    elementSelector: "#gameCanvas"

  eventNamespace = _.uniqueId("keyboard")

  keysDown = {}

  $(options.elementSelector).on "keydown.#{eventNamespace} keyup.#{eventNamespace} blur.#{eventNamespace}", (event) ->
    # jQuery standardizes the keycode into http://api.jquery.com/event.which/
    switch event.type 
      when "keydown" then keysDown[event.which] = true
      when "keyup" then delete keysDown[event.which]
      when "blur" then keysDown = {} # Lost focus, so will not receive keyup events
      else throw new Error("Unexpected event type")      

  return {
    provideData: -> return { "keysDown": keysDown }

    establishData: -> # NOOP. Input service does not take data

    # Remove all event handlers
    destroy: -> $(options.elementSelector).off(".#{eventNamespace}")
  }

# Define mouse input service
registerService "Mouse", (options) ->
  options = _.defaults options,
    elementSelector: "#gameCanvas"

  eventNamespace = _.uniqueId("mouse")

  mouse =
    down: false
    position: null

  $(options.elementSelector).on "mousedown.#{eventNamespace} mouseup.#{eventNamespace} mousemove.#{eventNamespace} mouseleave.#{eventNamespace}", (event) ->
    switch event.type 
      when "mousedown" then mouse.down = true
      when "mouseup" then mouse.down = false
      when "mouseleave" 
        mouse.down = false
        mouse.position = null
      when "mousemove"
        # Get position relative to canvas.
        # Based on http://www.html5canvastutorials.com/advanced/html5-canvas-mouse-coordinates/
        rect = $(options.elementSelector)[0].getBoundingClientRect()
        mouse.position = 
          x: event.clientX - rect.left
          y: event.clientY - rect.top
      else throw new Error("Unexpected event type")

  return {
    provideData: -> return mouse

    establishData: -> # NOOP. Input service does not take data

    # Remove all event handlers
    destroy: -> $(options.elementSelector).off(".#{eventNamespace}")
  }

# Define canvas output service
registerService "Canvas", (options) ->
  options = _.defaults options,
    elementSelector: "#gameCanvas"
    layers: 
      default: 
        order: 0

  # Default 
  layerOrderForCommand = (command) ->
    if not command.layer? then return 0
    if command.layer not of options.layers then return 0
    return options.layers[command.layer].order or 0 

  commandSorter = (a, b) -> return layerOrderForCommand(a) - layerOrderForCommand(b)

  executeCommand = (command, ctx) ->
    ctx.save()
    switch command.type
      when "rectangle" 
        if command.fillStyle
          ctx.fillStyle = command.fillStyle
          ctx.fillRect(command.position[0], command.position[1], command.size[0], command.size[1])
        if command.strokeStyle
          ctx.strokeStyle = command.strokeStyle
          ctx.strokeRect(command.position[0], command.position[1], command.size[0], command.size[1])
      when "image"
        ctx.drawImage(command.image, command.position[0], command.position[1])
      when "text"
        text = _.isString(command.text) && command.text || JSON.stringify(command.text)
        ctx.strokeStyle = command.style
        ctx.font = command.font
        ctx.strokeText(text, command.position[0], command.position[1])
      else throw new Error("Unknown or missing command type")
      # TODO: paths       
    ctx.restore()

  return {
    provideData: -> 
      canvas = $(options.elementSelector)
      return {
        width: canvas.prop("width")
        height: canvas.prop("height")
        commands: []
      }

    establishData: (data) -> 
      if not data.commands then return 

      ctx = $(options.elementSelector)[0].getContext("2d")
      data.commands.sort(commandSorter)
      for command in data.commands
        # TODO: handle composition for layers
        executeCommand(command, ctx)

    destroy: -> # NOOP
  }

