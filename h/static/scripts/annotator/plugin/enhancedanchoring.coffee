Annotator = require('annotator')
$ = Annotator.$

# A NodeFilter bitmask that matches node types included by `Node.textContent`.
TEXT_CONTENT_FILTER = (
  NodeFilter.SHOW_ALL &
  ~NodeFilter.SHOW_COMMENT &
  ~NodeFilter.SHOW_PROCESSING_INSTRUCTION
)


class DefaultAccessStrategy

  @applicable: -> true
  getCorpus: -> document.body.textContent
  getPageIndex: -> 0
  getPageCount: -> 1
  getPageIndexForPos: -> 0
  isPageMapped: -> true

  getStartPosForNode: (node) ->
    offset = 0

    # Walk the nodes of the body included by `Node.textContent`.
    walker = document.createTreeWalker(document.body, TEXT_CONTENT_FILTER)

    # Start from the current node.
    walker.currentNode = node

    # Continue until the current node is null.
    while node?

      # Step backwards through siblings, to count the leading content.
      while cur = walker.previousSibling()
        offset += cur.textContent.length

      # Step up to the parent and continue until done.
      node = walker.parentNode()

    return offset

  getEndPosForNode: (node) ->
    return this.getStartPosForNode(node) + node.textContent.length

  getContextForCharRange: (start, end) ->
    corpus = this.getCorpus()
    return [corpus.substr(start-32, 32), corpus.substr(end, 32)]

  getMappingsForCharRange: (start, end) ->
    # Seek a TreeWalker forward by the given offset. The length of all the text
    # content skipped in this manner may be less than the requested offset.
    # The return value is the remainder, or zero, after advancing the walker
    # up to, but not more than, the requested offset.
    _seek = (walker, offset) ->
      while offset > 0
        next = offset - walker.currentNode.textContent.length

        # If this node is longer than the offset, step in to it.
        if next < 0

          # Finish if there is no smaller step to take.
          if walker.firstChild() is null
            break

          # Otherwise, continue with the first child.
          else
            continue

        # Step over this node. Failing that, step out or error.
        else if walker.nextSibling() is null
          if walker.nextNode() is null
            throw new Error('Unexpected document end')

        # Update the offset and continue.
        offset = next

      # Return the remaining offset.
      return offset

    # Create a Range object for storing the result.
    range = document.createRange()

    # Walk the nodes of the body included by `Node.textContent`.
    walker = document.createTreeWalker(document.body, TEXT_CONTENT_FILTER)

    # Seek to the start and update the range.
    offset = _seek(walker, start)
    range.setStart(walker.currentNode, offset)

    # Seek to the end and update the range.
    offset = _seek(walker, end - start + offset)
    range.setEnd(walker.currentNode, offset)

    # Return a section map providing this range for page 0.
    return sections: [{realRange: range}]


# Abstract anchor class.
class Anchor

  constructor: (@anchoring, @annotation, @target
      @startPage, @endPage,
      @quote, @diffHTML, @diffCaseOnly) ->

    unless @anchoring? then throw "anchoring manager is required!"
    unless @annotation? then throw "annotation is required!"
    unless @target? then throw "target is required!"
    unless @startPage? then "startPage is required!"
    unless @endPage? then throw "endPage is required!"
    unless @quote? then throw "quote is required!"

    @highlight = {}

  _getSegment: (page) ->
    throw "Function not implemented"

  # Create the missing highlights for this anchor
  realize: () =>
    return if @fullyRealized # If we have everything, go home

    # Collect the pages that are already rendered
    renderedPages = [@startPage .. @endPage].filter (index) =>
      @anchoring.document.isPageMapped index

    # Collect the pages that are already rendered, but not yet anchored
    pagesTodo = renderedPages.filter (index) => not @highlight[index]?

    return unless pagesTodo.length # Return if nothing to do

    # Create the new highlights
    created = for page in pagesTodo
      # TODO: add a layer of abstraction here
      # Don't call TextHighlight directly; instead, make a system
      # For registering highlight creators, or publish an event, or
      # whatever
      @highlight[page] = Annotator.TextHighlight.createFrom @_getSegment(page), this, page

    # Check if everything is rendered now
    @fullyRealized = renderedPages.length is @endPage - @startPage + 1

    # Announce the creation of the highlights
    @anchoring.annotator.publish 'highlightsCreated', created

    # If we are supposed to scroll to the highlight on a page,
    # and it's available now, go scroll there.
    if @pendingScrollTargetPage? and (hl = @highlight[@pendingScrollTargetPage])
      hl.scrollToView()
      delete @pendingScrollTargetPage

  # Remove the highlights for the given set of pages
  virtualize: (pageIndex) =>
    highlight = @highlight[pageIndex]

    return unless highlight? # No highlight for this page

    highlight.removeFromDocument()

    delete @highlight[pageIndex]

    # Mark this anchor as not fully rendered
    @fullyRealized = false

    # Announce the removal of the highlight
    @anchoring.annotator.publish 'highlightRemoved', highlight

  # Virtualize and remove an anchor from all involved pages
  remove: ->
    # Go over all the pages
    for index in [@startPage .. @endPage]
      @virtualize index
      anchors = @anchoring.anchors[index]
      # Remove the anchor from the list
      i = anchors.indexOf this
      anchors[i..i] = []
      # Kill the list if it's empty
      delete @anchoring.anchors[index] unless anchors.length

  # Scroll to this anchor
  scrollToView: ->
    currentPage = @anchoring.document.getPageIndex()

    if @startPage is @endPage and currentPage is @startPage
      # It's all in one page. Simply scrolling
      @highlight[@startPage].scrollToView()
    else
      if currentPage < @startPage
        # We need to go forward
        wantedPage = @startPage
        scrollPage = wantedPage - 1
      else if currentPage > @endPage
        # We need to go backwards
        wantedPage = @endPage
        scrollPage = wantedPage + 1
      else
        # We have no idea where we need to go.
        # Let's just go to the start.
        wantedPage = @startPage
        scrollPage = wantedPage

      # Is this rendered?
      if @anchoring.document.isPageMapped wantedPage
        # The wanted page is already rendered, we can simply go there
        @highlight[wantedPage].scrollToView()
      else
        # Not rendered yet. Go to the page, we will continue from there
        @pendingScrollTargetPage = wantedPage
        @anchoring.document.setPageIndex scrollPage
        null

