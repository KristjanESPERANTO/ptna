#!/bin/bash

#
# Public Transport Network Analysis of a single network
#

if [ -z "$PTNA_TARGET_LOC"     -o \
     -z "$PTNA_RESULTS_LOC"    -o \
     -z "$PTNA_NETWORKS_LOC"   -o \
     -z "$PTNA_WORK_LOC"            ]
then
    echo " ...unset global variable(s)"
    [ -z "$PTNA_TARGET_LOC"       ] && echo "Please specify: PTNA_TARGET_LOC as environment variable outside the tools"
    [ -z "$PTNA_RESULTS_LOC"      ] && echo "Please specify: PTNA_RESULTS_LOC as environment variable outside the tools"
    [ -z "$PTNA_NETWORKS_LOC"     ] && echo "Please specify: PTNA_NETWORKS_LOC as environment variable outside the tools"
    [ -z "$PTNA_WORK_LOC"         ] && echo "Please specify: PTNA_WORK_LOC as environment variable outside the tools"
    echo "... terminating"
    exit 1
fi


SETTINGS_DIR="."


TEMP=$(getopt -o acCfgGhoOpPuwWS --long analyze,clean-created,clean-downloaded,get-routes,get-talk,force-download,help,overpass-query,overpass-query-on-zero-xml,push-routes,push-talk,update-result,watch-routes,watch-talk,settings-dir -n 'ptna-network.sh' -- "$@")

if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 2 ; fi

eval set -- "$TEMP"

while true ; do
    case "$1" in
        -a|--analyze)                       analyze=true                ; shift ;;
        -c|--clean-created)                 cleancreated=true           ; shift ;;
        -C|--clean-downloaded)              cleandownloaded=true        ; shift ;;
        -f|--force-download)                forcedownload=true          ; shift ;;
        -g|--get-routes)                    getroutes=true              ; shift ;;
        -G|--get-talk)                      gettalk=true                ; shift ;;
        -h|--help)                          help=true                   ; shift ;;
        -o|--overpass-query)                overpassquery=true  ; overpassqueryonzeroxml=false ; shift ;;
        -O|--overpass-query-on-zero-xml)    overpassqueryonzeroxml=true  ; overpassquery=false ; shift ;;
        -p|--push-routes)                   pushroutes=true             ; shift ;;
        -P|--push-talk)                     pushtalk=true               ; shift ;;
        -u|--update-result)                 updateresult=true           ; shift ;;
        -w|--watch-routes)                  watchroutes=true            ; shift ;;
        -W|--watch-talk)                    watchtalk=true              ; shift ;;
        -S|--settings_dir)                  shift; SETTINGS_DIR=$1      ; shift ;;
        --) shift ; break ;;
        *) echo "Internal error!" ; exit 3 ;;
    esac
done


#
#
#

if [ -f "$SETTINGS_DIR/settings.sh" -a -r "$SETTINGS_DIR/settings.sh" ]
then
    . $SETTINGS_DIR/settings.sh              # source the settings.sh and 'import' shell network specific variables
else
    echo "$SETTINGS_DIR/settings.sh: file not found ... terminating"
    exit 4
fi


if [ -z "$PREFIX"          -o \
     -z "$OVERPASS_QUERY"  -o \
     -z "$ANALYSIS_OPTIONS"     ]
then
    echo "$SETTINGS_DIR/settings.sh file: unset variables(s)"
    [ -z "$PREFIX"           ] && echo "Please specify: PREFIX"
    [ -z "$OVERPASS_QUERY"   ] && echo "Please specify: OVERPASS_QUERY"
    [ -z "$ANALYSIS_OPTIONS" ] && echo "Please specify: ANALYSIS_OPTIONS"
    echo "... terminating"
    exit 5
fi

# on the web and in the work directory, the data will be stored in sub-directories
# PREFIX=DE-BY-MVV --> stored in SUB_DIR=DE/BY
# PREFIX=DE-BW-DING-SWU --> stored in SUB_DIR=DE/BW
# PREFIX=FR-IDF-entre-seine-et-foret --> stored in SUB_DIR=FR/IDF
# PREFIX=EU-Flixbus --> stored in SUB_DIR=EU

