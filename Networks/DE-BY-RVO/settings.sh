#!/bin/bash

#
# set variales for analysis of network
#

PREFIX="DE-BY-RVO"

OVERPASS_QUERY="http://overpass-api.de/api/interpreter?data=area[boundary=administrative][admin_level=5][name='Oberbayern']->.O; rel(area.O)[route='bus']->.R; rel(br.R); out; rel.R; out; rel(r.R); out; way(r.R); out; node(r.R); out;"
NETWORK_LONG="Regionalverkehr Oberbayern"
NETWORK_SHORT="RVO"

WIKI_ANALYSIS_PAGE="Oberbayern/Transportation/Analyse"
WIKI_ROUTES_PAGE="Oberbayern/Transportation/RVO-Linien-gesamt"
WIKI_FILE_DIFF="196"

ANALYSIS_OPTIONS="-v --wiki --check-access --check-name --check-stop-position --check-sequence --check-version --check-wide-characters --positive-notes --coloured-sketchline --network-long-regex="$NETWORK_LONG" --network-short-regex="$NETWORK_SHORT" --lines-csv=$CSV_FILE --routes=$XML_FILE"

# --max-error=
# --check-bus-stop 
# --expect-network-long
# --expect-network-short
# --expect-network-short-for=
# --expect-network-long-for=
# --relaxed-begin-end-for=
