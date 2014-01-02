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
      console.error("Puppet reported error", e.data.error)
    else
      console.log("Puppet reported success", e.data)

    # TODO: handle errors in recording

    switch e.data.operation
      when "stopRecording" 
        $scope.$apply ->
          # Remove frames after the current one
          gameHistory.frames.length = gameHistory.currentFrameNumber + 1

          # Add in the new results
          lastModel = gameHistory.frames[gameHistory.currentFrameNumber].model
          for results in e.data.value
            lastModel = GE.applyPatches(results.modelPatches, lastModel)
            gameHistory.frames.push
              model: lastModel
              servicePatches: results.servicePatches
              inputServiceData: results.inputServiceData

          # Go the the last frame
          gameHistory.currentFrameNumber = gameHistory.frames.length - 1


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

  onUpdateFrame = (frameNumber) ->
    if not gameCode? then return
    console.log("Changed frame to", frameNumber)
    frameResult = gameHistory.frames[frameNumber]
    outputServiceData = GE.applyPatches(frameResult.servicePatches, frameResult.inputServiceData)
    sendMessage("playFrame", { outputServiceData: outputServiceData })

  onUpdateRecording = (isRecording) ->
    if not gameCode? then return
    if isRecording 
      sendMessage("startRecording", { model: gameHistory.frames[gameHistory.currentFrameNumber].model })
    else
      sendMessage("stopRecording")

  $scope.$watch('gameHistory.currentFrameNumber', onUpdateFrame, true)
  $scope.$watch('gameHistory.isRecording', onUpdateRecording, true)

  # TODO: need some kind of notification from flexy-layout when a block changes size!
  # Until then automatically resize once in a while.
  setInterval(onResize, 1000)
