import { test } from "node:test";
import assert from "node:assert/strict";
import { resolveBadge } from "../javascripts/discourse/lib/je-nav-core.js";
const row = { badge_source: "messages_unread" };
const site = { notification_types: { private_message: 73 } };
function user(count, newer = 0) {
  const value = { grouped_unread_notifications: { 73: count, 74: 19 }, new_personal_messages_notifications_count: newer, unread_high_priority_notifications: 12 };
  value.get = function (key) { return key.split('.').reduce((v, p) => v?.[p], this); };
  return value;
}
test('Messages matches native unread type even when new, Chat and other notification counts differ', () => {
  assert.equal(resolveBadge(row, user(3, 0), site), '3');
  assert.equal(resolveBadge(row, user(0, 9), site), null);
  assert.equal(resolveBadge(row, user(1, 9), site), '1');
  assert.equal(resolveBadge(row, user(125), site), '99+');
});
test('reactive reads follow arrivals and clearing rather than a cached count', () => {
  const member = user(0); const reads = []; const original = member.get;
  member.get = function (key) { reads.push(key); return original.call(this, key); };
  assert.equal(resolveBadge(row, member, site), null);
  member.grouped_unread_notifications = { 73: 2 };
  assert.equal(resolveBadge(row, member, site), '2');
  member.grouped_unread_notifications = { 73: 0 };
  assert.equal(resolveBadge(row, member, site), null);
  assert.equal(reads.filter(key => key === 'grouped_unread_notifications.73').length, 3);
});
test('native legacy fallback, missing capability and configured static labels are preserved', () => {
  const member = user(0); member.grouped_unread_high_priority_notifications = { 73: 4 };
  assert.equal(resolveBadge(row, member, site), '4');
  assert.equal(resolveBadge(row, member, {}), null);
  assert.equal(resolveBadge(row, null, site), null);
  assert.equal(resolveBadge({...row, badge:'NEW'}, user(0), site), 'NEW');
  assert.equal(resolveBadge({badge_source:'static', badge:'LIVE'}, member, site), 'LIVE');
});
test('notification and matchmaking badge sources keep their existing semantics', () => {
  const member = user(5);
  assert.equal(resolveBadge({badge_source:'notifications_unread'}, member, site), '12');
  assert.equal(resolveBadge({badge_source:'unknown', badge:'custom'}, member, site), 'custom');
});
