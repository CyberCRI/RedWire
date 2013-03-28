# Define keyboard input service
registerService "Keyboard", (options) ->
  options = _.defaults options,
    elementSelector: "#gameCanvas"

  keysDown = {}

  # Use the KeyboardService event namespace
  $(options.elementSelector).on "keydown.GE.KeyboardService keyup.GE.KeyboardService", (event) ->
    # jQuery standardizes the keycode into http://api.jquery.com/event.which/
    if event.type == "keydown"
      keysDown[event.which] = true
    else
      delete keysDown[event.which]

  return {
    provideData: -> return { "keysDown": keysDown }

    establishData: -> # NOOP. Input service does not take data

    # Remove all events
    destroy: -> $(options.elementSelector).off(".GE.KeyboardService")
  }

# Define mouse input service
registerService "Mouse", (options) ->
  options = _.defaults options,
    elementSelector: "#gameCanvas"

  mouse =
    down: false
    position: null

  # Use the KeyboardService event namespace
  $(options.elementSelector).on "mousedown.GE.MouseService mouseup.GE.MouseService mouseup.GE.MouseService mousemove.GE.MouseService mouseleave.GE.MouseService", (event) ->
    # jQuery standardizes the keycode into http://api.jquery.com/event.which/
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

  return {
    provideData: -> return mouse

    establishData: -> # NOOP. Input service does not take data

    # Remove all events
    destroy: -> $(options.elementSelector).off(".GE.MouseService")
  }



