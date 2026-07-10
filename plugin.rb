# frozen_string_literal: true

# name: discourse-vc-feed
# about: The wall at the heart of Victorious Christians — title-less microposting into a stream that unifies member posts and program cards. New surfaces over core data, never modification of core surfaces (ADR-F1).
# version: 0.8.0
# authors: Brian Crawford
# url: https://github.com/BrianCraword/discourse-vc-feed
# required_version: 2.7.0

enabled_site_setting :vc_feed_enabled

register_asset "stylesheets/vc-feed.scss"

module ::DiscourseVcFeed
  PLUGIN_NAME = "discourse-vc-feed"

  # Topic custom field marking a topic as born on the wall. The stream
  # shows every topic in vc_feed_categories (the wall is the UNION —
  # §12.1 of PROJECT-INSTRUCTIONS), but renderers use this flag to pick
  # the micropost card treatment vs. the titled-post card treatment.
  MICROPOST_FIELD = "vc_feed_micropost"

  def self.feed_category_ids
    SiteSetting.vc_feed_categories.to_s.split("|").map(&:to_i).reject(&:zero?)
  end

  # Compose target = FIRST entry of the list (documented in settings.yml).
  def self.compose_category_id
    feed_category_ids.first
  end

  def self.can_post?(user)
    return false if user.blank?
    user.in_any_groups?(SiteSetting.vc_feed_post_allowed_groups_map)
  end
end

require_relative "lib/discourse_vc_feed/engine"

after_initialize do
  require_relative "lib/discourse_vc_feed/title_generator"

  # Register the micropost marker so it serializes and survives.
  register_topic_custom_field_type(DiscourseVcFeed::MICROPOST_FIELD, :boolean)

  # ── Serializer additions (§6.3, Tier 1) ──────────────────────────────
  # Only the marker rides on core serializers in Phase 1; the stream has
  # its own serializer with full bodies. Repost fields arrive in Phase 3
  # as ADDITIVE fields (ADR-F2).
  add_to_serializer(
    :topic_view,
    :is_micropost,
    include_condition: -> { SiteSetting.vc_feed_enabled },
  ) { object.topic.custom_fields[DiscourseVcFeed::MICROPOST_FIELD] == true }

  # Preload the field for topic lists so no N+1 when core lists render
  # feed topics (e.g., the category page still works as a normal forum).
  TopicList.preloaded_custom_fields << DiscourseVcFeed::MICROPOST_FIELD

  add_to_serializer(
    :topic_list_item,
    :is_micropost,
    include_condition: -> { SiteSetting.vc_feed_enabled },
  ) { object.custom_fields[DiscourseVcFeed::MICROPOST_FIELD] == true }

  # The composer renders only for members who may write the wall; the
  # server re-checks on every POST (client hint, server law).
  add_to_serializer(
    :current_user,
    :can_vc_feed_post,
    include_condition: -> { SiteSetting.vc_feed_enabled },
  ) { DiscourseVcFeed.can_post?(object) }

  # ── Live inserts (§6.5, Tier 1) ──────────────────────────────────────
  # Publish on every new wall topic so the theme's "new posts" pill can
  # listen on one channel. Payload is intentionally tiny: the theme
  # refetches /vc-feed/stream.json rather than trusting a pushed body
  # (single source of truth, and MessageBus stays cheap).
  on(:topic_created) do |topic, _opts, _user|
    next unless SiteSetting.vc_feed_enabled
    next unless DiscourseVcFeed.feed_category_ids.include?(topic.category_id)

    MessageBus.publish(
      "/vc-feed/stream",
      { topic_id: topic.id, created_at: topic.created_at.iso8601 },
    )
  end
end
