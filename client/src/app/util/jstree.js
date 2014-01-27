angular.module('gamEvolve.util.jstree', [])

    .directive('jstree', function() {
        return {

            restrict: 'A',
            scope: { jstree: '=' },
            link: function (scope, element, attrs) {
                scope.$watch('jstree', function () {
                    $(element).jstree({
                        "json_data" : {
                            "data" : scope.jstree
                        },
                        "dnd" : {
                            "drop_finish" : function () {
                                alert("DROP");
                            },
                            "drag_check" : function (data) {
                                if(data.r.attr("id") == "phtml_1") {
                                    return false;
                                }
                                return {
                                    after : false,
                                    before : false,
                                    inside : true
                                };
                            },
                            "drag_finish" : function (data) {
                                console.log(data);
                                alert(data.o.attributes['actionId'].nodeValue);
                            }
                        },
                        "types" : {
                            "valid_children" : [ "switch" ],
                            "types" : {
                                "switch" : {
                                    "icon" : {
                                        "image" : "http://localhost:2403/assets/images/switch.png"
                                    },
                                    "valid_children" : [ "default" ],
                                    "max_depth" : 2,
                                    "hover_node" : false,
                                    "select_node" : function () {return false;}
                                },
                                "default" : {
                                    "valid_children" : [ "default" ]
                                }
                            }
                        },
                        "plugins" : [ "themes", "json_data", "ui", "dnd", "types" ]
                    });
                });
            }
        };
    });