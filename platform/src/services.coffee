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

  interpretStyle = (style, ctx) ->
    if _.isString(style) then return style
    if not _.isObject(style) then throw new Error("Style must be string or object")

    switch style.type
      when "radialGradient"
        grad = ctx.createRadialGradient(style.start.position[0], style.start.position[1], style.start.radius, style.end.position[0], style.end.position[1], style.end.radius)
        for colorStop in style.colorStops
          grad.addColorStop(colorStop.position, colorStop.color)
        return grad
      when "linearGradient"
        grad = ctx.createLinearGradient(style.startPosition[0], style.startPosition[1], style.endPosition[0], style.endPosition[1])
        for colorStop in style.colorStops
          grad.addColorStop(colorStop.position, colorStop.color)
        return grad
      else throw new Error("Unknown or missing style type")

  executeCommand = (command, ctx) ->
    # TODO: verify that arguments are of the correct type (the canvas API will not complain, just misfunction!)
    ctx.save()
    switch command.type
      when "rectangle" 
        if command.fillStyle
          ctx.fillStyle = interpretStyle(command.fillStyle, ctx)
          ctx.fillRect(command.position[0], command.position[1], command.size[0], command.size[1])
        if command.strokeStyle
          ctx.strokeStyle = interpretStyle(command.strokeStyle, ctx)
          ctx.strokeRect(command.position[0], command.position[1], command.size[0], command.size[1])
      when "image"
        ctx.drawImage(command.image, command.position[0], command.position[1])
      when "text"
        text = _.isString(command.text) && command.text || JSON.stringify(command.text)
        ctx.strokeStyle = interpretStyle(command.style, ctx)
        ctx.font = command.font
        ctx.strokeText(text, command.position[0], command.position[1])
      when "path"
        ctx.beginPath();
        ctx.moveTo(command.points[0][0], command.points[0][1])
        for point in command.points[1..] then ctx.lineTo(point[0], point[1])
        if command.fillStyle
          ctx.fillStyle = interpretStyle(command.fillStyle, ctx)
          ctx.fill()
        if command.strokeStyle
          ctx.strokeStyle = interpretStyle(command.strokeStyle, ctx)
          if command.lineWidth then ctx.lineWidth = command.lineWidth
          if command.lineCap then ctx.lineCap = command.lineCap
          if command.lineJoin then ctx.lineJoin = command.lineJoin
          if command.miterLimit then ctx.miterLimit = command.miterLimit
          ctx.stroke()
      when "circle"
        ctx.moveTo(command.position[0], command.position[1])
        ctx.arc(command.position[0], command.position[1], command.radius, 0, 2 * Math.PI)
        if command.fillStyle
          ctx.fillStyle = interpretStyle(command.fillStyle, ctx)
          ctx.fill()
        if command.strokeStyle
          ctx.strokeStyle = interpretStyle(command.strokeStyle, ctx)
          ctx.stroke()
      else throw new Error("Unknown or missing command type")
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

