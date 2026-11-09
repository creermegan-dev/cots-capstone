const test = require("node:test");
const assert = require("node:assert/strict");
const {pushData} = require("./index")._test;

test("push payload contains only string navigation data", () => {
  assert.deepEqual(pushData("notice-1", {
    type: "review_accepted",
    related_record_id: "capture-1",
    zone: "Zone A",
  }), {
    notification_id: "notice-1",
    type: "review_accepted",
    related_record_id: "capture-1",
    zone: "Zone A",
  });
});