# PREFIX=FR-IDF-entre-seine-et-foret --> changed into in SUB_DIR=FR/IDF-entre-seine-et-foret
SUB_DIR=${PREFIX/-//}
# SUB_DIR=FR/IDF-entre-seine-et-foret --> changed into in SUB_DIR=FR/IDF/entre-seine-et-foret
SUB_DIR=${SUB_DIR/-//}
# SUB_DIR=FR/IDF/entre-seine-et-foret --> changed into in SUB_DIR=FR/IDF
SUB_DIR="${SUB_DIR%/*}"

COUNTRY_DIR="${PREFIX%%-*}"

WORK_LOC="$PTNA_WORK_LOC/$SUB_DIR"

ROUTES_FILE="$PREFIX-Routes.txt"
SETTINGS_FILE="settings.sh"
TALK_FILE="$PREFIX-Talk.wiki"

HTML_FILE="$PREFIX-Analysis.html"
DIFF_FILE="$PREFIX-Analysis.html.diff"
DIFF_HTML_FILE="$PREFIX-Analysis.diff.html"
SAVE_FILE="$PREFIX-Analysis.html.save"
DETAILS_FILE="$PREFIX-Analysis-details.txt"

if [ "$OVERPASS_REUSE_ID" ]
then
    OSM_XML_FILE_ABSOLUTE="$PTNA_WORK_LOC/$OVERPASS_REUSE_ID-Data.xml"
else
    OSM_XML_FILE_ABSOLUTE="$WORK_LOC/$PREFIX-Data.xml"
fi

#
#
#

if [ "$forcedownload" = "true" ]
then
    overpassquery="true"

elif [ "$overpassquery" = "true" ]
then
    if [ "$OVERPASS_REUSE_ID" -a -f $OSM_XML_FILE_ABSOLUTE -a -s $OSM_XML_FILE_ABSOLUTE ]
    then
        last_mod=$(stat -c '%Y' $OSM_XML_FILE_ABSOLUTE)
        now=$(date '+%s')
        age=$(( $now - $last_mod ))

        if [ "$age" -lt 3600 ]
        then
            echo $(date "+%Y-%m-%d %H:%M:%S") "Skipping download via Overpass Query API to $OSM_XML_FILE_ABSOLUTE"
            echo $(date "+%Y-%m-%d %H:%M:%S") "Age of file: $age seconds is less than 3600 seconds = 1 hour"
            echo $(date "+%Y-%m-%d %H:%M:%S") "Use option -f if you want to force the download"
            overpassquery="false"
        fi
    fi
fi

#
#
#

if [ "$cleancreated" = "true" ]
then
    echo $(date "+%Y-%m-%d %H:%M:%S") "Removing temporary files"
    rm -f $WORK_LOC/$HTML_FILE $WORK_LOC/$DIFF_FILE $WORK_LOC/$DIFF_HTML_FILE $WORK_LOC/$SAVE_FILE
fi

#
#
#

if [ "$cleandownloaded" = "true" ]
then
    echo $(date "+%Y-%m-%d %H:%M:%S") "Removing XML and Routes file"
    rm -f $OSM_XML_FILE_ABSOLUTE $WORK_LOC/$ROUTES_FILE
fi

#
#
#

if [ "$overpassqueryonzeroxml" = "true" ]
then
    if [ -f $OSM_XML_FILE_ABSOLUTE -a -s $OSM_XML_FILE_ABSOLUTE ]
    then
        echo $(date "+%Y-%m-%d %H:%M:%S") "File '$OSM_XML_FILE_ABSOLUTE' exists, no further analysis required, terminating"
        exit 0
    else
        echo $(date "+%Y-%m-%d %H:%M:%S") "File '$OSM_XML_FILE_ABSOLUTE' does not exist or is empty, starting download"
        overpassquery="true"
    fi
fi

#
#
#

if [ "$overpassquery" = "true" ]
then
    echo $(date "+%Y-%m-%d %H:%M:%S") "Calling wget for '$PREFIX'"

    OSM_XML_LOC=$(dirname $OSM_XML_FILE_ABSOLUTE)

    if [ ! -d "$OSM_XML_LOC" ]
    then
        echo $(date "+%Y-%m-%d %H:%M:%S") "Creating directory $OSM_XML_LOC"
        mkdir -p $OSM_XML_LOC
    fi

    if [ -d "$OSM_XML_LOC" ]
    then
        wget "$OVERPASS_QUERY" -O $OSM_XML_FILE_ABSOLUTE
        echo $(date "+%Y-%m-%d %H:%M:%S") "wget returns $?"

        if [ -s $OSM_XML_FILE_ABSOLUTE ]
        then
            echo $(date "+%Y-%m-%d %H:%M:%S") "Success for wget for '$PREFIX'"
        else
            echo $(date "+%Y-%m-%d %H:%M:%S") "Calling wget for '$PREFIX' a second time"
            # try a second, but only a second time
            sleep 60
            wget "$OVERPASS_QUERY" -O $OSM_XML_FILE_ABSOLUTE
            echo $(date "+%Y-%m-%d %H:%M:%S") "wget returns $?"

            if [ -s $OSM_XML_FILE_ABSOLUTE ]
            then
                echo $(date "+%Y-%m-%d %H:%M:%S") "Success for wget for '$PREFIX'"
            else
                echo $(date "+%Y-%m-%d %H:%M:%S") "Failure for wget for '$PREFIX'"
            fi
        fi
    else
        echo $(date "+%Y-%m-%d %H:%M:%S") "Work dir $OSM_XML_LOC does not exist/could not be created"
    fi
fi

#
#
#

if [ "$getroutes" = "true" ]
then
    if [ -n "$WIKI_ROUTES_PAGE" ]
    then
        echo $(date "+%Y-%m-%d %H:%M:%S") "Reading Routes Wiki page '$WIKI_ROUTES_PAGE' to file '$WORK_LOC/$ROUTES_FILE'"
        ptna-wiki-page.pl --pull --page=$WIKI_ROUTES_PAGE --file=$WORK_LOC/$ROUTES_FILE
        echo $(date "+%Y-%m-%d %H:%M:%S") $(ls -l $WORK_LOC/$ROUTES_FILE)
    else
        if [ -f "$SETTINGS_DIR/$ROUTES_FILE" ]
        then
            echo $(date "+%Y-%m-%d %H:%M:%S") "'$ROUTES_FILE' provided by GitHub, copy to $WORK_LOC"
            cp $SETTINGS_DIR/$ROUTES_FILE $WORK_LOC/$ROUTES_FILE
            echo $(date "+%Y-%m-%d %H:%M:%S") $(ls -l $WORK_LOC/$ROUTES_FILE)
        else
            echo $(date "+%Y-%m-%d %H:%M:%S") "no file: '$ROUTES_FILE'"
        fi
    fi
fi

#
#
#

if [ "$gettalk" = "true" ]
then
    if [ -n "$ANALYSIS_TALK" ]
    then
        echo $(date "+%Y-%m-%d %H:%M:%S") "Reading Analysis Talk Wiki page '$ANALYSIS_TALK' to file '$WORK_LOC/$TALK_FILE'"
        ptna-wiki-page.pl --pull --page=$ANALYSIS_TALK --file=$WORK_LOC/$TALK_FILE
        echo $(date "+%Y-%m-%d %H:%M:%S") $(ls -l $WORK_LOC/$TALK_FILE)
    fi
fi

#
#
#

if [ "$analyze" = "true" ]
then
    echo $(date "+%Y-%m-%d %H:%M:%S")  "Analyze $PREFIX"

    if [ -f $OSM_XML_FILE_ABSOLUTE ]
    then
        if [ -s $OSM_XML_FILE_ABSOLUTE ]
        then
            rm -f $WORK_LOC/$DIFF_FILE.diff

            if [ -f "$WORK_LOC/$HTML_FILE" -a -s "$WORK_LOC/$HTML_FILE" ]
            then
                mv $WORK_LOC/$HTML_FILE $WORK_LOC/$SAVE_FILE
            fi
            ptna-routes.pl --v\
                           --title="$PREFIX" \
                           --network-guid=$PREFIX \
                           $ANALYSIS_OPTIONS \
                           --expect-network-short-as="$EXPECT_NETWORK_SHORT_AS" \
                           --expect-network-short-for="$EXPECT_NETWORK_SHORT_FOR" \
                           --expect-network-long-as="$EXPECT_NETWORK_LONG_AS" \
                           --expect-network-long-for="$EXPECT_NETWORK_LONG_FOR" \
                           --network-long-regex="$NETWORK_LONG" \
                           --network-short-regex="$NETWORK_SHORT" \
                           --operator-regex="$OPERATOR_REGEX" \
                           --routes-file=$WORK_LOC/$ROUTES_FILE \
                           --osm-xml-file=$OSM_XML_FILE_ABSOLUTE \
                           2>&1 > $WORK_LOC/$HTML_FILE | tee $WORK_LOC/$HTML_FILE.log

            if [ -s "$WORK_LOC/$HTML_FILE" ]
            then
                echo $(date "+%Y-%m-%d %H:%M:%S") "Analysis succeeded, '$WORK_LOC/$HTML_FILE' created"
                echo $(date "+%Y-%m-%d %H:%M:%S") $(ls -l $WORK_LOC/$HTML_FILE)

                if [ -f "$WORK_LOC/$SAVE_FILE" -a -s "$WORK_LOC/$SAVE_FILE" ]
                then
                    diff $WORK_LOC/$SAVE_FILE $WORK_LOC/$HTML_FILE > $WORK_LOC/$DIFF_FILE
                    echo $(date "+%Y-%m-%d %H:%M:%S") "Diff size:  " $(ls -l $WORK_LOC/$DIFF_FILE | awk '{print $5 " " $9}')
                    echo $(date "+%Y-%m-%d %H:%M:%S") "Diff lines: " $(wc -l $WORK_LOC/$DIFF_FILE)
                else
                    rm -f $WORK_LOC/$SAVE_FILE
                fi
            else
                echo $(date "+%Y-%m-%d %H:%M:%S") "'$WORK_LOC/$HTML_FILE' is empty"
            fi
        else
            echo $(date "+%Y-%m-%d %H:%M:%S") "'$OSM_XML_FILE_ABSOLUTE' is empty"
            echo $(date "+%Y-%m-%d %H:%M:%S") $(ls -l $WORK_LOC/$HTML_FILE)
       fi
    else
        echo $(date "+%Y-%m-%d %H:%M:%S") "'$OSM_XML_FILE_ABSOLUTE' does not exist"
    fi
fi

#
#
#

if [ "$updateresult" = "true" ]
then
    RESULTS_LOC="$PTNA_TARGET_LOC/$PTNA_RESULTS_LOC/$SUB_DIR"

    echo "REGION_NAME=$PTNA_WWW_REGION_NAME"         >  $WORK_LOC/$DETAILS_FILE
    echo "REGION_LINK=$PTNA_WWW_REGION_LINK"         >> $WORK_LOC/$DETAILS_FILE
    echo "NETWORK_NAME=$PTNA_WWW_NETWORK_NAME"       >> $WORK_LOC/$DETAILS_FILE
    echo "NETWORK_LINK=$PTNA_WWW_NETWORK_LINK"       >> $WORK_LOC/$DETAILS_FILE
    echo "DISCUSSION_NAME=$PTNA_WWW_DISCUSSION_NAME" >> $WORK_LOC/$DETAILS_FILE
    echo "DISCUSSION_LINK=$PTNA_WWW_DISCUSSION_LINK" >> $WORK_LOC/$DETAILS_FILE
    echo "ROUTES_NAME=$PTNA_WWW_ROUTES_NAME"         >> $WORK_LOC/$DETAILS_FILE
    echo "ROUTES_LINK=$PTNA_WWW_ROUTES_LINK"         >> $WORK_LOC/$DETAILS_FILE

    echo $(date "+%Y-%m-%d %H:%M:%S")  "Updating '$WORK_LOC/$HTML_FILE' to '$RESULTS_LOC'"

    if [ -f $WORK_LOC/$HTML_FILE ]
    then
        if [ -s $WORK_LOC/$HTML_FILE ]
        then
            # DIFF_LINES_BASE defines how many diff lines we have to tollerate in order to skip the
            # different time strings of the analysis
            # only diffs in the analysis result count

            NEW_OSM_Base_Time="$(awk '/OSM-Base Time : .* UTC/ { print $4 "T" $5 "Z"; }' $WORK_LOC/$HTML_FILE)"
            NEW_Local_OSM_Base_Time="$(TZ=${PTNA_TIMEZONE:-Europe/Berlin} date --date "$NEW_OSM_Base_Time" '+%Y-%m-%d %H:%M:%S %Z' | sed -e 's/ \([+-][0-9]*\)$/ UTC\1/')"

            echo "NEW_DATE_UTC=$NEW_OSM_Base_Time"       >> $WORK_LOC/$DETAILS_FILE
            echo "NEW_DATE_LOC=$NEW_Local_OSM_Base_Time" >> $WORK_LOC/$DETAILS_FILE

            if [ $(echo $OVERPASS_QUERY | egrep -c '(data=area)|(data=\[timeout:[0-9]+\];area)') = 1 ]
            then
                # Overpass-API query includes an area(...), so AREA Time is included in HTML
                # this is the case for most 'network' analyzes
                DIFF_LINES_BASE=8
            else
                # Overpass-API query includes definition of a poly('...'), so no AREA Time is included in HTML
                # this is the case for EU-Flixbus and one or two others
                DIFF_LINES_BASE=4
            fi

            if [ ! -d "$RESULTS_LOC" ]
            then
                echo $(date "+%Y-%m-%d %H:%M:%S") "Creating directory $RESULTS_LOC"
                mkdir -p $RESULTS_LOC
            fi

            if [ -d "$RESULTS_LOC" ]
            then

                echo $(date "+%Y-%m-%d %H:%M:%S")  "Copying '$RESULTS_LOC/$HTML_FILE' to '$WORK_LOC/$SAVE_FILE'"
                if [ -f $RESULTS_LOC/$HTML_FILE ]
                then
                    cp $RESULTS_LOC/$HTML_FILE $WORK_LOC/$SAVE_FILE
                else
                    # if there is no *.html file on the Web server side, the we delete also the local *.save file, so that a copy will take place
                    rm -f $WORK_LOC/$SAVE_FILE
                fi

                if [ -f "$WORK_LOC/$SAVE_FILE" ]
                then
                    OLD_OSM_Base_Time="$(awk '/OSM-Base Time : .* UTC/ { print $4 "T" $5 "Z"; }' $WORK_LOC/$SAVE_FILE)"
                    OLD_Local_OSM_Base_Time="$(TZ=${PTNA_TIMEZONE:-Europe/Berlin} date --date "$OLD_OSM_Base_Time" '+%Y-%m-%d %H:%M:%S %Z' | sed -e 's/ \([+-][0-9]*\)$/ UTC\1/')"

                    if [ "$NEW_OSM_Base_Time" = "$OLD_OSM_Base_Time" ]
                    then
                        # we analyzed the same XML data again, so every diff line counts
                        DIFF_LINES_BASE=0
                    fi

                    diff $WORK_LOC/$SAVE_FILE $WORK_LOC/$HTML_FILE > $WORK_LOC/$DIFF_FILE
                    DIFF_LINES=$(cat $WORK_LOC/$DIFF_FILE | wc -l)
                    echo $(date "+%Y-%m-%d %H:%M:%S") "Diff size:  " $(ls -l $WORK_LOC/$DIFF_FILE | awk '{print $5 " " $9}')
                    echo $(date "+%Y-%m-%d %H:%M:%S") "Diff lines: " $DIFF_LINES $WORK_LOC/$DIFF_FILE
                else
                    DIFF_LINES=$(($DIFF_LINES_BASE + 1))
                    rm -f $WORK_LOC/$DIFF_FILE
                fi

                if [ "$DIFF_LINES" -gt "$DIFF_LINES_BASE" ]
                then
                    echo $(date "+%Y-%m-%d %H:%M:%S")  "Copying '$WORK_LOC/$HTML_FILE' to '$RESULTS_LOC'"
                    cp $WORK_LOC/$HTML_FILE $RESULTS_LOC

                    if [ -n "$(which htmldiff.pl)" ]
                    then
                        if [ -f "$WORK_LOC/$SAVE_FILE" ]
                        then
                            htmldiff.pl -c $WORK_LOC/$SAVE_FILE $WORK_LOC/$HTML_FILE > $WORK_LOC/$DIFF_HTML_FILE
                        else
                            htmldiff.pl -c $WORK_LOC/$HTML_FILE $WORK_LOC/$HTML_FILE > $WORK_LOC/$DIFF_HTML_FILE
                        fi

                        echo $(date "+%Y-%m-%d %H:%M:%S") "Copying '$WORK_LOC/$DIFF_HTML_FILE' to '$RESULTS_LOC'"
                        cp $WORK_LOC/$DIFF_HTML_FILE $RESULTS_LOC

                        echo $(date "+%Y-%m-%d %H:%M:%S") "Updating analysis details file '$WORK_LOC/$DETAILS_FILE' old date = new"
                        echo "OLD_DATE_UTC=$NEW_OSM_Base_Time"       >> $WORK_LOC/$DETAILS_FILE
                        echo "OLD_DATE_LOC=$NEW_Local_OSM_Base_Time" >> $WORK_LOC/$DETAILS_FILE
                        echo "OLD_OR_NEW=new"                        >> $WORK_LOC/$DETAILS_FILE
                    else
                        echo $(date "+%Y-%m-%d %H:%M:%S") "no htmldiff.pl tool: no HTML-Diff Analysis page '$HTMLDIFF_FILE'"

                        echo $(date "+%Y-%m-%d %H:%M:%S") "Updating analysis details file '$WORK_LOC/$DETAILS_FILE' old date = empty"
                        echo "OLD_DATE_UTC="  >> $WORK_LOC/$DETAILS_FILE
                        echo "OLD_DATE_LOC="  >> $WORK_LOC/$DETAILS_FILE
                        echo "OLD_OR_NEW=old" >> $WORK_LOC/$DETAILS_FILE
                    fi
                else
                    echo $(date "+%Y-%m-%d %H:%M:%S") "No relevant changes on '$HTML_FILE'"

                    echo $(date "+%Y-%m-%d %H:%M:%S") "Updating analysis details file '$WORK_LOC/$DETAILS_FILE' old date = old"
                    echo "OLD_DATE_UTC=$OLD_OSM_Base_Time"       >> $WORK_LOC/$DETAILS_FILE
                    echo "OLD_DATE_LOC=$OLD_Local_OSM_Base_Time" >> $WORK_LOC/$DETAILS_FILE
                    echo "OLD_OR_NEW=old"                        >> $WORK_LOC/$DETAILS_FILE
                fi
            else
                echo $(date "+%Y-%m-%d %H:%M:%S") "Target location $RESULTS_LOC does not exist/could not be created"
            fi
        else
            echo $(date "+%Y-%m-%d %H:%M:%S") $WORK_LOC/$HTML_FILE is empty
            echo $(date "+%Y-%m-%d %H:%M:%S") $(ls -l $WORK_LOC/$HTML_FILE)
        fi
    else
        echo $(date "+%Y-%m-%d %H:%M:%S") $WORK_LOC/$HTML_FILE does not exist
    fi
fi

#
#
#

if [ "$pushroutes" = "true" ]
then
    if [ -n "$WIKI_ROUTES_PAGE" ]
    then
        if [ -f $WORK_LOC/$ROUTES_FILE ]
        then
            if [ -s $WORK_LOC/$ROUTES_FILE ]
            then
                echo $(date "+%Y-%m-%d %H:%M:%S") "Writing Routes file '$WORK_LOC/$ROUTES_FILE' to Wiki page '$WIKI_ROUTES_PAGE'"
                ptna-wiki-page.pl --push --page=$WIKI_ROUTES_PAGE --file=$WORK_LOC/$ROUTES_FILE --summary="update by PTNA"
            else
                echo $(date "+%Y-%m-%d %H:%M:%S") $WORK_LOC/$ROUTES_FILE is empty
            fi
        else
            echo $(date "+%Y-%m-%d %H:%M:%S") $WORK_LOC/$ROUTES_FILE does not exist
        fi
    else
        echo $(date "+%Y-%m-%d %H:%M:%S") "'$ROUTES_FILE' stored in GitHub"
    fi
fi

#
#
#

if [ "$pushtalk" = "true" ]
then
    if [ -n "$ANALYSIS_TALK" ]
    then
        if [ -f $WORK_LOC/$TALK_FILE ]
        then
            if [ -s $WORK_LOC/$TALK_FILE ]
            then
                echo $(date "+%Y-%m-%d %H:%M:%S") "Writing Analysis Talk file '$WORK_LOC/$TALK_FILE' to Wiki page '$ANALYSIS_TALK'"
                ptna-wiki-page.pl --push --page=$ANALYSIS_TALK --file=$WORK_LOC/$TALK_FILE --summary="update by PTNA"
            else
                echo $(date "+%Y-%m-%d %H:%M:%S") $WORK_LOC/$TALK_FILE is empty
            fi
        else
            echo $(date "+%Y-%m-%d %H:%M:%S") $WORK_LOC/$TALK_FILE does not exist
        fi
    fi
fi

#
#
#

if [ "$watchroutes" = "true" ]
then
    if [ -n "$WIKI_ROUTES_PAGE" ]
    then
        echo $(date "+%Y-%m-%d %H:%M:%S") "Setting 'watch' on Wiki page '$WIKI_ROUTES_PAGE'"
        ptna-wiki-page.pl --watch --page=$WIKI_ROUTES_PAGE
    else
        echo $(date "+%Y-%m-%d %H:%M:%S") "'$ROUTES_FILE' provided by GitHub"
    fi
fi

#
#
#

if [ "$watchtalk" = "true" ]
then
    if [ -n "$ANALYSIS_TALK" ]
    then
        echo $(date "+%Y-%m-%d %H:%M:%S") "Setting 'watch' on Wiki page '$ANALYSIS_TALK'"
        ptna-wiki-page.pl --watch --page=$ANALYSIS_TALK
    fi
fi




