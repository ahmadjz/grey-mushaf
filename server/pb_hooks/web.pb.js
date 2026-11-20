/// <reference path="../pb_data/types.d.ts" />
// The mushaf files sit in private/, outside the public dir, so no path spelling can reach them through the shell route.

routerAdd("GET", "/{path...}", (e) => {
  e.response.header().set("Cache-Control", "no-cache");
  return $apis.static(($os.getenv("MUSHAF_WEB_DIR") || "/pb/web") + "/public", true)(e);
});

routerAdd("GET", "/assets/assets/{path...}", (e) => {
  e.response.header().set("Cache-Control", "private, no-store");
  let record = null;
  try {
    record = $app.findAuthRecordByToken(e.request.cookie("mushaf_session").value, "auth");
  } catch (_) {}
  if (!record || record.collection().name !== "users" || !record.verified()) {
    throw new UnauthorizedError("Sign in to read the mushaf.");
  }
  return $apis.static(($os.getenv("MUSHAF_WEB_DIR") || "/pb/web") + "/private", false)(e);
});

routerAdd(
  "POST",
  "/api/mushaf/session",
  (e) => {
    if (!e.auth.verified()) throw new ForbiddenError("Verify the account first.");
    e.response.header().set("Cache-Control", "no-store");
    e.setCookie(
      new Cookie({
        name: "mushaf_session",
        value: e.request.header.get("Authorization").replace(/^Bearer\s+/i, ""),
        path: "/",
        secure: true,
        httpOnly: true,
        sameSite: 3,
      }),
    );
    return e.noContent(204);
  },
  $apis.requireAuth("users"),
);

routerAdd("DELETE", "/api/mushaf/session", (e) => {
  e.response.header().set("Cache-Control", "no-store");
  e.setCookie(
    new Cookie({ name: "mushaf_session", value: "", path: "/", maxAge: -1, secure: true, httpOnly: true, sameSite: 3 }),
  );
  return e.noContent(204);
});
