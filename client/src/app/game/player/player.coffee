angular.module('gamEvolve.game.player', [])
.run( ->
  window.addEventListener 'message', (e) -> 
      # Sandboxed iframes which lack the 'allow-same-origin' header have "null" rather than a valid origin. 
      if e.origin is "null" && e.source is $("#gamePlayer")[0].contentWindow
        console.log("master received message", e)

  sendMessage = (value) ->  
    # Note that we're sending the message to "*", rather than some specific origin. 
    # Sandboxed iframes which lack the 'allow-same-origin' header don't have an origin which you can target: you'll have to send to any origin, which might alow some esoteric attacks. 
    $('#gamePlayer')[0].contentWindow.postMessage(value, '*')

  window.sendMessage = sendMessage
)

