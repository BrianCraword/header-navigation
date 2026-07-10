import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { getOwner } from "@ember/owner";
import avatar from "discourse/helpers/avatar";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

// ── The modules rail (§4 dispositions, first four residents) ─────────
//
// Every module obeys graceful absence (ADR-F3): a disabled plugin, an
// erroring endpoint, or an empty answer renders NOTHING — never an
// error, never a placeholder. Campaign and trivia ride the SAME
// plaza-summary endpoints Canvas has run in production — proven
// contracts, new skin. Who's-online rides the whos-online plugin's own
// service exactly as the Canvas block does.
export default class VcFeedRail extends Component {
  @tracked campaign = null;
  @tracked trivia = null;
  @tracked latest = [];
  @tracked topMembers = [];
  @tracked tags = [];
  @tracked hot = [];
  @tracked stats = null;

  constructor() {
    super(...arguments);
    this.load();
  }

  // Optional service: hard-injecting a service from an absent plugin
  // throws at lookup, so we resolve it softly.
  get whosOnline() {
    return getOwner(this).lookup("service:whos-online");
  }

  get onlineUsers() {
    if (!this.whosOnline?.enabled) {
      return [];
    }
    return (this.whosOnline.users || []).slice(0, 10);
  }

  get onlineOverflow() {
    const extra = (this.whosOnline?.count || 0) - this.onlineUsers.length;
    return extra > 0 ? extra : 0;
  }

  async load() {
    const [campaign, trivia, latest, directory, tags, top, about] =
      await Promise.allSettled([
        ajax("/scripture-campaign/plaza-summary.json"),
        ajax("/trivia/plaza-summary.json"),
        ajax("/latest.json"),
        ajax("/directory_items.json", {
          data: { period: "weekly", order: "likes_received" },
        }),
        ajax("/tags.json"),
        ajax("/top.json", { data: { period: "weekly" } }),
        ajax("/about.json"),
      ]);

    if (campaign.status === "fulfilled" && campaign.value?.active) {
      this.campaign = campaign.value;
    }
    if (trivia.status === "fulfilled" && trivia.value?.active !== false) {
      this.trivia = trivia.value;
    }
    if (latest.status === "fulfilled") {
      this.latest = (latest.value?.topic_list?.topics || []).slice(0, 5);
    }
    if (directory.status === "fulfilled") {
      this.topMembers = (directory.value?.directory_items || [])
        .filter((d) => (d.likes_received || 0) > 0)
        .slice(0, 5);
    }
    if (top.status === "fulfilled") {
      this.hot = (top.value?.topic_list?.topics || []).slice(0, 5);
    }
    if (about.status === "fulfilled") {
      this.stats = about.value?.about?.stats || null;
    }
    if (tags.status === "fulfilled") {
      this.tags = (tags.value?.tags || [])
        .filter((t) => (t.count || 0) > 0)
        .sort((a, b) => (b.count || 0) - (a.count || 0))
        .slice(0, 8);
    }
  }

  get lightPercent() {
    const level = this.campaign?.light_level;
    if (level == null) {
      return null;
    }
    return Math.max(0, Math.min(100, level));
  }

