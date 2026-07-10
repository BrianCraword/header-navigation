# frozen_string_literal: true

module DiscourseVcFeed
  # ── TitleGenerator — ADR-F4 made concrete ────────────────────────────
  #
  # Core requires a title; the wall never asks for one. We generate a
  # title that (a) satisfies min/max length validation, (b) reads well in
  # every core surface that still shows titles (search results, email
  # digests, the category's classic topic list, /latest), and (c) never
  # collides into a "title has already been used" rejection the member
  # could not possibly understand.
  #
  # Strategy: first meaningful line of the body → strip markup → squish →
  # truncate on a word boundary → pad or suffix as needed. The suffix
  # (" · Jul 9, 2:14 PM") both rescues too-short bodies ("Amen!") and
  # de-duplicates repeated short posts — a wall WILL see many identical
  # exclamations, and each deserves its own topic.
  module TitleGenerator
    MAX_SOURCE_CHARS = 400

    def self.call(raw, user:)
      base = extract(raw)
      min = SiteSetting.min_topic_title_length
      max = SiteSetting.max_topic_title_length

      title = base.truncate(limit(max), separator: " ", omission: "…")

      # Short or empty body → anchor with author + timestamp. Also applied
      # when the trimmed body duplicates an existing recent title, so
      # SiteSetting.allow_duplicate_topic_titles can stay OFF site-wide.
      if title.length < min || duplicate?(title)
        title = with_suffix(title, user, max)
      end

      title
    end

    def self.extract(raw)
      text = raw.to_s[0, MAX_SOURCE_CHARS]
      text = text.gsub(/```.*?```/m, " ")            # fenced code
      text = text.gsub(/!\[[^\]]*\]\([^)]*\)/, " ")  # images
      text = text.gsub(/\[([^\]]*)\]\([^)]*\)/, '\1') # links → label
      text = text.gsub(/[#>*_`~\-]{1,}/, " ")        # md furniture
      text = ActionView::Base.full_sanitizer.sanitize(text)
      text.squish
    end

    def self.with_suffix(title, user, max)
      stamp = Time.zone.now.strftime("%b %-d, %-l:%M %p")
      head = title.presence || I18n.t("vc_feed.default_title", username: user.username)
      "#{head} · #{stamp}".truncate(limit(max), separator: " ", omission: "…")
    end

    def self.duplicate?(title)
      return false if SiteSetting.allow_duplicate_topic_titles
      Topic.listable_topics.where(title: title).where("created_at > ?", 30.days.ago).exists?
    end

    # Budget = the smaller of our display preference (vc_feed_title_length)
    # and core's hard ceiling (max_topic_title_length) — but never below 20,
    # or suffixing becomes impossible.
    def self.limit(max)
      [[SiteSetting.vc_feed_title_length.to_i, max.to_i].reject(&:zero?).min, 20].max
    end
  end
end
