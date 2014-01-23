Package.describe({
  summary: "Enable server-side reactivity"
});

Package.on_use(function(api) {
  api.use('coffeescript', ['server']);
  api.use('deps', ['server']);
  api.use('underscore', ['server']);

  api.add_files('lib/server-deps.coffee', ['server']);
});
