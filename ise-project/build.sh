#!/bin/bash
set -o pipefail

MODULE=timex_interface

# cleanup

rm -rf 'xlnx_auto_0_xdb' '_xmsgs' 'xst' '_impact.cmd' '_impact.log' 'netlist.lst' 'timex_interface.bld' 'timex_interface.gyd' 'timex_interface.jed' 'timex_interface.lso' 'timex_interface.mfd' 'timex_interface.ngc' 'timex_interface.ngd' 'timex_interface.ngr' 'timex_interface.pad' 'timex_interface.pnx' 'timex_interface.rpt' 'timex_interface.srf' 'timex_interface.vm6' 'timex_interface.xml' 'timex_interface_build.xml' 'timex_interface_ngdbuild.xrpt' 'timex_interface_pad.csv' 'timex_interface_xst.xrpt' 'tmperr.err'

xst -ifn $MODULE.xst -ofn $MODULE.srf
if [ $? -ne 0 ]; then
    echo "Error: xst failed"
    exit 1
fi

ngdbuild -p xc9572xl-vq44 $MODULE.ngc
if [ $? -ne 0 ]; then
    echo "Error: ngdbuild failed"
    exit 1
fi

cpldfit -p xc9572xl-10-vq44 $MODULE.ngd
if [ $? -ne 0 ]; then
    echo "Error: cpldfit failed"
    exit 1
fi

hprep6 -i $MODULE.vm6
if [ $? -ne 0 ]; then
    echo "Error: hprep6 failed"
    exit 1
fi

echo "#####"
stat -c "%n: %s bytes" timex_interface.jed
