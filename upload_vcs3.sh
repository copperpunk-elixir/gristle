cwd=$PWD
cd ~/Documents/Github/nerves_firmware_ssh
mix upload $1 --firmware ~/Documents/Github/gristle/vcs/_build/rpi3_dev/nerves/images/vcs.fw
cd $cwd
