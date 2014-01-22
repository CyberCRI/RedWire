angular.module('gamEvolve.util.tree', [])

    .directive('jstree', function () {

        return {
            restrict: 'A',

            scope: {
                //create a two-way binding between this scope and the attribute's value
                jstree: '='
            },

            //call this function to construct the element
            link: function (scope, element, attrs) {
                scope.$watch('jstree', function () {
                    $(element).jstree();
                    $(element).jstree().destroy();
                    $(element).jstree({
                        'core': {
                            'animation': 0,
                            'check_callback': true,
                            'themes': { 'stripes': true },
                            'data': scope.jstree },
                        'types': {
                            'root': {
                            },
                            'switch': {
                            },
                            'action': {
                                'valid_children': []
                            },
                            'unknown': {
                            }
                        },
                        'plugins': [ 'types', 'dnd' ]
                    });
                }, false);
            }

        };
    });