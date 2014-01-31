angular.module('gamEvolve.game', [
        'flexyLayout',
        'ui.bootstrap',
        'gamEvolve.game.select'
    ])

    .config(function config($stateProvider) {
        $stateProvider
            .state('game', {
                url: '/game',
                views: {
                    "main": {
                        controller: 'GameCtrl',
                        templateUrl: 'game/game.tpl.html'
                    }
                },
                abstract: true
            })
        ;
    })

    .controller('GameCtrl', function ($scope, currentGame, games, loggedUser, loginDialog, gameSelectionDialog, importExportDialog) {
        // Binding services
        $scope.currentGame = currentGame;
        $scope.games = games;
        $scope.user = loggedUser;
        $scope.loginDialog = loginDialog;
        $scope.gameSelectionDialog = gameSelectionDialog;
        $scope.importExportDialog = importExportDialog;
    })

;