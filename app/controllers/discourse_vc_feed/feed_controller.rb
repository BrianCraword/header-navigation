# frozen_string_literal: true

module DiscourseVcFeed
  # ── FeedController — the wall's two verbs: write and read ─────────────
  #
  # POST /vc-feed/posts  — title-less compose. Wraps PostCreator so EVERY
  #   core defense rides along untouched: rate limits, watched words,
  #   min-post-length, silenced/suspended checks, plugin validators,
  #   akismet-style hooks. We add exactly one thing — a generated title
  #   (ADR-F4: generate what core requires; never remove the requirement).
  #
  # GET /vc-feed/stream.json — the wall. UNION of vc_feed_categories,
  #   creation-ordered (a wall is a timeline, not a bump list), keyset
  #   paginated, first-post bodies included so cards render without a
  #   second round trip.
  class FeedController < ::ApplicationController
    requires_plugin DiscourseVcFeed::PLUGIN_NAME

    before_action :ensure_logged_in, only: [:create]
    before_action :ensure_can_post, only: [:create]

    PAGE_SIZE = 20

    # Serves the Ember app shell for full-page loads of /feed. For HTML
    # requests, ApplicationController#check_xhr intercepts and renders the
    # bootstrap before this body even runs — `render` is the no-op that
    # lets that mechanism work (verbatim core chat pattern).
    def respond
      render
    end

    def create
      raw = params.require(:raw).to_s.strip
      category_id = DiscourseVcFeed.compose_category_id

      if category_id.blank?
        return render_json_error(
          I18n.t("vc_feed.errors.no_category"), status: 422
        )
      end

      title = DiscourseVcFeed::TitleGenerator.call(raw, user: current_user)

      creator =
        PostCreator.new(
          current_user,
          title: title,
          raw: raw,
          category: category_id,
          archetype: Archetype.default,
          # The wall composer has no title field, so a title-similarity
          # rejection would be unexplainable to the member. Titles are
          # machine-generated and de-duplicated by TitleGenerator instead.
          skip_validations: false,
        )

      post = creator.create

      if creator.errors.present?
        return render_json_error(creator.errors.full_messages.join(", "), status: 422)
      end

      topic = post.topic
      topic.custom_fields[DiscourseVcFeed::MICROPOST_FIELD] = true
      topic.save_custom_fields(true)

      render json: serialized_item(topic, post, liked_ids: [])
    end

    def stream
      category_ids = DiscourseVcFeed.feed_category_ids
      return render json: { items: [], has_more: false } if category_ids.empty?

      guardian = Guardian.new(current_user)
      visible_ids =
        category_ids.select { |id| guardian.can_see_category?(Category.find_by(id: id)) }
      return render json: { items: [], has_more: false } if visible_ids.empty?

      topics =
        Topic
          .visible
          .listable_topics
          .where(category_id: visible_ids)
          .where(archetype: Archetype.default)
          .includes(:user, :tags, :category)
          .order(created_at: :desc, id: :desc)

      # Keyset pagination: ?before=<topic_id>. Stable under inserts at the
      # head (offset pagination would duplicate items as new posts land —
      # the exact failure X-style infinite scroll must not have).
      if params[:before].present?
        pivot = Topic.find_by(id: params[:before].to_i)
        if pivot
          topics =
            topics.where(
              "(topics.created_at, topics.id) < (?, ?)",
              pivot.created_at,
              pivot.id,
            )
        end
      end

      page = topics.limit(PAGE_SIZE + 1).to_a
      has_more = page.size > PAGE_SIZE
      page = page.first(PAGE_SIZE)

      first_posts =
        Post
          .where(topic_id: page.map(&:id), post_number: 1)
          .index_by(&:topic_id)

      # One query answers "which of these has the current user liked" —
      # the inline heart must render correctly on first paint (ADR-F5).
      liked_ids =
        if current_user
          PostAction
            .where(
              user_id: current_user.id,
              post_id: first_posts.values.map(&:id),
              post_action_type_id: PostActionType.types[:like],
              deleted_at: nil,
            )
            .pluck(:post_id)
        else
          []
        end

      Topic.preload_custom_fields(page, [DiscourseVcFeed::MICROPOST_FIELD])

      items =
        page.filter_map do |topic|
          post = first_posts[topic.id]
          next if post.blank?
          serialized_item(topic, post, liked_ids: liked_ids)
        end

      render json: { items: items, has_more: has_more }
    end

    private

    def ensure_can_post
      raise Discourse::InvalidAccess.new unless DiscourseVcFeed.can_post?(current_user)
    end

    # One shape for both endpoints, so the theme's optimistic insert after
    # compose is byte-compatible with a stream item (no reconciliation
    # special cases). Contract discipline per ADR-F2: additive only from
    # here forward.
    def serialized_item(topic, post, liked_ids:)
      {
        topic_id: topic.id,
        post_id: post.id,
        is_micropost: topic.custom_fields[DiscourseVcFeed::MICROPOST_FIELD] == true,
        created_at: topic.created_at.iso8601,
        title: topic.title,
        cooked: post.cooked,
        category_id: topic.category_id,
        tags: topic.tags.map(&:name),
        user: {
          id: topic.user&.id,
          username: topic.user&.username,
          name: topic.user&.name,
          avatar_template: topic.user&.avatar_template,
        },
        like_count: post.like_count,
        liked: liked_ids.include?(post.id),
        reply_count: [topic.posts_count - 1, 0].max,
        views: topic.views,
        last_posted_at: topic.last_posted_at&.iso8601,
        url: topic.relative_url,
      }
    end
  end
end
