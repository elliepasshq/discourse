import { withPluginApi } from "discourse/lib/plugin-api";
import ElliepassConnectionStatus from "../components/elliepass-connection-status";
import ElliepassSettingsSetup from "../components/elliepass-settings-setup";

const PLUGIN_ID = "elliepass";

export default {
  name: "elliepass-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.renderBeforeWrapperOutlet(
        "admin-config-area-filtered-site-settings",
        ElliepassSettingsSetup
      );

      api.renderAfterWrapperOutlet(
        "admin-config-area-filtered-site-settings",
        ElliepassConnectionStatus
      );
    });
  },
};
