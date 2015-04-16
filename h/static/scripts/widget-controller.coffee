angular = require('angular')


module.exports = class WidgetController
  this.$inject = [
    '$rootScope', '$scope', 'annotationUI', 'crossframe', 'annotationMapper',
    'streamer', 'streamFilter', 'store'
  ]
  constructor:   (
     $rootScope, $scope,   annotationUI, crossframe, annotationMapper,
     streamer,   streamFilter,   store
  ) ->
    # Tells the view that these annotations are embedded into the owner doc
    $scope.isEmbedded = true
    $scope.isStream = true

    @chunkSize = 200
    loaded = []

    _loadAnnotationsFrom = (query, offset) =>
      queryCore =
        limit: @chunkSize
        offset: offset
        sort: 'created'
        order: 'asc'
      q = angular.extend(queryCore, query)

      store.SearchResource.get q, (results) ->
        total = results.total
        offset += results.rows.length
        if offset < total
          _loadAnnotationsFrom query, offset

        annotationMapper.loadAnnotations(results.rows)

    loadAnnotations = ->
      query = {}

      for p in crossframe.providers
        for e in p.entities when e not in loaded
          loaded.push e
          q = angular.extend(uri: e, query)
          _loadAnnotationsFrom q, 0

      streamFilter.resetFilter().addClause('/uri', 'one_of', loaded)

      streamer.send({filter: streamFilter.getFilter()})

    $scope.$watchCollection (-> crossframe.providers), loadAnnotations

    $scope.focus = (annotation) ->
      if angular.isObject annotation
        highlights = [annotation.$$tag]
      else
        highlights = []
      crossframe.notify
        method: 'focusAnnotations'
        params: highlights

    $scope.scrollTo = (annotation) ->
      if angular.isObject annotation
        crossframe.notify
          method: 'scrollToAnnotation'
          params: annotation.$$tag

    $scope.shouldShowThread = (container) ->
      if annotationUI.hasSelectedAnnotations() and not container.parent.parent
        annotationUI.isAnnotationSelected(container.message?.id)
      else
        true

    $scope.hasFocus = (annotation) ->
      !!($scope.focusedAnnotations ? {})[annotation?.$$tag]

    $scope.notOrphan = (container) -> !container?.message?.$orphan

    $scope.filterView = (container) ->
      # If an annnoation is being edited it should show up in any view.
      if not container?.message?.permissions?.read?
        return true
      else if $rootScope.socialview.name == 'All'
        # Filter out group annotations.
        str1 = "group:"
        re1 = new RegExp(str1, "g");
        # if re1.test(container?.message?.tags)
        #   for tag in container?.message?.tags
        #     console.log tag
        !re1.test(container?.message?.tags)
      else if $rootScope.socialview.name != 'All'
        # console.log $rootScope.socialview.name
        # console.log container?.message?.tags?[0]?
        # debugger
        # if container?.message?.tags?[0] == undefined
        #   return false
        # else
        str2 = "group:" + $rootScope.socialview.name
        re2 = new RegExp(str2, "g");
        re2.test(container?.message?.tags)
    
    $rootScope.views = [
        {name:'All', icon:'h-icon-public', selected:true}
        # {name:'groupName', icon:'h-icon-group', selected:false}
    ]

    $rootScope.viewnames = ['All']

    $rootScope.socialview = $rootScope.views[0]
