#!/bin/bash

MODULE=timex_interface

xst -ifn $MODULE.xst -ofn $MODULE.srf
ngdbuild -p xc9572xl-vq44 $MODULE.ngc
cpldfit -p xc9572xl-10-vq44 $MODULE.ngd
hprep6 -i $MODULE.vm6
