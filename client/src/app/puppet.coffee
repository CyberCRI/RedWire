window.addEventListener 'message', (e) ->
  if e.origin == "null" then return

  console.log("puppet received message", e)
  e.source.postMessage("your message was #{e}", e.origin)

