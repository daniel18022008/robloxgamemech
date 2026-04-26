# Roblox setup (required)

## 1) Put scripts in the right services

1. Put `MoneyAndUpgradesServer.lua` inside **ServerScriptService**.
2. Put `MoneyTextLabel.client.lua` as a **LocalScript** under your money `TextLabel`.
3. Put `BuyAndPlaceButton.client.lua` as a **LocalScript** under your buy `TextButton`.

> The two `.client.lua` scripts must run from PlayerGui (for example `StarterGui/ScreenGui/...`), not from Workspace.

## 2) Required objects / folders

- `ReplicatedStorage/Upgrades/Basic/Part` (a BasePart template you want to buy/place).
- If it does not exist, the server script now auto-creates a fallback orange part at that path.
- `ReplicatedStorage/UpgradeRemotes/PlacePartRequest` and `ReplicatedStorage/UpgradeRemotes/CashChanged` are auto-created by the server script (you do not need to create these manually).

## 3) DataStore setting (for persistence)

To save cash + placed parts between sessions in Studio:

- Go to **Game Settings → Security**.
- Enable **Studio Access to API Services**.
- Publish the place/game at least once.

Without this, money/parts will work during play but may not persist after leaving.

## 4) UI flow

- Click the buy button to enter placement mode.
- Hover over your own character body to see the semi-transparent preview snap.
- Click once on your own body to buy (`-50`) and place.
- Press `Esc` to cancel placement mode.

## Behavior included

- Money stat in `leaderstats` (`Money`) with DataStore saving.
- TextLabel live-updates to show `Cash: <amount>`.
- Button enters placement mode; preview part is semi-transparent and smooth-snaps to your own character's body surface.
- Clicking while preview is on your body buys once (`-50`) and places/welds the part on your character.
- Placement exits automatically after one click.
- Bought parts and money are restored when rejoining.
