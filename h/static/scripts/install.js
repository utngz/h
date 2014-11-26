// Injects the hypothesis dependencies. These can be either js or css, the
// file extension is used to determine the loading method. This file is
// pre-processed in order to insert the wgxpath and inject scripts.
//
// Custom injectors can be provided to load the scripts into a different
// environment. Both script and stylesheet methods are provided with a url
// and a callback fn that expects either an error object or null as the only
// argument.
//
// For example a Chrome extension may look something like:
//
//   window.hypothesisInstall({
//     script: function (src, fn) {
//       chrome.tabs.executeScript(tab.id, {file: src}, fn);
//     },
//     stylesheet: function (href, fn) {
//       chrome.tabs.insertCSS(tab.id, {file: href}, fn);
//     }
//   });
function loadResources(resources, inject) {
  inject = inject || {};

  var injectStylesheet = inject.stylesheet || function injectStylesheet(href, fn) {
    var link = document.createElement('link');
    link.rel = 'stylesheet';
    link.type = 'text/css';
    link.href = href;

    document.head.appendChild(link);
    fn(null);
  };

  var injectScript = inject.script || function injectScript(src, fn) {
    var script = document.createElement('script');
    script.type = 'text/javascript';
    script.onload = function () { fn(null); };
    script.onerror = function () { fn(new Error('Failed to load script: ' + src)); };
    script.src = src;

    document.head.appendChild(script);
  };

  (function next(err) {
    if (err) { throw err; }

    if (resources.length) {
      var url = resources.shift();
      var ext = url.split('?')[0].split('.').pop();
      var fn = (ext === 'css' ? injectStylesheet : injectScript);
      fn(url, next);
    }
  })();
}

// Appends a <link> tag to the document to enable the Hypothesis application
// to discover the address of the sidebar application.
function appendSidebarLink(baseURL) {
  var link = document.createElement('link');
  link.rel = 'sidebar';
  link.href = baseURL + 'app.html';
  link.type = 'application/annotator+html';
  document.head.appendChild(link);
}
