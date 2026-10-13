# Cleans every raw Tripo model in models_raw/src into models_raw/clean, 3 at a time.
# Row format: name | size (m) | measure | max faces | max texture px [| extra args]
$rows = @"
fox|0.70|height|30000|2048
moss_spirit|0.65|height|20000|2048
blue_spirit|0.75|height|20000|2048
giant_tree|13.0|height|110000|2048
tea_stall|4.4|length|150000|2048
bridge|5.8|length|70000|2048
bench|1.6|length|20000|1024
lantern_post|2.2|height|6000|1024
kettle|0.30|height|6000|1024
teacup|0.10|height|3000|1024
bait_jar|0.22|height|4000|1024
lantern|0.45|height|4000|1024
wish_lantern|0.50|height|4000|1024
moonleaf|0.55|height|8000|1024
coin|0.035|length|1500|512
charm|0.12|height|3000|512
forest_tree_a|9.0|height|12000|1024
forest_tree_b|8.0|height|12000|1024
shrub|1.0|height|4000|1024
fern|0.5|height|2000|1024
flower|0.28|height|1000|512
lily_pad|0.45|length|900|512
rock|1.0|length|2500|1024
stepping_stone|0.7|length|800|1024
frog|0.15|height|12000|1024
rabbit|0.32|height|14000|1024
owl|0.42|height|14000|1024
duck|0.13|height|8000|1024|--yaw 90
koi|0.42|length|8000|1024|--yaw -90
moonfin|0.34|length|8000|1024|--yaw 90
butterfly|0.09|length|3000|512|--pitch 90
bee|0.035|length|2500|512|--min-part 0.0
bait|0.16|height|5000|1024
bobber|0.09|height|3000|512
fishing_rod|1.7|length|6000|1024
reeds|1.2|height|5000|1024
grass_a|0.32|height|2500|512
grass_b|0.30|height|2500|512
grass_c|0.32|height|3000|1024
leafy|0.30|height|2500|1024
lavender|0.40|height|5000|1024
glow_mushrooms|0.28|height|5000|1024
potion_bottles|0.26|height|8000|1024
herb_jars|0.24|height|8000|1024
stone_lantern|1.1|height|8000|1024
barrel|0.85|height|8000|1024
dock|6.0|length|40000|2048
water_lantern|0.32|length|4000|1024
"@ -split "`r?`n" | Where-Object { $_ -ne "" }

$root = Split-Path -Parent $PSScriptRoot
$blender = if ($env:BLENDER) { $env:BLENDER } else { "blender" }
$preview = "$root\models_raw\previews"
New-Item -ItemType Directory -Force "$root\models_raw\clean", $preview | Out-Null
$todo = $rows | Where-Object {
  $n = ($_ -split '\|')[0]
  (Test-Path "$root\models_raw\src\$n.glb") -and -not (Test-Path "$root\models_raw\clean\$n.glb")
}
"todo: $($todo.Count)"
$todo | ForEach-Object -ThrottleLimit 3 -Parallel {
  $f = $_ -split '\|'; $root = $using:root
  $out = & $using:blender --background --factory-startup --python "$root\tools\prepare_model.py" -- `
    --in "$root\models_raw\src\$($f[0]).glb" --out "$root\models_raw\clean\$($f[0]).glb" `
    --size $f[1] --measure $f[2] --max-faces $f[3] --tex $f[4] --preview $using:preview `
    @(if ($f.Count -gt 5) { $f[5] -split ' ' } else { @() }) 2>&1
  $line = $out | Select-String "PREPARE_REPORT" | Select-Object -First 1
  if ($line) { "$($f[0]): " + ($line.ToString() -replace '.*PREPARE_REPORT ', '') }
  else { "$($f[0]): FAILED`n" + ($out | Select-Object -Last 8 | Out-String) }
}
"BATCH_DONE"
