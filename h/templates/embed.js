(function (window) {
  {% include_raw 'h:static/scripts/install.js' %}

  var resources = [];
  if (!window.document.evaluate) {
    resources = resources.concat(['{{ layout.xpath_polyfil_urls | map("string") | join("', '") | safe }}']);
  }

  if (typeof window.Annotator === 'undefined') {
    resources = resources.concat(['{{ layout.app_inject_urls | map("string") | join("', '") | safe }}']);
  }

  loadResources(resources);
  appendSidebarLink('{{ base_url }}');
})(this);
