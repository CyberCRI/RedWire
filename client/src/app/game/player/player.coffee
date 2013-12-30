angular.module('gamEvolve.game.player', [])
.controller "PlayerCtrl", ($scope, games, currentGame, gameHistory) -> 
  # Bring services into the scope
  $scope.currentGame = currentGame
  $scope.gameHistory = gameHistory

  # TODO: take out this "global" message handler?
  window.addEventListener 'message', (e) -> 
    # Sandboxed iframes which lack the 'allow-same-origin' header have "null" rather than a valid origin. 
    if e.origin isnt "null" or e.source isnt $("#gamePlayer")[0].contentWindow then return

    if e.data.type is "error"
      return console.error("Puppet reported error", e.data.error)

    console.log("Puppet reported success", e.data)

    switch e.data.operation
      when "stepLoop" 
        # If we are on the last frame...
        if gameHistory.currentFrameNumber is gameHistory.frames.length - 1
          # ... add a new frame to the list
          { modelPatches: modelPatches, servicePatches: servicePatches } = e.data.value
          model = GE.applyPatches(gameHistory.frames[gameHistory.frames.length - 1], modelPatches)
          $scope.$apply ->
            $scope.gameHistory.frames.push({ model: model })

  sendMessage = (operation, value) ->  
    # Note that we're sending the message to "*", rather than some specific origin. 
    # Sandboxed iframes which lack the 'allow-same-origin' header don't have an origin which you can target: you'll have to send to any origin, which might alow some esoteric attacks. 
    $('#gamePlayer')[0].contentWindow.postMessage({operation: operation, value: value}, '*')

  gameCode = null
  $scope.$watch 'currentGame.version', (code) ->
    if not code? then return

    gameCode = code
    console.log("Game code changed to", gameCode)
    $scope.gameHistory.frames = [model: code.model]
    sendMessage("loadGameCode", gameCode)

  oldRoundedScale = null
  onResize = -> 
    screenElement = $('#gamePlayer')
    scale = Math.min(screenElement.parent().outerWidth() / GAME_DIMENSIONS[0], screenElement.parent().outerHeight() / GAME_DIMENSIONS[1])
    roundedScale = scale.toFixed(2)
    # Avoid rescaling if not needed
    if oldRoundedScale is roundedScale then return 

    oldRoundedScale = roundedScale
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

  # onUpdateFrame = (frameNumber) ->
  #   if not gameCode? then return
  #   console.log("Changed frame to", frameNumber)
  #   sendMessage("stepLoop", { model: gameHistory.frames[frameNumber - 1].model })

  onUpdateRecording = (isRecording) ->
    if isRecording 
      sendMessage("startRecording", { model: gameHistory.frames[gameHistory.currentFrameNumber].model })
    else
      sendMessage("stopRecording")

  # $scope.$watch('gameHistory.currentFrameNumber', onUpdateFrame, true)
  $scope.$watch('gameHistory.isRecording', onUpdateRecording, true)

  # TODO: need some kind of notification from flexy-layout when a block changes size!
  # Until then automatically resize once in a while.
  setInterval(onResize, 1000)
