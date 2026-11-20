/// <reference path="../pb_data/types.d.ts" />
// seq is the pull cursor: assigned inside the create's write, so it only grows in commit order.
onRecordCreate(
  (e) => {
    const record = e.record;
    const now = Date.now();
    if (record.getInt("created_at") > now) record.set("created_at", now);
    const row = new DynamicModel({ last: 0 });
    e.app
      .db()
      .newQuery(
        `SELECT COALESCE(MAX(seq), 0) AS last FROM ${record.collection().name} WHERE user = {:user}`,
      )
      .bind({ user: record.getString("user") })
      .one(row);
    record.set("seq", row.last + 1);
    e.next();
  },
  "word_actions",
  "mark_actions",
  "bookmark_actions",
);
