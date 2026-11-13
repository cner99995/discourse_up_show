import { withPluginApi } from "discourse/lib/plugin-api";
import TrustLevelProgress from "discourse/plugins/discourse-trust-level-progress/discourse/components/trust-level-progress";

export default {
  name: "trust-level-progress",

  initialize() {
    withPluginApi("1.0", (api) => {
      if (typeof api.renderInOutlet === "function") {
        api.renderInOutlet("above-user-summary-stats", TrustLevelProgress);
      }
    });
  },
};
