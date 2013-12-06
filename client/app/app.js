'use strict';

angular.module('GameEvolve', [
        'ui.router',
        'ui.route',
        'ui.bootstrap.transition',
        'ui.bootstrap.collapse',
        'home'
    ])
    .config(function ($stateProvider,$urlRouterProvider,$locationProvider) {
        $locationProvider.html5Mode(true);

        $urlRouterProvider.otherwise("/");

        $stateProvider
            .state('home',{
                'url' : '/',
                'views' : {
                    'a' :{
                        'templateUrl' : 'app/views/home/home.tpl.html',
                        'controller' : 'homeCtrlA'
                    },
                    'b' : {
                        'templateUrl' : 'app/views/home/home2.tpl.html',
                        'controller' : 'homeCtrlB'
                    }
                }
            });
    });
