#!/bin/bash
# PixelLab animasyon klasörlerinden Godot SpriteFrames (.tres) üretir.
# Kullanım: make_frames.sh <proje_kökü> <çıktı.tres> <ad>|<animasyon_klasörü (res'e göre)>|<fps>|<loop true/false> [...]
# Örn: make_frames.sh . data/enemies/hellhound_frames.tres \
#        "run|assets/sprites/monster/hellhound/Idle/animations/run|12.0|true" \
#        "attack|assets/sprites/monster/hellhound/Idle/animations/attack|14.0|false"
set -e
root="$1"; out="$2"; shift 2
dirs="south south-east east north-east north"
ext=""; anims=""; count=0
for spec in "$@"; do
  IFS='|' read -r name anim_dir fps loop <<< "$spec"
  for d in $dirs; do
    key="${d//-/_}"
    frames=""
    i=0
    for f in $(ls "$root/$anim_dir/$d" | grep '\.png$' | sort); do
      rid="${name}_${key}_${i}"
      ext+="[ext_resource type=\"Texture2D\" path=\"res://$anim_dir/$d/$f\" id=\"$rid\"]"$'\n'
      [ -n "$frames" ] && frames+=", "
      frames+="{"$'\n'"\"duration\": 1.0,"$'\n'"\"texture\": ExtResource(\"$rid\")"$'\n'"}"
      i=$((i+1)); count=$((count+1))
    done
    [ "$i" -eq 0 ] && { echo "bos klasor: $anim_dir/$d"; exit 1; }
    [ -n "$anims" ] && anims+=", "
    anims+="{"$'\n'"\"frames\": [$frames],"$'\n'"\"loop\": $loop,"$'\n'"\"name\": &\"${name}_$key\","$'\n'"\"speed\": $fps"$'\n'"}"
  done
done
{
  printf '[gd_resource type="SpriteFrames" format=3]\n\n'
  printf '%s\n' "$ext"
  printf '[resource]\nanimations = [%s]\n' "$anims"
} > "$root/$out"
echo "$out: $count kare"
