{{flutter_js}}
{{flutter_build_config}}

(() => {
  const progress = document.querySelector('#jotcalc-loading progress');
  const config = {
    // The self-hosted release keeps the full runtime for all browsers.
    canvasKitVariant: _flutter.buildConfig.useLocalCanvasKit ? 'full' : 'auto',
  };

  _flutter.loader.load({
    config,
    onEntrypointLoaded: async (engineInitializer) => {
      if (progress) progress.value = 2;
      const appRunner = await engineInitializer.initializeEngine(config);
      if (progress) progress.value = 3;
      await appRunner.runApp();
    },
  });
})();
