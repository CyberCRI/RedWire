# TODO: this should be configurable
GAME_DIMENSIONS = [960, 540]

angular.module('gamEvolve.game.player', [])
.controller "PlayerCtrl", ($scope, games, currentGame, gameHistory, gameTime) -> 
  # Globals
  gameCode = null
  oldRoundedScale = null

  # Bring services into the scope
  $scope.currentGame = currentGame
  $scope.gameTime = gameTime

  # TODO: take out this "global" message handler?
  window.addEventListener 'message', (e) -> 
    # Sandboxed iframes which lack the 'allow-same-origin' header have "null" rather than a valid origin. 
    if e.origin isnt "null" or e.source isnt $("#gamePlayer")[0].contentWindow then return

    message = e.data

    if message.type is "error"
      console.error("Puppet reported error on operation #{message.operation}.", message.error)
    else
      console.log("Puppet reported success on operation #{message.operation}.", message)

    # TODO: handle errors in recording and update

    switch message.operation
      when "loadGameCode"
        if message.type is "error"
          $scope.$apply ->
            gameHistory.data.compilationErrors = [GE.firstLine(message.error)]
            gameHistory.meta.version++
        else
          # The game loaded successfully
          $scope.$apply ->
            gameHistory.data.compilationErrors = []
            gameHistory.meta.version++

          if gameHistory.data.frames.length > 0 and not gameHistory.data.frames[0].error?
            # If there are already frames, then update them 
            inputIoDataFrames = _.pluck(gameHistory.data.frames, "inputIoData")
            sendMessage("updateFrames", { memory: gameHistory.data.frames[0].memory, inputIoDataFrames })
          else
            # Else just record the first frame
            sendMessage("recordFrame", { memory: gameCode.memory })
      when "recordFrame"
        $scope.$apply ->
          # Set the first frame
          newFrame = null
          if message.type is "error"
            newFrame = 
              memory: gameCode.memory # Initial memory
              inputIoData: null
              ioPatches: null
              logMessages: [ 
                { 
                  path: []
                  level: GE.logLevels.ERROR
                  message: [GE.firstLine(message.error)] 
                }
              ]
          else
            newFrame = 
              memory: gameCode.memory # Initial memory
              inputIoData: message.value.inputIoData 
              ioPatches: message.value.ioPatches
              logMessages: message.value.logMessages 
          gameHistory.data.frames = [newFrame]
          gameHistory.meta.version++
          gameTime.currentFrameNumber = 0
      when "stopRecording" 
        $scope.$apply ->
          # Remove frames after the current one
          gameHistory.data.frames.length = gameTime.currentFrameNumber + 1

           # Replace the io data on the last frame
          results = message.value[0]
          gameHistory.data.frames[gameTime.currentFrameNumber].inputIoData = results.inputIoData
          gameHistory.data.frames[gameTime.currentFrameNumber].ioPatches = results.ioPatches
          gameHistory.data.frames[gameTime.currentFrameNumber].logMessages = results.logMessages

          # Add in the new results
          lastMemory = gameHistory.data.frames[gameTime.currentFrameNumber].memory
          for results in message.value[1..]
            gameHistory.data.frames.push
              memory: lastMemory
              ioPatches: results.ioPatches
              inputIoData: results.inputIoData
              logMessages: results.logMessages
            # Calcuate the next memory to be used
            lastMemory = GE.applyPatches(results.memoryPatches, lastMemory)

          # Go the the last frame
          gameTime.currentFrameNumber = gameHistory.data.frames.length - 1

          # Update the version
          gameHistory.meta.version++
      when "updateFrames" 
        $scope.$apply ->
          # Replace existing frames by the new results
          lastMemory = gameHistory.data.frames[0].memory
          for index, results of message.value
            gameHistory.data.frames[index] = 
              memory: lastMemory
              ioPatches: results.ioPatches
              inputIoData: results.inputIoData
              logMessages: results.logMessages
            # Calcuate the next memory to be used
            lastMemory = GE.applyPatches(results.memoryPatches, lastMemory)

            # Update the version
          gameHistory.meta.version++

          # Display the current frame
          onUpdateFrame(gameTime.currentFrameNumber)

  sendMessage = (operation, value) ->  
    # Note that we're sending the message to "*", rather than some specific origin. 
    # Sandboxed iframes which lack the 'allow-same-origin' header don't have an origin which you can target: you'll have to send to any origin, which might alow some esoteric attacks. 
    $('#gamePlayer')[0].contentWindow.postMessage({operation: operation, value: value}, '*')

  onUpdateCode = (code) ->
    if not code? then return

    gameCode = code
    console.log("Game code changed to", gameCode)
    sendMessage("loadGameCode", gameCode)
  $scope.$watch('currentGame.version', onUpdateCode, true)

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
    frameResult = gameHistory.data.frames[frameNumber]
    outputIoData = GE.applyPatches(frameResult.ioPatches, frameResult.inputIoData)
    sendMessage("playFrame", { outputIoData: outputIoData })
  $scope.$watch('gameTime.currentFrameNumber', onUpdateFrame, true)

  onUpdateRecording = (isRecording) ->
    if not gameCode? then return
    if isRecording 
      sendMessage("startRecording", { memory: gameHistory.data.frames[gameTime.currentFrameNumber].memory })
    else
      sendMessage("stopRecording")
  $scope.$watch('gameTime.isRecording', onUpdateRecording, true)

  # TODO: need some kind of notification from flexy-layout when a block changes size!
  # Until then automatically resize once in a while.
  setInterval(onResize, 1000)
