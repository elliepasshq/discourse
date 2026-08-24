# ElliePass for Discourse

ElliePass adds privacy-focused verification requirements to Discourse communities.

Community administrators can require members to meet selected verification requirements before performing protected actions, while ElliePass handles the verification process outside of Discourse.

## Supported Verification Requirements

Depending on the community's ElliePass configuration, members can be required to satisfy:

- **Human verification** — verifies that the member is a real, live person.
- **Identity verification** — verifies a government-issued identity.
- **Minimum age** — verifies that the member meets the community's required minimum age.
- **Current location** — verifies the member's current country and/or region.
- **ID-verified location** — verifies location using verified identity information.

Communities choose which requirements they need. Members only need to satisfy the requirements configured for that community.

## What Can Be Protected

Community administrators can independently require ElliePass verification before a member:

- Creates a new topic
- Posts a reply to a topic
- Starts a private message
- Replies to a private message

Normal community browsing and other standard Discourse functionality remain available.

Discourse staff and administrators are not subject to ElliePass verification requirements.

## How It Works

1. A member attempts an action protected by ElliePass.
2. The plugin checks the community's current ElliePass verification policy.
3. ElliePass determines which requirements the member already satisfies.
4. If additional verification is required, Discourse shows the member the requirements that need attention.
5. The member continues securely to ElliePass.
6. ElliePass performs only the verification needed for the community's requirements.
7. The member returns to Discourse.
8. Once all requirements are satisfied, the member can continue the protected action.

ElliePass remains authoritative for verification status. The Discourse plugin does not perform identity, age, or human verification itself.

## Installation

Add the ElliePass plugin to your Discourse installation.

In `containers/app.yml`, add the plugin repository to the `hooks.after_code` section:

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/elliepasshq/elliepass-discourse.git elliepass
```

Then rebuild Discourse:

```bash
cd /var/discourse
./launcher rebuild app
```

### ElliePass setup on Discourse

After the rebuild completes:

1. Sign in to Discourse as an administrator.
2. Go to **Admin → Plugins → Installed plugins**.
3. Find **ElliePass** and enable it.
4. Click **Settings** or **ElliePass** to continue setup.
5. Now sign in to ElliePass.com to continue to setup.

## ElliePass setup at ElliePass.com

Before configuring the plugin, create a community in ElliePass.

1. Sign in to ElliePass.
2. Under ElliePass Communtiy click **Get Started**
3. Click **Add Community**.
4. Enter your Discourse community name and URL.
5. Select **Discourse** as the platform. Click **Add Community**
6. On the community setup page, click **Generate connection settings**.
7. Copy the **API URL**, **Community Key**, and **Community Secret** into the ElliePass plugin settings in Discourse, then click **Save all changes**.
8. Confirm that the plugin shows **Connected to ElliePass**.
9. Return to ElliePass Community Admin and configure the verification requirements and protected actions for your community.
10. Your community is now ready to require ElliePass verification.


## Discourse Configuration

In your Discourse administration settings, configure the ElliePass plugin:

- **elliepass enabled** — enables ElliePass enforcement.
- **elliepass api url** — ElliePass API endpoint.
- **elliepass community key** — identifies your ElliePass community.
- **elliepass community secret** — authenticates your Discourse installation with ElliePass.

The production ElliePass API is:

```text
https://elliepass.com
```

After configuration, use the ElliePass connection status in Discourse to confirm that the community is connected successfully.

## Verification Policy

Verification requirements and protected actions are managed through ElliePass Community Admin rather than independently inside Discourse.

This keeps ElliePass as the authoritative source for:

- Required verification capabilities
- Minimum age
- Location requirements
- Verification expiration
- Protected community actions
- Policy version

Policy changes are synchronized with the Discourse plugin automatically.

When a policy changes, previously cached authorization information from an older policy version is not used to bypass the new policy.

## Caching

The plugin locally caches authorization information so members do not require an ElliePass API request for every protected action.

ElliePass separates reusable verification state from current-location state so each can have an appropriate cache lifetime.

While a valid cached authorization result is available, protected actions continue to use that result without requiring ElliePass to be contacted again.

Cache entries are invalidated when necessary, including after verification activity and relevant ElliePass policy updates.

## ElliePass Availability

A temporary ElliePass API outage does not prevent members with valid cached authorization information from continuing to use protected community features.

If a cached authorization result has expired and ElliePass cannot be reached to obtain a current decision, the plugin fails closed rather than silently bypassing the community's verification policy.

In that situation, the member receives a temporary-unavailable message and can try again when ElliePass is available.

Members who have never received an authorization decision also require ElliePass to be available before using a protected action.

Browsing and other actions that the community has not protected with ElliePass remain unaffected.

## Privacy

ElliePass is designed so communities can enforce verification requirements without receiving the underlying identity documents or sensitive verification data.

Discourse receives only the authorization information needed to determine whether a member satisfies the community's requirements.

The plugin does not store government-issued identity documents, selfies, or other verification evidence in Discourse.

## Debug Logging

Detailed ElliePass diagnostic logging is disabled by default.

Administrators troubleshooting an integration can temporarily enable:

```text
elliepass_debug_logging
```

When enabled, the plugin logs additional information about policy synchronization, authorization decisions, caching, and protected-action enforcement.

Disable debug logging again after troubleshooting.

Authentication secrets and identity verification evidence should never be written to logs.

## Updating

Update the plugin using the normal Discourse plugin update/rebuild process.

For container-based Discourse installations:

```bash
cd /var/discourse
./launcher rebuild app
```

## Uninstalling

Disable ElliePass in the Discourse plugin settings before removing the plugin.

Then remove the ElliePass plugin from your Discourse plugin configuration and rebuild the Discourse container.

Removing the Discourse plugin does not delete the community or its configuration from ElliePass.

## Requirements

- A supported Discourse installation
- An ElliePass community
- ElliePass Community Key
- ElliePass Community Secret
- HTTPS-accessible Discourse community

## Support

For ElliePass information and support, visit:

https://elliepass.com

## License

See the repository's `LICENSE` file.