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



