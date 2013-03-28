# Define keyboard input service

makeKeyboardService = (options) ->
  options = _.defaults options,
    elementSelector: "#gameCanvas"

  keysDown = {}

  # Use the KeyboardService event namespace
  $(options.elementSelector).on "keydown.GE.KeyboardService keyup.GE.KeyboardService", (event) ->
    # jQuery standardizes the keycode into http://api.jquery.com/event.which/
    if event.type == "keydown"
      keysDown[event.which] = true
    else
      keysDown[event.which]

  return {
    provideData: -> return { "keysDown": keysDown }

    establishData: -> # NOOP. Input service does not take data

    # Remove all events
    destroy: -> $(options.elementSelector).off(".GE.KeyboardService")
  }

registerService("Keyboard", makeKeyboardService)

