import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";

export default class TrustLevelProgress extends Component {
  @service currentUser;
  @service router;

  @tracked data = null;
  @tracked loading = false;
  @tracked failed = false;

  constructor(owner, args) {
    super(owner, args);

    // `router.currentURL` can still point at the previous route while the
    // component is constructed, so when the outlet gives us no user we cannot
    // tell whose profile this is yet. In that case fetch anyway; the endpoint
    // only ever returns data for the signed-in user.
    const hasOutletUser = Boolean(this.args?.outletArgs?.user);

    if (this.currentUser?.username && (this.ownsProfile || !hasOutletUser)) {
      this.load();
    }
  }

  // The endpoint only ever returns data for the current user, so this card is
  // rendered on the signed-in user's own summary page only.
  get ownsProfile() {
    const username = this.currentUser?.username;

    if (!username) {
      return false;
    }

    const outletUser = this.args?.outletArgs?.user || this.args?.user;

    if (outletUser?.username) {
      return outletUser.username.toLowerCase() === username.toLowerCase();
    }

    const url = (this.router.currentURL || "").toLowerCase();
    const escaped = username.toLowerCase().replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

    return new RegExp(`^/u/${escaped}([/?#]|$)`).test(url);
  }

  get items() {
    return (this.data?.items || []).map((item) => ({
      ...item,
      rowClass: item.met ? "tlp-item is-met" : "tlp-item",
    }));
  }

  async load() {
    this.loading = true;
    this.failed = false;

    try {
      this.data = await ajax("/trust-level-progress.json");
    } catch {
      this.failed = true;
    } finally {
      this.loading = false;
    }
  }

  <template>
    {{#if this.ownsProfile}}
      <section class="tlp-card">
        {{#if this.loading}}
          <div class="tlp-skeleton">
            <span></span>
            <span></span>
            <span></span>
          </div>
        {{else if this.failed}}
          <div class="tlp-message tlp-message--danger">
            {{i18n "trust_level_progress.load_failed"}}
          </div>
        {{else if this.data}}
          <div class="tlp-header">
            <h3 class="tlp-title">{{this.data.title}}</h3>
            <span class="tlp-badge tlp-badge--{{this.data.summary_state}}">{{this.data.summary}}</span>
          </div>

          {{#each this.data.alerts as |alert|}}
            <div class="tlp-message tlp-message--{{alert.level}}">{{alert.text}}</div>
          {{/each}}

          <p class="tlp-subtitle">{{this.data.subtitle}}</p>

          <ul class="tlp-items">
            {{#each this.items as |item|}}
              <li class={{item.rowClass}}>
                <div class="tlp-item-row">
                  <span class="tlp-item-label">{{item.label}}</span>
                  <span class="tlp-item-values">
                    {{item.value_text}}
                    <span class="tlp-sep">/</span>
                    {{item.required_text}}
                  </span>
                </div>
                <progress class="tlp-progress" value={{item.percent}} max="100"></progress>
                {{#if item.hint}}
                  <span class="tlp-hint">{{item.hint}}</span>
                {{/if}}
              </li>
            {{/each}}
          </ul>

          <p class="tlp-footnote">{{this.data.footnote}}</p>
        {{/if}}
      </section>
    {{/if}}
  </template>
}
