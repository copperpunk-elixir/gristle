#cwd=$PWD
#cd ~/Documents/Github/nerves_firmware_ssh
MIX_TARGET=rpi3 mix upload $1 --firmware $PWD/_build/rpi3_dev/nerves/images/demo_cluster.fw
#cd $cwd