  <template>
    <aside class="vc-feed-rail">
      {{#if this.campaign}}
        <section class="vc-rail-module vc-rail-module--campaign">
          <h3 class="vc-rail-module__title">{{i18n "vc_feed.rail.campaign"}}</h3>
          <div class="vc-rail-module__headline">{{this.campaign.season_title}}</div>
          <div class="vc-rail-module__line">
            {{i18n
              "vc_feed.cards.campaign_open"
              walked=this.campaign.scenes_walked
              count=this.campaign.scene_count
            }}
          </div>
          {{#if this.lightPercent}}
            <div class="vc-feed-program-card__meter">
              <div
                class="vc-feed-program-card__meter-fill"
                style="width: {{this.lightPercent}}%"
              ></div>
            </div>
          {{/if}}
          <a class="vc-rail-module__link" href="/scripture-campaign">
            {{i18n "vc_feed.rail.campaign_link"}}
          </a>
        </section>
      {{/if}}

      {{#if this.trivia}}
        <section class="vc-rail-module vc-rail-module--trivia">
          <h3 class="vc-rail-module__title">{{i18n "vc_feed.rail.trivia"}}</h3>
          {{#if this.trivia.community}}
            <div class="vc-rail-module__line">
              {{i18n
                "vc_feed.rail.trivia_community"
                count=this.trivia.community.correct_answers
              }}
            </div>
          {{/if}}
          <a class="vc-rail-module__link" href="/trivia">
            {{i18n "vc_feed.rail.trivia_link"}}
          </a>
        </section>
      {{/if}}

      {{#if this.onlineUsers.length}}
        <section class="vc-rail-module vc-rail-module--online">
          <h3 class="vc-rail-module__title">{{i18n "vc_feed.rail.online"}}</h3>
          <div class="vc-rail-module__avatars">
            {{#each this.onlineUsers as |user|}}
              <a href="/u/{{user.username}}" title={{user.username}}>
                {{avatar user imageSize="small"}}
              </a>
            {{/each}}
            {{#if this.onlineOverflow}}
              <span class="vc-rail-module__overflow">+{{this.onlineOverflow}}</span>
            {{/if}}
          </div>
        </section>
      {{/if}}

      {{#if this.topMembers.length}}
        <section class="vc-rail-module vc-rail-module--top">
          <h3 class="vc-rail-module__title">{{i18n "vc_feed.rail.top_week"}}</h3>
          {{#each this.topMembers as |item|}}
            <a class="vc-rail-module__member" href="/u/{{item.user.username}}">
              {{avatar item.user imageSize="small"}}
              <span class="vc-rail-module__member-name">
                {{if item.user.name item.user.name item.user.username}}
              </span>
              <span class="vc-rail-module__member-count">
                {{icon "heart"}} {{item.likes_received}}
              </span>
            </a>
          {{/each}}
        </section>
      {{/if}}

      {{#if this.tags.length}}
        <section class="vc-rail-module vc-rail-module--tags">
          <h3 class="vc-rail-module__title">{{i18n "vc_feed.rail.tags"}}</h3>
          <div class="vc-rail-module__tags">
            {{#each this.tags as |tag|}}
              <a class="vc-feed-item__tag" href="/tag/{{tag.id}}">#{{tag.id}}</a>
            {{/each}}
          </div>
        </section>
      {{/if}}

      {{#if this.hot.length}}
        <section class="vc-rail-module vc-rail-module--hot">
          <h3 class="vc-rail-module__title">{{i18n "vc_feed.rail.hot"}}</h3>
          {{#each this.hot as |topic|}}
            <a class="vc-rail-module__topic" href="/t/{{topic.slug}}/{{topic.id}}">
              {{topic.title}}
            </a>
          {{/each}}
        </section>
      {{/if}}

      {{#if this.latest.length}}
        <section class="vc-rail-module vc-rail-module--latest">
          <h3 class="vc-rail-module__title">{{i18n "vc_feed.rail.latest"}}</h3>
          {{#each this.latest as |topic|}}
            <a class="vc-rail-module__topic" href="/t/{{topic.slug}}/{{topic.id}}">
              {{topic.title}}
            </a>
          {{/each}}
        </section>
      {{/if}}
      {{#if this.stats}}
        <section class="vc-rail-module vc-rail-module--stats">
          <h3 class="vc-rail-module__title">{{i18n "vc_feed.rail.community"}}</h3>
          <div class="vc-rail-module__stats">
            <div class="vc-rail-module__stat">
              <span class="vc-rail-module__stat-num">{{this.stats.users_count}}</span>
              <span class="vc-rail-module__stat-label">{{i18n "vc_feed.rail.members"}}</span>
            </div>
            <div class="vc-rail-module__stat">
              <span class="vc-rail-module__stat-num">{{this.stats.posts_count}}</span>
              <span class="vc-rail-module__stat-label">{{i18n "vc_feed.rail.posts"}}</span>
            </div>
            <div class="vc-rail-module__stat">
              <span class="vc-rail-module__stat-num">{{this.stats.active_users_7_days}}</span>
              <span class="vc-rail-module__stat-label">{{i18n "vc_feed.rail.active"}}</span>
            </div>
          </div>
        </section>
      {{/if}}
    </aside>
  </template>
}
