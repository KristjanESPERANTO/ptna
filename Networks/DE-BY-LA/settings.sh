#!/bin/bash

#
# set variales for analysis of network
#

PREFIX="DE-BY-LA"

OVERPASS_QUERY="http://overpass-api.de/api/interpreter?data=area[boundary=administrative][admin_level=6][name~'Landshut']->.L; rel(area.L)[route~'bus']->.R; rel(br.R); out; rel.R; out; rel(r.R); out; way(r.R); out; node(r.R); out;"
NETWORK_LONG="Landshuter Stadtbusnetz|Landshuter Regionalbusnetz"
NETWORK_SHORT="LA"

ANALYSIS_PAGE="Landshut/Transportation/Analyse"
WIKI_ROUTES_PAGE="Landshut/Transportation/Analyse/DE-BY-LA-Linien"
FILE_DIFF="196"

ANALYSIS_OPTIONS="--check-access --check-name --check-stop-position --check-sequence --check-version --check-wide-characters --multiple-ref-type-entries=allow --positive-notes --coloured-sketchline"

# --max-error=
# --check-bus-stop 
# --expect-network-long
# --expect-network-short
# --expect-network-short-for=
# --expect-network-long-for=
# --relaxed-begin-end-for=

