angular.module('gamEvolve.game.player', [])
.controller "PlayerCtrl", ($scope, games, currentGame, gameTime) -> 
  # Bring services into the scope
  $scope.currentGame = currentGame
  $scope.gameTime = gameTime

  # TODO: take out this "global" message handler?
  window.addEventListener 'message', (e) -> 
    # Sandboxed iframes which lack the 'allow-same-origin' header have "null" rather than a valid origin. 
    if e.origin is "null" && e.source is $("#gamePlayer")[0].contentWindow
      switch e.data.type
        when "error"
          console.log("Puppet reported error", e.data.error)
        when "success" 
          console.log("Puppet reported success", e.data.value)
        else
          throw new Error("Unknown message from puppet", e.data)

  sendMessage = (operation, value) ->  
    # Note that we're sending the message to "*", rather than some specific origin. 
    # Sandboxed iframes which lack the 'allow-same-origin' header don't have an origin which you can target: you'll have to send to any origin, which might alow some esoteric attacks. 
    $('#gamePlayer')[0].contentWindow.postMessage({operation: operation, value: value}, '*')

  # TODO: remove this
  window.sendMessage = sendMessage

  gameCode = null
  $scope.$watch 'currentGame.version', (code) ->
    gameCode = code
    console.log("Game code changed to", gameCode)
    sendMessage("loadGameCode", gameCode)

  onUpdateFrame = (frame) ->
    if not gameCode? then return
    console.log("Changed frame to", frame)
    sendMessage("stepLoop", { model: gameCode.model })

  onResize = -> 
    screenElement = $('#gamePlayer')
    scale = Math.min(screenElement.parent().outerWidth() / GAME_DIMENSIONS[0], screenElement.parent().outerHeight() / GAME_DIMENSIONS[1])
    roundedScale = scale.toFixed(2)
    newSize = [
      roundedScale * GAME_DIMENSIONS[0]
      roundedScale * GAME_DIMENSIONS[1]
    ]
    remainingSpace = [
      screenElement.parent().outerWidth() - newSize[0]
      screenElement.parent().outerHeight() - newSize[1]
    ]
    screenElement.css 
      "width": "#{newSize[0]}px"
      "height": "#{newSize[1]}px"
      "left": "#{remainingSpace[0] / 2}px"
      "top": "#{remainingSpace[1] / 2}px"
    sendMessage("changeScale", roundedScale)

  $scope.$watch('gameTime.currentFrame', onUpdateFrame, true)

  window.updateResize = onResize

  # TODO: need some kind of notification from flexy-layout when a block changes size!
  # Until then automatically resize once in a while.
  setInterval(onResize, 1000)
