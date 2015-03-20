class StreamSearchController
  this.inject = [
    '$scope', '$rootScope', '$routeParams',
    'auth', 'queryparser', 'searchfilter', 'store',
    'streamer', 'streamfilter', 'annotationMapper'
  ]
  constructor: (
     $scope,   $rootScope,   $routeParams
     auth,   queryparser,   searchfilter,   store,
     streamer,   streamfilter, annotationMapper
  ) ->
    # Initialize the base filter
    streamfilter
      .resetFilter()
      .setMatchPolicyIncludeAll()

    # Apply query clauses
    $scope.search.query = $routeParams.q
    terms = searchfilter.generateFacetedFilter $scope.search.query
    queryparser.populateFilter streamfilter, terms
    streamer.send({filter: streamfilter.getFilter()})

    # Perform the search
    searchParams = searchfilter.toObject $scope.search.query
    query = angular.extend limit: 10, searchParams
    store.SearchResource.get query, ({rows}) ->
      annotationMapper.loadAnnotations(rows)

      # Fetch parents
      rootAncestors = []
      for annotation in rows
        if annotation.references?
          rootId = annotation.references[0]
          if rootId not in rootAncestors
            rootAncestors.push(rootId)

      for id in rootAncestors
        store.AnnotationResource.read {id: id}, (annotation) ->
          annotationMapper.loadAnnotations([annotation])

        store.SearchResource.get {references: id}, (result) ->
          annotations = result.rows # Not to shadow the rows from above
          annotationMapper.loadAnnotations(annotations)

    $scope.isEmbedded = false
    $scope.isStream = true

    $scope.sort.name = 'Newest'

    $scope.shouldShowThread = (container) ->
      container.message isnt null

    $scope.$on '$destroy', ->
      $scope.search.query = ''

angular.module('h')
.controller('StreamSearchController', StreamSearchController)
