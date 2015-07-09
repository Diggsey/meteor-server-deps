Package.describe({
  summary: "Server-side Tracker.autorun",
  version: '0.3.0',
  name: 'peerlibrary:server-autorun',
  git: 'https://github.com/peerlibrary/meteor-server-autorun.git'
});

Package.onUse(function (api) {
  api.versionsFrom('1.0.3.1');

  // Core dependencies.
  api.use([
    'coffeescript',
    'underscore',
    'tracker'
  ]);

  // 3rd party dependencies.
  api.use([
    'peerlibrary:assert@0.2.5'
  ], 'server');

  api.addFiles([
    'client.coffee'
  ], 'client');

  api.addFiles([
    'server.coffee'
  ], 'server');
});

Package.onTest(function (api) {
  // Core dependencies.
  api.use([
    'tinytest',
    'test-helpers',
    'coffeescript',
    'mongo',
    'reactive-var'
  ]);

  // Internal dependencies.
  api.use([
    'peerlibrary:server-autorun'
  ]);

  api.addFiles([
    'meteor/packages/tracker/tracker_tests.js',
    'tests.coffee'
  ]);
});
