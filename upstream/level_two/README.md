# Preserved upstream mechanic test

Source: https://github.com/yujuan0215/funny-battle/commit/62be378

`duel.gd`, `prop.gd`, and `moves.csv` preserve that revision's duel, placement-based spring rules, and pause/success UI. Local adaptations alias the prop script to avoid conflicting with the introductory arena, point at this snapshot's CSV, and remove its global `class_name DuelProp` registration. The CSV is kept as raw data rather than imported as translations.

`scripts/level_two.gd` supplies the local test-lab entry/exit, half speed, independent test progress, and route to the spike challenge. This snapshot is a test arena and does not occupy chapter two in the adventure catalog.

The snapshot refers to its prop script as `LabProp`; naming it `DuelProp` collides with the global class in `scripts/duel_prop.gd`, which makes every `as DuelProp` cast null and props inert.
