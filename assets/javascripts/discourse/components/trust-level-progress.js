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
}
