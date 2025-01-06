rm -rf build
mkdir build

odin run src -out:build/ohttp -debug -- $1