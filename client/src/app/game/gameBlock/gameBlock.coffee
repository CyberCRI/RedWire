angular.module('gamEvolve.game.block', [])
  .directive("gameBlock", ->
    return {
      restrict: "E"
      scope:
        game: "=" 
      templateUrl: 'game/gameBlock/gameBlock.tpl.html'
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


