#!/bin/bash
#
# Author: Suraj Iyer
# Description: Get last creation / alteration time for all tables in all hive databases.
# Usage: bash ./hive_tables_lastaltertime.sh -db "<database-name>" -s "/path/to/file"
# Parameters:
#  -db, --database: (Optional) Specific comma-separated database(s) to focus on. If not provided, it will go over all databases.
#  -o, --output: (Optional) Output file save path.
#  -dp, --dbpattern: (Optional) Regex pattern to filter database names out.
#  -tp, --tblpattern: (Optional) Regex pattern to filter tables names out.
#  -p, --parallel: (Optional) Number of parrallel cores to use for executing hive queries.
#  -S, --silent: (Optional) Run silently. Errors will NOT be outputted.
#

POSITIONAL=()
while [[ $# -gt 0 ]]
do
    key="$1"

    case $key in
        -db|--database)
        DATABASES=`echo "$2" | sed "s/,/\n/g"`
        shift # past argument
        shift # past value
        ;;
        -o|--output)
        SAVEPATH="$2"
        shift # past argument
        shift # past value
        ;;
        -dp|--dbpattern)
        DBNAMEREGEX="$2"
        shift # past argument
        shift # past value
        ;;
        -tp|--tblpattern)
        TABLENAMEREGEX="$2"
        shift # past argument
        shift # past value
        ;;
        -p|--parallel)
        PARALLEL="$2"
        shift # past argument
        shift # past value
        ;;
        -S|--silent)
        SILENT=true
        shift # past argument
        ;;
        *)    # unknown option
        POSITIONAL+=("$1") # save it in an array for later
        shift # past argument
        ;;
    esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

log()
{
    if [ -z $1 ]
    then
        # read from pipe
        if [ "$SILENT" = false ]
        then
            while read data; do
                echo -e "$data" |& tee -a "$SAVEPATH"
            done
        else
            while read data; do
                echo -e "$data" |& tee -a "$SAVEPATH" >/dev/null 2>&1
            done
        fi
    else
        # read from passed argument
        if [ "$SILENT" = false ]
        then
            echo -e "$1" |& tee -a "$SAVEPATH"
        else
            echo -e "$1" |& tee -a "$SAVEPATH" >/dev/null 2>&1
        fi
    fi
}

silenthive()
{
    args=("$@")
    if [ "$SILENT" = false ]
    then
        `hive "${args[@]}"`
    else
        `hive\
        --hiveconf hive.root.logger=OFF\
        "${args[@]}"` 2>/dev/null
    fi
}

# Output file save path
if [ -z "$SAVEPATH" ]
then
    SAVEPATH="./hive-tables-lastaltertime-`date +'%Y-%m-%d-%T'`.csv"
fi

# Regex pattern to exclude certain database names
if [ -z "$DBNAMEREGEX" ]
then
    # if not provided, then match any database name; database names cannot contain "-"
    DBNAMEREGEX="-"
fi

# Regex pattern to exclude certain table names
if [ -z "$TABLENAMEREGEX" ]
then
    # if not provided, then match any table name; table names cannot contain "-"
    TABLENAMEREGEX="-"
fi

# Run silently or not
if [ -z "$SILENT" ]
then
    SILENT=false
fi

# List of databases to check
if [ -z "$DATABASES" ]
then
    DATABASES=`silenthive -S -e 'show databases;'`
fi
DATABASES=`echo -e "$DATABASES" | grep -E -v "$DBNAMEREGEX"`

# Number of parrallel cores to use for executing hive queries
if [ -z "$PARALLEL" ]
then
    PARALLEL=1
fi

log "table,lastUpdateTime"
for DB in $DATABASES
do
    # print database name
    if [ "$SILENT" = false ]
    then
        echo "Database ${DB}"
    fi

    # store all table names from DB within tables (also apply filtering based on regex pattern)
    tables=`silenthive --database ${DB} -S -e 'show tables;' | grep -E -v "${TABLENAMEREGEX}"`

    # if tables exists within database, ...
    if [ -n "$tables" ]
    then
        ###############################################
        ## 1. Echo all tables into a pipe.
        ## 2. Process each table separately (optionally in parallel). Get table info (show create).
        ## 3. Search for line with transient_lastDdlTime value.
        ## 4. Extract last alteration unix timestamp from line with regex.
        ## 5. Convert timestamp to datetime formatted string.
        ## 6. log to output file and repeat process for each table.
        ###############################################
        echo -E ${tables}\
            | xargs -n1 -i -P$PARALLEL sh -c "silenthive -S -e 'show create table ${DB}.{};'\
                | egrep 'transient_lastDdlTime'\
                | sed 's/[^0-9]//g'\
                | xargs -i$ sh -c 'date -d @$ +'%Y-%m-%d-%H:%M:%S''\
                | xargs -i$ echo -e ${DB}.{},$"\
            | log
    fi
done