#!/bin/bash
SCRIPT_PATH=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
cd $SCRIPT_PATH/..

# Set parameters
SCRATCH_ORG_ALIAS="hxl-storefront-scratch"

# Checks that the previous command succeeded
check_status() {
  local status=$?
  if [ $status -ne 0 ]; then
    echo "Install failed: $1 failed" >&2
    exit $status
  fi
}

# Prints a numbered step header
next_step() {
  STEP=$((STEP+1))
  echo "[$STEP/$TOTAL_STEPS] $1"
}

echo ""
echo "HXL storefront demo installer (Pronto storefront app + HXL widgets)"
echo ""
echo "Select installation type:"
echo "  1) Existing org: DE org, Trailhead Playground or sandbox (deploys to your current default org)"
echo "  2) Scratch org (creates a fresh scratch org named \"$SCRATCH_ORG_ALIAS\")"
echo ""
read -p "Enter choice [1-2]: " INSTALL_CHOICE
echo ""

case "$INSTALL_CHOICE" in
  1) INSTALL_TYPE="org" ;;
  2) INSTALL_TYPE="scratch" ;;
  *)
    echo "Install failed: invalid choice \"$INSTALL_CHOICE\"" >&2
    exit 1
    ;;
esac

TOTAL_STEPS=9
STEP=0

if [ "$INSTALL_TYPE" == "org" ]; then
  ORG_ALIAS=$(sf org display --json | jq -r '.result.alias // .result.username')
  check_status "Reading the default org"
  if [ -z "$ORG_ALIAS" ] || [ "$ORG_ALIAS" == "null" ]; then
    echo "Install failed: no default org. Run: sf org login web --alias hxl-demo --set-default" >&2
    exit 1
  fi
  echo "Ready to install to org $ORG_ALIAS"
  echo "Confirm that you've enabled the org features listed in the README (Custom Addresses,"
  echo "State and Country/Territory Picklists, Agentforce, Headless Experience Layer)."
else
  ORG_ALIAS=$SCRATCH_ORG_ALIAS
  echo "Ready to create scratch org $ORG_ALIAS from your default Dev Hub"
fi
echo ""
read -p "Continue? [y/N]: " CONFIRM_INSTALL
if [[ ! "$CONFIRM_INSTALL" =~ ^[Yy]$ ]]; then
  echo "Install cancelled." >&2
  exit 1
fi
echo ""

if [ "$INSTALL_TYPE" == "scratch" ]; then
  TOTAL_STEPS=$((TOTAL_STEPS+1))
  next_step "Creating scratch org..."
  sf org delete scratch --no-prompt --target-org $ORG_ALIAS &> /dev/null
  sf org create scratch --definition-file config/project-scratch-def.json --alias $ORG_ALIAS --set-default --duration-days 30 --wait 15
  check_status "Creating scratch org"
  echo ""
fi

next_step "Deploying the Pronto storefront app (data model, Apex, Storefront Explorer)..."
sf project deploy start --source-dir pronto --target-org $ORG_ALIAS --ignore-conflicts --wait 30
check_status "Deploying the Pronto storefront app"
echo ""

next_step "Deploying the HXL Apex actions, widgets, Lightning Types and Employee Assistant agent..."
sf project deploy start --target-org $ORG_ALIAS --ignore-conflicts --wait 30 \
  --source-dir hxl/main/default/classes \
  --source-dir hxl/main/default/uiWidgets \
  --source-dir hxl/main/default/lightningTypes \
  --source-dir hxl/main/default/permissionsets \
  --source-dir hxl/main/default/aiAuthoringBundles
check_status "Deploying the HXL code"
echo ""

next_step "Deploying the ProntoStorefrontTools MCP server..."
sf project deploy start --source-dir hxl/main/default/mcpServerDefinitions --target-org $ORG_ALIAS --ignore-conflicts --wait 30
check_status "Deploying the MCP server"
echo ""

next_step "Assigning permission sets..."
sf org assign permset --name Merchant_Management_App --name HXL_Storefront_Widgets --target-org $ORG_ALIAS
check_status "Assigning permission sets"
echo ""

next_step "Importing sample data..."
sf data tree import --plan data/data-plan.json --target-org $ORG_ALIAS
check_status "Importing sample data"
echo ""

next_step "Generating sample data: adding storefront thumbnails..."
sf apex run --file apex-scripts/set-storefront-thumbnails.apex --target-org $ORG_ALIAS
check_status "Adding storefront thumbnails"
echo ""

next_step "Generating sample data: setting storefront operating hours..."
sf apex run --file apex-scripts/set-storefront-opening-hours.apex --target-org $ORG_ALIAS
check_status "Setting storefront operating hours"
echo ""

next_step "Publishing agent: Employee_Assistant..."
sf agent publish authoring-bundle --api-name Employee_Assistant --target-org $ORG_ALIAS
check_status "Publishing Employee_Assistant agent"
echo ""

next_step "Activating agent: Employee_Assistant..."
sf agent activate --api-name Employee_Assistant --target-org $ORG_ALIAS
check_status "Activating Employee_Assistant agent"
echo ""

echo "Installation completed."
echo ""
echo "Try it: open the org (sf org open --target-org $ORG_ALIAS), open the Agentforce panel, pick"
echo "Employee Assistant, and ask \"Tell me about The Green Fork.\" then \"Show me the menu for The Green Fork.\""
echo ""
echo "For Slackbot, Claude or ChatGPT: activate the Pronto Storefront Tools MCP server in Setup (see the README)."
echo ""
