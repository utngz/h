###*
# @ngdoc type
# @name thread.ThreadController
#
# @property {Object} container The thread domain model. An instance of
# `mail.messageContainer`.
# @property {boolean} collapsed True if the thread is collapsed.
#
# @description
# `ThreadController` provides an API for the thread directive controlling
# the collapsing behavior.
###
ThreadController = [
  ->
    @container = null
    @collapsed = false

    ###*
    # @ngdoc method
    # @name thread.ThreadController#toggleCollapsed
    # @description
    # Toggle the collapsed property.
    ###
    this.toggleCollapsed = ->
      @collapsed = not @collapsed

    ###*
    # @ngdoc method
    # @name thread.ThreadController#isCard
    # @returns {Boolean} True if this thread controller is a top-level card.
    ###
    this.isCard = ->
      @container.parent && !@container.parent.parent

    this
]


###*
# @ngdoc directive
# @name thread
# @restrict A
# @description
# Directive that instantiates {@link thread.ThreadController ThreadController}.
#
# If the `thread-collapsed` attribute is specified, it is treated as an
# expression to watch in the context of the current scope that controls
# the collapsed state of the thread.
###
thread = [
  '$parse', '$window', 'render',
  ($parse,   $window,   render) ->
    linkFn = (scope, elem, attrs, [ctrl, counter]) ->
      ctrl.container = $parse(attrs.thread)(scope)

      counter.count 'message', 1
      scope.$on '$destroy', -> counter.count 'message', -1

      # Add and remove the collapsed class when the collapsed property changes.
      scope.$watch 'search.query', (query) ->
        ctrl.collapsed = !query

    controller: 'ThreadController'
    controllerAs: 'vm'
    link: linkFn
    require: ['thread', '?^deepCount']
    scope: true
]


angular.module('h')
.controller('ThreadController', ThreadController)
.directive('thread', thread)
