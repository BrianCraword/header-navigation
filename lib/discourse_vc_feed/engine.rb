# frozen_string_literal: true

module ::DiscourseVcFeed
  class Engine < ::Rails::Engine
    engine_name DiscourseVcFeed::PLUGIN_NAME
    isolate_namespace DiscourseVcFeed
  end
end

Discourse::Application.routes.append do
  mount ::DiscourseVcFeed::Engine, at: "/vc-feed"

  # Full-page loads of the wall. Ember owns /feed client-side, but the URL
  # bar, shared links, and bookmarks hit Rails first — this tells Rails to
  # serve the app shell so the client route can take over. Same pattern as
  # core chat (`get "/" => "chat#respond"`). Without it: 404 on direct
  # entry, while in-app navigation works — the trap trivia/campaign
  # currently sit in.
  get "/feed" => "discourse_vc_feed/feed#respond"
end
