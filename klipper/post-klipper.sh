#!/usr/bin/env bash

echo "ARGS:" "$@"

plugins_dir=$HOME/plugins
config_dir=$HOME/printer_data/config

kamp_dir=$plugins_dir/Klipper-Adaptive-Meshing-Purging

[ ! -d $plugins_dir ] && (echo "No plugins to configure" && exit 0)

git clone https://github.com/kyleisah/Klipper-Adaptive-Meshing-Purging.git $kamp_dir

ln -s $kamp_dir/Configuration $config_dir/KAMP

cp -n $config_dir/KAMP/KAMP_Settings.cfg $config_dir/KAMP_Settings.cfg
