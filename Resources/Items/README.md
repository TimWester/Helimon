# Item Creation Guide

This folder contains all the items in the game. Items can be assigned as rewards to enemies and provide stat bonuses when equipped.

## Quick Start - Creating New Items

### Method 1: Duplicate an Existing Item (EASIEST)

1. In Godot's **FileSystem** panel, navigate to `res://Resources/Items/`
2. Right-click on any existing item (e.g., `necklace.tres` or `_TEMPLATE_item.tres`)
3. Select **Duplicate**
4. Name your new item (e.g., `fire_sword.tres`)
5. Click on the new item in the FileSystem
6. In the **Inspector** panel on the right, you'll see all the item properties
7. Edit the properties:
   - **Item Name**: Display name shown in the UI
   - **Description**: Lore/description text
   - **Icon**: (Optional) A texture for the item icon
   - **Item Type**: EQUIPMENT, CONSUMABLE, or QUEST
   - **Spirit Bonus**: Increases mana regeneration per second
   - **Health Bonus**: Increases max health
   - **Mana Bonus**: Increases max mana
   - **Damage Bonus**: Increases damage dealt

### Method 2: Create from Scratch in Godot

1. In the **FileSystem** panel, navigate to `res://Resources/Items/`
2. Right-click in empty space → **Create New** → **Resource**
3. In the dialog, search for "Item" and select it
4. Name your new item file (e.g., `mystic_staff.tres`)
5. Edit the properties in the Inspector as described above

### Method 3: Duplicate the Template File

The `_TEMPLATE_item.tres` file is a blank template with all properties set to default values. You can duplicate this file and edit it to create new items quickly.

## Example Items Included

- **necklace.tres** - Spirit Necklace (+1 Spirit)
- **leatherTunic.tres** - Your custom creation!
- **health_ring.tres** - Ring of Vitality (+25 Health)
- **mana_amulet.tres** - Amulet of the Arcane (+20 Mana)
- **warrior_sword.tres** - Warrior's Blade (+5 Damage)
- **sage_pendant.tres** - Sage's Pendant (Multi-stat bonus)
- **_TEMPLATE_item.tres** - Blank template for creating new items

## Assigning Items to Enemies

1. Open `res://Scenes/main_scene.tscn`
2. Select an enemy node (e.g., `Enemy1` or `Enemy2`) in the Scene tree
3. In the **Inspector**, find the **Rewards** section
4. Find **Item Rewards** (it's an Array)
5. Click the array size number and increase it (e.g., from 0 to 1, or 1 to 2)
6. Click the dropdown for each array element
7. Select **Quick Load** and choose your item file from `Resources/Items/`
8. Repeat steps 5-7 to add more items
9. Save the scene

Now when the player defeats that enemy, they'll receive **all** the items you assigned!

## Item Stat Effects

- **Spirit**: Increases mana regeneration rate (1 spirit = 1 mana per second)
- **Health**: Adds to maximum health pool
- **Mana**: Adds to maximum mana pool
- **Damage**: Adds to attack damage

## Notes

- **You can assign multiple items to a single enemy** - they'll all drop when defeated
- Items are automatically equipped when received (for now)
- Multiple items can be equipped at once - their bonuses stack
- Items are stored in the player's inventory in `GameState`
- Items persist during a run but are cleared when the player dies
- If multiple items are rewarded, the victory screen shows them as a comma-separated list
