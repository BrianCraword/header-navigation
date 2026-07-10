import { apiInitializer } from "discourse/lib/api";

// ── Core composer, wall manners (v0.7.0) ─────────────────────────────
//
// The wall composes through Discourse's REAL composer — drafts, GIFs,
// Ask AI, uploads, fullscreen, preview, every inherent feature — and
// keeps its title-less identity through the OFFICIAL transformer for
// exactly this: "composer-service-cannot-submit-post". When composing a
// new topic into a wall category with an empty title, we (a) generate
// the title from the first line of the body (ADR-F4, client edition)
// and (b) let the submit proceed. The title field itself is hidden by
// CSS scoped to a body class we toggle on composer open/close.

function feedCategoryIds(siteSettings) {
  return (siteSettings.vc_feed_categories || "")
    .split("|")
    .map((v) => parseInt(v, 10))
    .filter(Boolean);
}

function deriveTitle(raw, maxLength) {
  let text = (raw || "").slice(0, 400);
  text = text.replace(/```[\s\S]*?```/g, " ");
  text = text.replace(/!\[[^\]]*\]\([^)]*\)/g, " ");
  text = text.replace(/\[([^\]]*)\]\([^)]*\)/g, "$1");
  text = text.replace(/[#>*_`~|-]+/g, " ");
  text = text.replace(/\s+/g, " ").trim();
  if (!text) {
    return null;
  }
  const limit = Math.max(20, maxLength || 50);
  if (text.length <= limit) {
    return text;
  }
  const cut = text.slice(0, limit);
  return `${cut.slice(0, cut.lastIndexOf(" ") > 20 ? cut.lastIndexOf(" ") : limit)}…`;
}

export default apiInitializer((api) => {
  const siteSettings = api.container.lookup("service:site-settings");
  if (!siteSettings.vc_feed_enabled) {
    return;
  }

  const isWallCompose = (model) =>
    model &&
    model.creatingTopic &&
    feedCategoryIds(siteSettings).includes(model.categoryId);

  // Title-less submit for wall categories: derive and set the title at
  // the validation gate, then re-answer "cannot submit?" ourselves.
  api.registerValueTransformer(
    "composer-service-cannot-submit-post",
    ({ value, context }) => {
      const model = context?.model ?? context?.post ?? context;
      if (!isWallCompose(model)) {
        return value;
      }
      const raw = model.reply || "";
      if (raw.trim().length < (siteSettings.min_first_post_length || 1)) {
        return true; // body too short — core message applies
      }
      if (!model.title || model.title.trim().length === 0) {
        const title = deriveTitle(raw, siteSettings.vc_feed_title_length);
        if (title) {
          model.set(
            "title",
            title.length >= siteSettings.min_topic_title_length
              ? title
              : `${title} · ${new Date().toLocaleString(undefined, {
                  month: "short",
                  day: "numeric",
                  hour: "numeric",
                  minute: "2-digit",
                })}`
          );
        }
      }
      return !model.title; // submittable once a title exists
    }
  );

  // Body class while composing to the wall → CSS hides the title/tags
  // row of the core composer (fields stay in the DOM; nothing is
  // removed from core, ADR-F1).
  const appEvents = api.container.lookup("service:app-events");
  const sync = () => {
    const model = api.container.lookup("service:composer")?.model;
    document.body.classList.toggle("vc-feed-composing", isWallCompose(model));
  };
  appEvents.on("composer:opened", sync);
  appEvents.on("composer:will-open", sync);
  appEvents.on("composer:closed", () =>
    document.body.classList.remove("vc-feed-composing")
  );
});
