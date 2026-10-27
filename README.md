# HXL Storefront Demo: Pronto Widgets for Agentforce and MCP Clients

Everything you need to replicate the Pronto storefront demo from the HXL video series on your own Salesforce org. Ask the Employee Assistant "Tell me about The Green Fork" and you get a **storefront profile card**. Click **View Menu** and you get a **menu list widget**. Click **Back to Storefront** and you're back on the card. The same two widgets render in Agentforce, and through an MCP server in Slackbot, Claude, and ChatGPT.

The repo contains:

- **`pronto/`**: the parts of the [Pronto sample app](https://github.com/trailheadapps/pronto) that the demo needs: the data model (storefronts, menus, reviews, orders), Apex services and actions, the Merchant Management app, and the Storefront Explorer page.
- **`hxl/`**: the HXL code: two invocable Apex actions, two widgets, six Custom Lightning Types (CLTs), an MCP server definition, and the Employee Assistant agent with both widgets wired in.

> **Note:** HXL is in beta. Metadata shapes and requirements can change before GA. Beta features are subject to the Beta Services Terms.

## How the pieces fit

```
Apex action (data)  ──►  Custom Lightning Type  ──►  Widget (layout)  ──►  card
```

- **Agentforce** needs **one** CLT per action: the output CLT (for example `c__storefrontProfileCardOutput`) maps the Apex output to the widget.
- **MCP clients** (Slackbot, ChatGPT, Claude) need **two** CLTs today, in the beta: the tool result arrives wrapped in an envelope, so an outer CLT (`getStorefrontFromName`) describes the envelope and points at the response schema. The HXL team is working to remove this requirement.

## What's inside

| Path | What it is |
|---|---|
| `hxl/main/default/classes/` | `GetStorefrontFromNameAction` (storefront card data) and `GetStorefrontMenuAction` (menu data), with tests. Both return display-ready values and use Pronto's `StorefrontService`. |
| `hxl/main/default/uiWidgets/` | `storefrontProfileCard` (**View Menu** and **Check Hours** buttons) and `storefrontMenu` (a `forEach` list with a **Back to Storefront** button) |
| `hxl/main/default/lightningTypes/` | For Agentforce: `storefrontProfileCardOutput`, `storefrontMenuOutput`. For MCP clients: `getStorefrontFromName` + `getStorefrontFromNameResponse`, `getStorefrontMenu` + `getStorefrontMenuResponse` |
| `hxl/main/default/mcpServerDefinitions/` | `ProntoStorefrontTools`: two read-only tools, each linked to its widget through a `ui://widget/lightningType/...` resource |
| `hxl/main/default/aiAuthoringBundles/` | `Employee_Assistant`: Pronto's employee agent, with the `browse_storefronts` subagent returning the card and the menu |
| `hxl/main/default/permissionsets/` | `HXL_Storefront_Widgets`: access to `GetStorefrontMenuAction` |
| `pronto/` | The Pronto storefront app (see [What's different from Pronto](#whats-different-from-pronto)) |
| `data/`, `apex-scripts/` | Pronto sample data (storefronts, menus, reviews, customers, orders), plus scripts that add thumbnails and opening hours |
| `agent-script/` | The two Agent Script action blocks, if you'd rather add the actions to your own agent |
| `playground/` | Structure and data JSON for the [HXL Playground](https://www.headlessexperiencelayer.com/playground/), plus a step-by-step build of the profile card |
| `bin/install.sh` | One-command install |

## Prerequisites

- **Salesforce CLI**, latest version ([install](https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/sfdx_setup_install_cli.htm))
- **[jq](https://jqlang.org/)** (the installer uses it)
- **An org with Agentforce and the HXL beta**, API version 67.0 or later. A Developer Edition org works.

If you install on an existing org (not a scratch org), enable these first. The install fails without them.

1. **Setup > User Interface**: click **Enable Custom Addresses**.
1. **Setup > State and Country/Territory Picklists**: click **Enable State and Country/Territory Picklists**.
1. **Setup > Agentforce Agents**: turn on **Agentforce**.
1. **Setup > Feature Settings > Headless Experience Layer Settings**: turn on **Headless Experience Layer (Beta)**.

## Install

1. Clone this repo and open a terminal in its folder.
1. For an existing org, log in and make it the default org:

   ```sh
   sf org login web --alias hxl-demo --set-default
   ```

   For a scratch org, make sure your default Dev Hub is set (`sf config get target-dev-hub`).

1. Run the installer:

   ```sh
   ./bin/install.sh
   ```

   It deploys `pronto/`, then the HXL code, then the MCP server, then assigns the `Merchant_Management_App` and `HXL_Storefront_Widgets` permission sets, imports the sample data, and publishes and activates the Employee Assistant.

<details>
<summary>Or run the steps yourself</summary>

```sh
ORG=hxl-demo
sf project deploy start --source-dir pronto --target-org $ORG
sf project deploy start --target-org $ORG \
  --source-dir hxl/main/default/classes --source-dir hxl/main/default/uiWidgets \
  --source-dir hxl/main/default/lightningTypes --source-dir hxl/main/default/permissionsets \
  --source-dir hxl/main/default/aiAuthoringBundles
sf project deploy start --source-dir hxl/main/default/mcpServerDefinitions --target-org $ORG
sf org assign permset --name Merchant_Management_App --name HXL_Storefront_Widgets --target-org $ORG
sf data tree import --plan data/data-plan.json --target-org $ORG
sf apex run --file apex-scripts/set-storefront-thumbnails.apex --target-org $ORG
sf apex run --file apex-scripts/set-storefront-opening-hours.apex --target-org $ORG
sf agent publish authoring-bundle --api-name Employee_Assistant --target-org $ORG
sf agent activate --api-name Employee_Assistant --target-org $ORG
```

The HXL code deploys after `pronto/` because the Apex actions call Pronto's `StorefrontService`, and the MCP server deploys last because its tools point at the Apex actions.

</details>

## Try it in Agentforce

1. Open the org (`sf org open`), and open the **Merchant Management** app.
1. Open the Agentforce panel and pick **Employee Assistant**.
1. Ask `Tell me about The Green Fork.` The storefront card appears.
1. Click **View Menu**. The menu widget appears. Click **Back to Storefront** to return to the card.

The output that carries a card must keep these settings in the agent (they're already set in `Employee_Assistant.agent`):

```
complex_data_type_name: "c__storefrontProfileCardOutput"   # or c__storefrontMenuOutput
filter_from_agent: False
is_displayable: True
```

## Try it from an MCP client (Slackbot, Claude, ChatGPT)

1. In Setup, go to **API Catalog > MCP Servers**, open **Pronto Storefront Tools**, and activate it.
1. Connect your MCP client to the server. The URL is `https://api.salesforce.com/platform/mcp/v1/custom/ProntoStorefrontTools`. Your client authenticates through an External Client App with the `mcp_api` and `refresh_token` OAuth scopes. See [Use HXL widgets on MCP channels](https://developer.salesforce.com/docs/platform/hxl/guide/hxl-mcp-channels.html).
1. Ask `Tell me about The Green Fork` or `Show me the menu for The Green Fork`.

Both tools are read-only, so the client can run them without asking for confirmation.

## Try the widget in the Playground (no org needed)

1. Open the [HXL Playground](https://www.headlessexperiencelayer.com/playground/) and go to **Widgets**.
2. Paste `playground/green-fork-structure.json` into **Structure** and `playground/green-fork-data.json` into **Data**.
3. Change `name` in the Data tab. The card updates and the structure stays the same.

`playground/build-steps/` builds the same card in three steps: the header row, the detail rows, then the buttons. `playground/storefront-menu-data.json` is sample data for the menu widget.

## What's different from Pronto

`pronto/` is Pronto's `src-base` folder (from [trailheadapps/pronto](https://github.com/trailheadapps/pronto) at commit `5d2659f`) with only the storefront app kept:

- **Removed (customer-service channel):** the Experience Cloud site, messaging, queues, and Omni-Channel presence; the `Customer_Service_Assistant`, `Customer_Order_Assistant`, and `Storefront_Explorer_Assistant` agents; the routing flows and `Identify_Customer_By_Email`; the `Customer_Support_UtilityBar` page; the site's static resource, audience, and CORS entries; and the `ProntoEmployeeServer` MCP server.
- **Replaced by the HXL versions in `hxl/`:** `GetStorefrontFromNameAction` and its test (now returning display-ready values for the card), and `Employee_Assistant` (now with a local `browse_storefronts` subagent instead of a hand-off to the Storefront Explorer Assistant).
- **Moved:** the `Merchant_Management_App` permission set, from `src-headless` into `pronto/`.

For the full Pronto app, including the customer site and the service agents, install [trailheadapps/pronto](https://github.com/trailheadapps/pronto) instead.

## Resources

- [HXL Developer Guide](https://developer.salesforce.com/docs/platform/hxl/guide/get-started.html)
- [Use HXL widgets on MCP channels](https://developer.salesforce.com/docs/platform/hxl/guide/hxl-mcp-channels.html)
- [HXL Playground](https://www.headlessexperiencelayer.com)
- [AIforce workshop: Give Agents UI with the Headless Experience Layer](https://developer.salesforce.com/workshops/aiforce-workshop/give-agents-ui-with-the-headless-experience-layer-hxl/overview)
- [Pronto sample app](https://github.com/trailheadapps/pronto)

## License

Apache 2.0 (see `LICENSE.md`). The `pronto/`, `data/`, and `apex-scripts/` folders come from the [Pronto sample app](https://github.com/trailheadapps/pronto), © Salesforce, also Apache 2.0; see `NOTICE.md`.
