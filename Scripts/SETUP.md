# Roblox setup

1. Put `MoneyAndUpgradesServer.lua` inside **ServerScriptService**.
2. Put `MoneyTextLabel.client.lua` as a **LocalScript** under your money `TextLabel`.
3. Put `BuyAndPlaceButton.client.lua` as a **LocalScript** under your buy `TextButton`.
4. Make sure this part exists: `ReplicatedStorage/Upgrades/Basic/Part`.

Behavior included:
- Money stat in `leaderstats` (`Money`) with DataStore saving.
- TextLabel live-updates to show `Cash: <amount>`.
- Button enters placement mode; preview part is semi-transparent and smooth-snaps to your own character's body surface.
- Clicking while preview is on your body buys once (`-50`) and places/welds the part on your character.
- Placement exits automatically after one click.
- Bought parts and money are restored when rejoining.