Annotator.Anchor = Anchor

# This plugin contains the enhanced anchoring framework.
class Annotator.Plugin.EnhancedAnchoring extends Annotator.Plugin

  constructor: ->

  # Initializes the available document access strategies
  _setupDocumentAccessStrategies: ->
    @documentAccessStrategies = [
      # Default strategy for simple HTML documents.
      name: "Basic"
      mapper: DefaultAccessStrategy
    ]

    this

  # Initializes the components used for analyzing the document
  chooseAccessPolicy: ->
    if @document? then return

    # Go over the available strategies
    for s in @documentAccessStrategies
      # Can we use this strategy for this document?
      if s.mapper.applicable()
        @documentAccessStrategy = s
        @document = new s.mapper()
        @anchors = {}
        addEventListener "docPageMapped", (evt) =>
          @_realizePage evt.pageIndex
        addEventListener "docPageUnmapped", (evt) =>
          @_virtualizePage evt.pageIndex
        s.init?()
        return this

  # Remove the current document access policy
  _removeCurrentAccessPolicy: ->
    return unless @document?

    list = @documentAccessStrategies
    index = list.indexOf @documentAccessStrategy
    list.splice(index, 1) unless index is -1

    @document.destroy?()
    delete @document

  # Perform a scan of the DOM. Required for finding anchors.
  _scan: ->
    # Ensure that we have a document access strategy
    @chooseAccessPolicy()
    try
      @pendingScan = @document.scan()
    catch
      @_removeCurrentAccessPolicy()
      @_scan()
      return

  # Plugin initialization
  pluginInit: ->
    @selectorCreators = []
    @strategies = []
    @_setupDocumentAccessStrategies()

    self = this
    @annotator.anchoring = this

    # Override loadAnnotations to account for the possibility that the anchoring
    # plugin is currently scanning the page.
    _loadAnnotations = Annotator.prototype.loadAnnotations
    Annotator.prototype.loadAnnotations = (annotations=[]) ->
      if self.pendingScan?
        # Schedule annotation load for when scan has finished
        self.pendingScan.then =>
          _loadAnnotations.call(this, annotations)
      else
        _loadAnnotations.call(this, annotations)

  # PUBLIC Try to find the right anchoring point for a given target
  #
  # Returns an Anchor object if succeeded, null otherwise
  createAnchor: (annotation, target) ->
    unless target?
      throw new Error "Trying to find anchor for null target!"

    error = null
    anchor = null
    for s in @strategies
      try
        a = s.code.call this, annotation, target
        if a
          # Store this anchor for the annotation
          annotation.anchors.push a

          # Store the anchor for all involved pages
          for pageIndex in [a.startPage .. a.endPage]
            @anchors[pageIndex] ?= []
            @anchors[pageIndex].push a

          # Realizing the anchor
          a.realize()

          return result: a
      catch error
        console.log "Strategy '" + s.name + "' has thrown an error.",
          error.stack ? error

    return error: "No strategies worked."

  # Do some normalization to get a "canonical" form of a string.
  # Used to even out some browser differences.
  normalizeString: (string) -> string.replace /\s{2,}/g, " "

  # Find the given type of selector from an array of selectors, if it exists.
  # If it does not exist, null is returned.
  findSelector: (selectors, type) ->
    for selector in selectors
      if selector.type is type then return selector
    null

  # Realize anchors on a given pages
  _realizePage: (index) ->
    # If the page is not mapped, give up
    return unless @document.isPageMapped index

    # Go over all anchors related to this page
    for anchor in @anchors[index] ? []
      anchor.realize()

  # Virtualize anchors on a given page
  _virtualizePage: (index) ->
    # Go over all anchors related to this page
    for anchor in @anchors[index] ? []
      anchor.virtualize index

  # Collect all the highlights (optionally for a given set of annotations)
  getHighlights: (annotations) ->
    results = []
    for anchor in @getAnchors(annotations)
      for page, highlight of anchor.highlight
        results.push highlight
    results

  # Collect all the anchors (optionally for a given set of annotations)
  getAnchors: (annotations) ->
    results = []
    if annotations?
      # Collect only the given set of annotations
      for annotation in annotations
        $.merge results, annotation.anchors
    else
      # Collect from everywhere
      for page, anchors of @anchors
        $.merge results, anchors
    results


  # PUBLIC entry point 1:
  # This is called to create a target from a raw selection,
  # using selectors created by the registered selector creators
  getSelectorsFromSelection: (selection) =>
    selectors = []
    for c in @selectorCreators
      description = c.describe selection
      for selector in description
        selectors.push selector

    selectors

exports.Anchor = Anchor
exports.EnhancedAnchoring = Annotator.Plugin.EnhancedAnchoring
