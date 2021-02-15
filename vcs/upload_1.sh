#cwd=$PWD
#cd ~/Documents/Github/nerves_firmware_ssh
MIX_TARGET=rpi mix upload $1 --firmware $PWD/_build/rpi_dev/nerves/images/vcs.fw
#cd $cwd
