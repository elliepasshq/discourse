import { apiInitializer } from "discourse/lib/api";
import I18n from "I18n";

export default apiInitializer("1.8.0", (api) => {
    const showLocationResult = () => {
    const url = new URL(window.location.href);

    if (
      url.searchParams.get("elliepass_result") !==
      "location_failed"
    ) {
      return;
    }

    const reason =
      url.searchParams.get("elliepass_reason");

    url.searchParams.delete(
      "elliepass_result"
    );

    url.searchParams.delete(
      "elliepass_reason"
    );

    window.history.replaceState(
      {},
      "",
      url.pathname +
        url.search +
        url.hash
    );

    const isIdVerifiedLocationFailure =
      reason === "id_verified_location_required";

    let title;
    let message;

    if (isIdVerifiedLocationFailure) {
      title =
        I18n.t(
          "elliepass.verification_dialog.id_location_result_title"
        );

      message =
        I18n.t(
          "elliepass.verification_dialog.id_location_failed_message"
        );
    } else {
      title =
        I18n.t(
          "elliepass.verification_dialog.location_result_title"
        );

      message =
        I18n.t(
          "elliepass.verification_dialog.location_failed_message"
        );

      if (
        reason === "current_location_region_mismatch" ||
        reason === "current_location_country_mismatch"
      ) {
        message =
          I18n.t(
            "elliepass.verification_dialog.location_mismatch_message"
          );
      }
    }

    const dialogOptions = {
      title,
      message,

      cancelButtonLabel:
        "elliepass.verification_dialog.close",
    };

    if (!isIdVerifiedLocationFailure) {
      dialogOptions.confirmButtonLabel =
        "elliepass.verification_dialog.check_location";

      dialogOptions.didConfirm = () => {
        const returnTo =
          window.location.pathname +
          window.location.search +
          window.location.hash;

        window.location.href =
          `/elliepass/verify?return_to=${encodeURIComponent(
            returnTo
          )}`;
      };
    }

    api.container
      .lookup("service:dialog")
      .confirm(dialogOptions);
  };

  showLocationResult();

  api.addComposerSaveErrorCallback((error) => {
    const errorText = String(error || "");

    const messages = {
      checklist: I18n.t(
        "elliepass.posting.checklist"
      ),

      humanNeeded: I18n.t(
        "elliepass.posting.checklist_human_needed"
      ),

      humanMet: I18n.t(
        "elliepass.posting.checklist_human_met"
      ),

      identityNeeded: I18n.t(
        "elliepass.posting.checklist_identity_needed"
      ),

      identityMet: I18n.t(
        "elliepass.posting.checklist_identity_met"
      ),

      idLocationNeeded: I18n.t(
        "elliepass.posting.checklist_id_location_needed"
      ),

      idLocationMet: I18n.t(
        "elliepass.posting.checklist_id_location_met"
      ),

      idLocationBlocked: I18n.t(
        "elliepass.posting.checklist_id_location_blocked"
      ),

      currentLocationNeeded: I18n.t(
        "elliepass.posting.checklist_current_location_needed"
      ),

      currentLocationMet: I18n.t(
        "elliepass.posting.checklist_current_location_met"
      ),
    };

    if (!errorText.includes(messages.checklist)) {
      return;
    }

    const rows = [];

    if (errorText.includes(messages.humanNeeded)) {
      rows.push(
        "✕ Human verification — required"
      );
    } else if (errorText.includes(messages.humanMet)) {
      rows.push(
        "✓ Human verification — verified"
      );
    }

    if (errorText.includes(messages.identityNeeded)) {
      rows.push(
        "✕ Identity verification — required"
      );
    } else if (errorText.includes(messages.identityMet)) {
      rows.push(
        "✓ Identity verification — verified"
      );
    }

    const ageNeededMatch =
      errorText.match(
        /Age (\d+)\+ requires attention\./
      );

    const ageMetMatch =
      errorText.match(
        /Age (\d+)\+ requirement met\./
      );

    const ageBlockedMatch =
      errorText.match(
        /Age (\d+)\+ requirement not met\./
      );

    let hasHardFailure = false;

    if (ageBlockedMatch) {
      hasHardFailure = true;

      rows.push(
        `✕ Age ${ageBlockedMatch[1]}+ — requirement not met`
      );
    } else if (ageNeededMatch) {
      rows.push(
        `✕ Age ${ageNeededMatch[1]}+ — verification required`
      );
    } else if (ageMetMatch) {
      rows.push(
        `✓ Age ${ageMetMatch[1]}+ — verified`
      );
    }

    if (errorText.includes(messages.idLocationBlocked)) {
      hasHardFailure = true;

      rows.push(
        "✕ ID-verified location — requirement not met"
      );
    } else if (errorText.includes(messages.idLocationNeeded)) {
      rows.push(
        "✕ ID-verified location — required"
      );
    } else if (errorText.includes(messages.idLocationMet)) {
      rows.push(
        "✓ ID-verified location — verified"
      );
    }

    if (
      errorText.includes(
        messages.currentLocationNeeded
      )
    ) {
      rows.push(
        "✕ Current location — requires attention"
      );
    } else if (
      errorText.includes(
        messages.currentLocationMet
      )
    ) {
      rows.push(
        "✓ Current location — verified"
      );
    }

    const intro =
      "This community requires verification for this action. " +
      "ElliePass will securely check if you meet the requirements.";

    const message =
      intro +
      (rows.length > 0
        ? `<br><br>${rows.join("<br>")}`
        : "");

    const dialogService =
      api.container.lookup("service:dialog");

    if (hasHardFailure) {
      dialogService.alert({
        title: "Requirement not met",

        message:
          intro +
          `<br><br>${rows.join("<br>")}` +
          "<br><br>You do not currently meet this community's requirements.",

        buttonLabel:
          "elliepass.verification_dialog.close",
      });

      return true;
    }

    dialogService.confirm({
      title: "In order to continue",

      message,

      confirmButtonLabel:
        "elliepass.verification_dialog.continue",

      cancelButtonLabel:
        "elliepass.verification_dialog.cancel",

      didConfirm: () => {
        const returnTo =
          window.location.pathname +
          window.location.search +
          window.location.hash;

        window.location.href =
          `/elliepass/verify?return_to=${encodeURIComponent(returnTo)}`;
      },
    });

    return true;
  });
});
