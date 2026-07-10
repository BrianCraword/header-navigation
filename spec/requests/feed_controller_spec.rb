# frozen_string_literal: true

require "rails_helper"

# Gate V1 in executable form: compose creates a titled topic the member
# never titled; the stream returns it creation-ordered with like state;
# gating and pagination hold. Run inside a dev container:
#   bundle exec rspec plugins/discourse-vc-feed/spec
RSpec.describe DiscourseVcFeed::FeedController do
  fab!(:category)
  fab!(:user) { Fabricate(:user, trust_level: 1, refresh_auto_groups: true) }
  fab!(:reader) { Fabricate(:user, trust_level: 0, refresh_auto_groups: true) }

  before do
    SiteSetting.vc_feed_enabled = true
    SiteSetting.vc_feed_categories = category.id.to_s
    SiteSetting.vc_feed_post_allowed_groups = Group::AUTO_GROUPS[:trust_level_1].to_s
    SiteSetting.tagging_enabled = true
  end

  describe "#create" do
    it "creates a micropost with a generated title (ADR-F4)" do
      sign_in(user)

      post "/vc-feed/posts.json",
           params: { raw: "The steadfast love of the LORD never ceases; his mercies never come to an end." }

      expect(response.status).to eq(200)
      body = response.parsed_body
      expect(body["is_micropost"]).to eq(true)

      topic = Topic.find(body["topic_id"])
      expect(topic.category_id).to eq(category.id)
      expect(topic.title).to be_present
      expect(topic.title.length).to be <= SiteSetting.max_topic_title_length
      expect(topic.custom_fields[DiscourseVcFeed::MICROPOST_FIELD]).to eq(true)
    end

    it "rescues too-short bodies with the author/timestamp suffix" do
      sign_in(user)
      post "/vc-feed/posts.json", params: { raw: "Amen! This is a wonderful testimony." }
      expect(response.status).to eq(200)
      expect(Topic.find(response.parsed_body["topic_id"]).title).to be_present
    end

    it "denies members outside vc_feed_post_allowed_groups" do
      sign_in(reader) # TL0 — reads the wall, cannot write it
      post "/vc-feed/posts.json", params: { raw: "should not land" }
      expect(response.status).to eq(403)
    end

    it "denies anonymous" do
      post "/vc-feed/posts.json", params: { raw: "should not land" }
      expect(response.status).to eq(403)
    end
  end

  describe "#stream" do
    fab!(:topics) do
      Array.new(3) { |i| Fabricate(:topic_with_op, category: category, created_at: (3 - i).hours.ago) }
    end

    it "returns items newest-first with first-post bodies and like state" do
      sign_in(user)
      get "/vc-feed/stream.json"

      expect(response.status).to eq(200)
      items = response.parsed_body["items"]
      expect(items.length).to eq(3)
      expect(items.map { |i| i["topic_id"] }).to eq(topics.reverse.map(&:id))
      expect(items.first).to include("cooked", "liked", "like_count", "user")
    end

    it "paginates by keyset via ?before=" do
      get "/vc-feed/stream.json", params: { before: topics.last.id }
      ids = response.parsed_body["items"].map { |i| i["topic_id"] }
      expect(ids).to eq([topics[1].id, topics[0].id])
    end

    it "returns an empty wall, not an error, when unconfigured" do
      SiteSetting.vc_feed_categories = ""
      get "/vc-feed/stream.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq("items" => [], "has_more" => false)
    end
  end
end
