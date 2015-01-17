Package.describe({
  summary: "Server-side Tracker.autorun",
  version: '0.2.0',
  name: 'peerlibrary:server-autorun',
  git: 'https://github.com/peerlibrary/meteor-server-autorun.git'
});

Package.on_use(function (api) {
  api.versionsFrom('METEOR@1.0.2.1');
  api.use(['coffeescript', 'underscore', 'tracker'], 'server');

  api.add_files([
    'server.coffee'
  ], 'server');
});
