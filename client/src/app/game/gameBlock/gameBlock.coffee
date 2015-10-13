angular.module('gamEvolve.game.block', [])
  .directive("gameBlock", ->
    return {
      restrict: "E"
      scope:
        game: "=" 
      templateUrl: 'game/gameBlock/gameBlock.tpl.html'
      link: (scope, element, attrs) ->
        staticImage = "url(#{scope.game.screenshot})" 
        animatedImage = "url(#{scope.game.animation})" 

        # Default to static image
        element.find(".screenshot").css("background-image", staticImage)
        
        element.on "mouseenter", ->
          console.log("animating")
          element.find(".screenshot").css("background-image", animatedImage)
        element.on "mouseleave", ->
          console.log("static")
          element.find(".screenshot").css("background-image", staticImage)
    }
  )
  .directive("gameBlockPanel", ->
    return {
      restrict: "E"
      scope:
        title: "="
        games: "=" 
      templateUrl: 'game/gameBlock/gameBlockPanel.tpl.html'
      controller: ($scope) ->
        updateRows = ->
          # Split the games into rows of 3
          $scope.rows = []
          currentRow = []
          for index, game of $scope.games 
            currentRow.push(game)

            # Make a new row if needed
            if index % 3 is 2
              $scope.rows.push(currentRow)
              currentRow = []

          # Add last row if needed
          if currentRow.length > 0        
              $scope.rows.push(currentRow)

        $scope.$watch("games", updateRows)
     }
   )


