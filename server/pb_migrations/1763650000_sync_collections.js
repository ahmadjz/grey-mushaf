/// <reference path="../pb_data/types.d.ts" />
const uuidPattern =
  "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$";
const own = "user = @request.auth.id";
const ownCreate =
  '@request.auth.id != "" && @request.auth.collectionName = "users" && @request.body.user = @request.auth.id';

const actionCollection = (users, name, fields, createCheck) =>
  new Collection({
    type: "base",
    name,
    listRule: own,
    viewRule: own,
    createRule: createCheck ? `${ownCreate} && (${createCheck})` : ownCreate,
    updateRule: null,
    deleteRule: null,
    fields: [
      {
        name: "user",
        type: "relation",
        required: true,
        collectionId: users.id,
        cascadeDelete: true,
        maxSelect: 1,
      },
      { name: "uuid", type: "text", required: true, pattern: uuidPattern },
      { name: "device", type: "text", required: true, pattern: uuidPattern },
      { name: "created_at", type: "number", onlyInt: true, min: 0 },
      { name: "seq", type: "number", onlyInt: true, min: 0 },
      ...fields,
      { name: "created", type: "autodate", onCreate: true, onUpdate: false },
    ],
    indexes: [
      `CREATE UNIQUE INDEX idx_${name}_uuid ON ${name} (user, uuid)`,
      `CREATE UNIQUE INDEX idx_${name}_seq ON ${name} (user, seq)`,
    ],
  });

migrate(
  (app) => {
    const users = app.findCollectionByNameOrId("users");
    users.authRule = "verified = true";
    users.listRule = "id = @request.auth.id";
    users.viewRule = "id = @request.auth.id";
    users.createRule = "";
    users.updateRule = "id = @request.auth.id";
    users.deleteRule = "id = @request.auth.id";
    users.manageRule = null;
    users.passwordAuth.enabled = true;
    users.passwordAuth.identityFields = ["email"];
    users.oauth2.enabled = false;
    users.otp.enabled = false;
    users.mfa.enabled = false;
    app.save(users);

    const settings = app.settings();
    settings.meta.appName = "Grey Mushaf";
    settings.meta.appURL = "https://mushaf.ahmadjz.tech";
    settings.rateLimits.enabled = true;
    settings.rateLimits.rules = [
      ...settings.rateLimits.rules,
      ...["word_actions", "mark_actions", "bookmark_actions"].map((name) => ({
        label: `${name}:create`,
        maxRequests: 300,
        duration: 10,
        audience: "@auth",
      })),
    ];
    settings.batch.enabled = false;
    app.save(settings);

    app.save(
      actionCollection(
        users,
        "word_actions",
        [
          {
            name: "word",
            type: "text",
            required: true,
            pattern: "^qul-v4-hafs:\\d{1,3}:\\d{1,3}:\\d{1,3}$",
          },
          { name: "black", type: "bool" },
          { name: "counted", type: "bool" },
        ],
        "@request.body.counted = false || @request.body.black = true",
      ),
    );
    app.save(
      actionCollection(
        users,
        "mark_actions",
        [
          {
            name: "word",
            type: "text",
            required: true,
            pattern: "^qul-v4-hafs:\\d{1,3}:\\d{1,3}:\\d{1,3}$",
          },
          {
            name: "kind",
            type: "select",
            required: true,
            maxSelect: 1,
            values: ["line", "shape"],
          },
          {
            name: "style",
            type: "select",
            maxSelect: 1,
            values: ["singleLine", "doubleLine", "rectangle", "circle"],
          },
          {
            name: "color",
            type: "select",
            maxSelect: 1,
            values: ["red", "blue", "green", "orange", "purple", "black"],
          },
        ],
        '(@request.body.style = "" && @request.body.color = "") || (@request.body.color != "" && ((@request.body.kind = "line" && (@request.body.style = "singleLine" || @request.body.style = "doubleLine")) || (@request.body.kind = "shape" && (@request.body.style = "rectangle" || @request.body.style = "circle"))))',
      ),
    );
    app.save(
      actionCollection(
        users,
        "bookmark_actions",
        [
          {
            name: "page",
            type: "number",
            required: true,
            onlyInt: true,
            min: 1,
            max: 604,
          },
          { name: "saved", type: "bool" },
        ],
      ),
    );
  },
  (app) => {
    for (const name of ["bookmark_actions", "mark_actions", "word_actions"]) {
      app.delete(app.findCollectionByNameOrId(name));
    }
  },
);
