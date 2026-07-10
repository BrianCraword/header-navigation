import { ajax } from "discourse/lib/ajax";

// ── Card protocol v1 client (§5) ──────────────────────────────────────
//
// Fetches every registered card endpoint in parallel with graceful
// absence (ADR-F3): a plugin that is disabled, erroring, or not yet
// carrying the endpoint contributes NOTHING — never an error on the
// wall. Registry is a plain list; Phase 5 may move it to a site setting.
const CARD_ENDPOINTS = [
  "/scripture-campaign/feed-cards.json",
  "/trivia/feed-cards.json",
];

const DISMISS_PREFIX = "vc-feed-dismissed:";

function dismissKey(card) {
  // `daily` cards re-earn attention each day; `once`/`per_event` cards
  // are silenced by id (per_event ids change per event by contract, so
  // dismissal naturally resets when the program moves forward).
  const day =
    card.frequency === "daily" ? `:${new Date().toISOString().slice(0, 10)}` : "";
  return `${DISMISS_PREFIX}${card.id}${day}`;
}

export function isDismissed(card) {
  try {
    return !!localStorage.getItem(dismissKey(card));
  } catch {
    return false;
  }
}

export function dismissCard(card) {
  try {
    localStorage.setItem(dismissKey(card), "1");
  } catch {
    // Private-mode storage failure: the card simply returns next load.
  }
}

function valid(card) {
  return card && card.id && card.type && card.ts;
}

function expired(card) {
  return card.expires_at && new Date(card.expires_at) <= new Date();
}

export async function fetchFeedCards() {
  const results = await Promise.allSettled(
    CARD_ENDPOINTS.map((url) => ajax(url))
  );

  const now = Date.now();
  const cards = [];

  for (const r of results) {
    if (r.status !== "fulfilled" || !Array.isArray(r.value?.cards)) {
      continue; // absent program, absent card — no residue (ADR-F3)
    }
    for (const card of r.value.cards) {
      if (!valid(card) || expired(card) || isDismissed(card)) {
        continue;
      }
      // A future ts (e.g., a scheduled event) would float above every
      // member post forever; clamp so sorting stays honest.
      card._ts = Math.min(new Date(card.ts).getTime(), now);
      cards.push(card);
    }
  }

  return cards.sort((a, b) => b._ts - a._ts);
}
