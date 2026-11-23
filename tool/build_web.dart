import 'dart:io';

Future<void> main(List<String> arguments) async {
  final baseHref = arguments.isEmpty ? '/' : arguments.first;
  if (arguments.length > 1 ||
      !RegExp(r'^/(?:[a-zA-Z0-9._~-]+/)*$').hasMatch(baseHref)) {
    stderr.writeln('Usage: dart tool/build_web.dart [/path/]');
    exitCode = 64;
    return;
  }

  final project = Platform.script.resolve('../');
  final build = await Directory.fromUri(project.resolve('build/')).create();
  final resolvedBuild = Directory(await build.resolveSymbolicLinks());
  if (resolvedBuild.uri != build.absolute.uri.normalizePath()) {
    throw FileSystemException('Expected a local build directory', build.path);
  }
  final staging = await build.createTemp('web-release-');
  try {
    final flutter = await Process.start(
      Platform.isWindows ? 'flutter.bat' : 'flutter',
      [
        'build',
        'web',
        '--release',
        '--no-wasm-dry-run',
        '--no-web-resources-cdn',
        '--base-href=$baseHref',
        '--output=${staging.absolute.path}',
      ],
      workingDirectory: project.toFilePath(),
      runInShell: Platform.isWindows,
      mode: ProcessStartMode.inheritStdio,
    );
    exitCode = await flutter.exitCode;
    if (exitCode != 0) return;

    await trimCanvasKit(staging);
    final bootstrap = File.fromUri(staging.uri.resolve('flutter_bootstrap.js'));
    final script = await bootstrap.readAsString();
    await bootstrap.writeAsString(
      script.replaceFirst(
        RegExp(r'^//# sourceMappingURL=flutter\.js\.map\r?\n', multiLine: true),
        '',
      ),
    );
    // The bootstrap already embeds the loader.
    for (final name in ['flutter.js', 'flutter.js.map']) {
      final file = File.fromUri(staging.uri.resolve(name));
      if (await file.exists()) await file.delete();
    }

    final release = Directory.fromUri(build.uri.resolve('web-release/'));
    if (await release.exists()) {
      // Replace only a generated release in this project's build directory.
      final releasePath = release.absolute.uri.normalizePath().toFilePath();
      final resolvedRelease = Directory(await release.resolveSymbolicLinks())
          .uri
          .toFilePath();
      if (resolvedRelease != releasePath) {
        throw FileSystemException(
          'Expected a local web release directory',
          releasePath,
        );
      }
      await release.delete(recursive: true);
    }
    await staging.rename(release.path);
    stdout.writeln('Publish build/web-release.');
  } finally {
    if (await staging.exists()) await staging.delete(recursive: true);
  }
}

Future<void> trimCanvasKit(Directory staging) async {
  final canvasKit = Directory.fromUri(staging.uri.resolve('canvaskit/'));
  final keep = {
    for (final name in ['canvaskit.js', 'canvaskit.wasm'])
      File.fromUri(canvasKit.uri.resolve(name)).path,
  };
  for (final path in keep) {
    if (!await File(path).exists()) {
      throw FileSystemException('Missing the full CanvasKit runtime', path);
    }
  }

  await for (final entry in canvasKit.list(followLinks: false)) {
    if (!keep.contains(entry.path)) await entry.delete(recursive: true);
  }
}
