#!/bin/bash

#
# analyze ÖPNV routes
#

WD=$PWD

PATH=$PWD:$PATH

for A in  NETWORKS/*
do
    
    cd $A

    ./analyze-area.sh $1

    cd $WD

done

