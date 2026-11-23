{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    // The self-hosted release keeps the full runtime for all browsers.
    canvasKitVariant: _flutter.buildConfig.useLocalCanvasKit ? 'full' : 'auto',
  },
});
