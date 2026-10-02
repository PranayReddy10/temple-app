{{flutter_js}}
{{flutter_build_config}}

// The web engine (CanvasKit, several MB) is loaded from this site, never
// from Google's CDN (www.gstatic.com): on slow or filtered mobile networks
// the CDN could take minutes, leaving the teak loading screen up, or fail
// and stop the app. The build always ships the engine in canvaskit/, so
// this holds whether or not it was built with --no-web-resources-cdn.
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: 'canvaskit/',
  },
});
