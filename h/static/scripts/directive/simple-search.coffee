module.exports = ['$http', '$parse', ($http, $parse) ->
  link: (scope, elem, attr, ctrl) ->
    scope.reset = (event) ->
      event.preventDefault()
      scope.query = ''
      scope.searchtext = ''

    scope.search = (event) ->
      event.preventDefault()
      scope.query = scope.searchtext

    scope.$watch (-> $http.pendingRequests.length), (pending) ->
      scope.loading = (pending > 0)

    scope.$watch 'query', (query) ->
      return if query is undefined
      scope.searchtext = query
      if query
        scope.onSearch?(query: scope.searchtext)
      else
        scope.onClear?()

  restrict: 'C'
  scope:
    query: '='
    onSearch: '&'
    onClear: '&'
  template: '''
            <form class="simple-search-form" ng-class="!searchtext && 'simple-search-inactive'" name="searchBox" ng-submit="search($event)">
              <input class="simple-search-input" type="text" ng-model="searchtext" name="searchText"
                     placeholder="{{loading && 'Loading' || 'Search notes'}}…"
                     ng-disabled="loading" />
              <span class="simple-search-icon" ng-hide="loading">
                <i class="h-icon-search"></i>
              </span>
              <span class="simple-search-icon" ng-show="loading">
                <i class="spinner"></i>
              </span>
            </form>
            '''
]
