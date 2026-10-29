# Custom Move Mechanics

This folder is reserved for custom GDScript files that define unique move mechanics outside of what the standard mechanics in `res://moves/` (`melee`, `homing`, `shotgun`, `shot`, `beam`) provide.

## How to Create a Custom Move Mechanic:
1. Create a new `.gd` script in this folder extending `MoveData`:
   ```gdscript
   class_name MySpecialMove
   extends MoveData

   func execute(user: Node2D) -> bool:
       var fighter := user as Fighter
       if fighter == null:
           return false
       # Custom behavior here (e.g. self-buff, teleport, healing, unique hazard)
       play_sound(user)
       return true
   ```
2. In your move `.tres` file under `res://data/moves/`, point the resource script to your custom mechanic file:
   ```
   [ext_resource type="Script" path="res://moves/custom_move_mechanics/my_special_move.gd" id="1"]
   ```
3. For all standard moves, leave the script set to `res://moves/move_data.gd` and configure its properties via data fields!
