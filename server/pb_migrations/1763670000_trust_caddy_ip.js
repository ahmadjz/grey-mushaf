/// <reference path="../pb_data/types.d.ts" />
migrate(
  (app) => {
    const settings = app.settings();
    settings.trustedProxy.headers = ["X-Forwarded-For"];
    settings.trustedProxy.useLeftmostIP = false;
    app.save(settings);
  },
  (app) => {
    const settings = app.settings();
    settings.trustedProxy.headers = [];
    app.save(settings);
  },
);
