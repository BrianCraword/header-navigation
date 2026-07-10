# frozen_string_literal: true

DiscourseVcFeed::Engine.routes.draw do
  # ── Phase 1: the two verbs (Gate V1 surface) ─────────────────────────
  # Verifiable after deploy:
  #   GET /vc-feed/stream.json returns { items: [], has_more: false }
  #   on a fresh install with an empty feed category.
  post "/posts"  => "feed#create"
  get  "/stream" => "feed#stream"

  # ── Phase 3 (reserved, not yet implemented): the repost verb ────────
  # put    "/reposts/:topic_id" => "reposts#create"
  # delete "/reposts/:topic_id" => "reposts#destroy"
end
