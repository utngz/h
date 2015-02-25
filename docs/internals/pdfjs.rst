Integrating Hypothes.is + PDF.js
================================

The goal of this documentation is to describe how we use PDF.js in
Hypothes.is, how do we deploy it, how do we integrate our software to
it, what APIs / internal access points we are using to achieve various
things, etc.

Currently, I am just documenting what we have now. The plan is that

-  The PDF.js developers can give us some advice, based on this, and
-  We might even be able to contribute to the process of improving the
   available APIs of PDF.js.

Status and scope
----------------

As of this writing (2015-02-25), we are supporting:

-  PDF.js `v1.0.68`_, which is shipped with the FF ESR versions
-  PDF.js `v1.0.277`_
-  PDF.js `v1.0.473`_
-  PDF.js `v1.0.712`_
-  PDF.js `v1.0.907`_
-  PDF.js v1.0.937, which doesn’t seem to be an `official PDF.js
   release`_, but this still, version is embedded in FF 36 (stable +
   beta versions)

Not (yet) supported/evaluated:

-  any versions older than v1.0.68 (hopefully, those versions are not
   around any more)
-  PDF.js `v1.0.1040`_, which is shipped with FF Developer Edition
   (formerly known as Aurora a.k.a. alpha) 37.0a2 (we plan to support
   this by the time it enters the FF beta channel)

In some cases, the various PDF.js versions offer slightly different APIs
to achieve the same thing. We support all these variations. In the
examples below, I’ll always describe the way we access the latest
supported version.

Integration / deployment
------------------------

In the Chrome extension
~~~~~~~~~~~~~~~~~~~~~~~

TBD

In Firefox
~~~~~~~~~~

TBD

In VIA
~~~~~~

TBD

APIs and data access
--------------------

Testing if we are in a PDF.js environment
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

We check for the existence of the ``PDFViewerApplication`` variable. If
it exists, we assume that we are looking at a document rendered by
PDF.js.

Determining when we can start to process data
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

-  Upon initialization, we start to periodically check for the existence
   of the ``PDFViewerApplication.documentInfo`` and
   ``PDFViewerApplication.documentFingerprint`` properties.
-  When both are available, we assume that it’s time to start accessing
   the document.

Extracting metadata about the document
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

We read ``PDFViewerApplication.documentFingerprint`` and
``PDFViewerApplication.documentInfo``.

Determining the number of pages of the document
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

We read ``PDFViewerApplication.pdfDocument.numPages``

Determining the index of the currently viewed page
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

We read ``PDFViewerApplication.page``.

Jumping to a page
~~~~~~~~~~~~~~~~~

We write ``PDFViewerApplication.page``.

Determining whether or not a given page is fully rendered
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

-  We check whether ``PDFViewerApplication.pdfViewer.pages[index]``
   exists
-  If it exists, then we search for a ``textLayer`` property on it.
-  If it exists, then we check for a ``renderingDone`` property on it.
-  If it’s truthy, then we conclude that the page has been rendered.

Detecting the event when a new page is rendered
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

-  We register a listener to ``pagerender`` and ``pagerendered`` events.
-  When the listener is called, we extract the page number by reading
   ``event.detail.pageNUmber``.

Detecting the event when a page is un-rendered
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

-  We register a listener to the ``DOMNodeRemoved`` events.
-  When the listener is called, we check whether the removed node was a
   DIV, with the class name ``text``.
-  If it was, then we assume that this was a root node of a page which
   has been unrendered
-  We extract the unrendered page number by reading the id of the parent
   node of the removed node.

Getting the root DOM node for (the text layer of) a page
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

We read
``PDFViewerApplication.pdfViewer.pages[index].textLayer.textLayerDiv``

Determining the page index of a given DOM node
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

-  We start to look at the node.
-  We check if it has the ``textLayer`` class.
-  If it doesn’t have the class, we move on the parent, and restart
-  If it has the class, we read out the id of it’s parent node, which
   will have the page number


Extracting the text content of the document
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

1. We call ``PDFViewerApplication.pdfDocument.getPage(index)``.
2. When the returned promise is resolved, we call the
   ``getTextContent()`` method on the returned object.
3. When the returned promise is resolved, we take the returned ``data``
   object, and
4. concatenate the ``str`` properties of each object found in the
   ``data.items`` array, adding a space when joining them.
5. In the resulting string, we compact all instances of multiple spaces
   to a single space.
6. Then we move on to the next page, and restart from process from step
   1.

This part warrants some explanation. PDF.js’s own ``PDFFindController``
class also has some built-in method for extracting the text from the
pages. The reason we are currently not using that method is that when
concatenating the different strings, it doesn’t always add a whitespace
between them. We have seen some documents, where this resulting in
wordsconcatenetedtoeachotherwithoutspacing.

That’s why we access the pieces of text directly. This situation might
have improved in recent PDF.js versions; we haven’t checked it for a
while. But even if it has, since we need to keep supporting all
versions, too, I don’t think we can remove our workaround in the near
future.

.. _v1.0.68: https://github.com/mozilla/pdf.js/releases/tag/v1.0.68
.. _v1.0.277: https://github.com/mozilla/pdf.js/releases/tag/v1.0.277
.. _v1.0.473: https://github.com/mozilla/pdf.js/releases/tag/v1.0.473
.. _v1.0.712: https://github.com/mozilla/pdf.js/releases/tag/v1.0.712
.. _v1.0.907: https://github.com/mozilla/pdf.js/releases/tag/v1.0.907
.. _official PDF.js release: https://github.com/mozilla/pdf.js/releases
.. _v1.0.1040: https://github.com/mozilla/pdf.js/releases/tag/v1.0.1040

