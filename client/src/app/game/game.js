angular.module('gamEvolve.game', [
        'flexyLayout',
        'ui.bootstrap'
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

    .controller('GameCtrl', function HomeController($scope, games, loggedUser, users) {

        $scope.noGameMessage = "Game Name";

        // Binding services
        $scope.games = games;
        $scope.user = loggedUser;
        $scope.users = users;

    })

;