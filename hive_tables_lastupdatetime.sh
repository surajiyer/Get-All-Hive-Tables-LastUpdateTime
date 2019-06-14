#!/bin/bash
##
## Author: Suraj Iyer
## Description: Get last update time for all tables in all hive databases.
## Usage: bash ./hive_tables_lastupdatetime.sh -db "<database-name>" -s "/path/to/file"
## Parameters:
##  -db, --database: (Optional) Specific comma-separated database(s) to focus on. If not provided, it will go over all databases.
##  -s, --savepath: (Optional) Output file save path.
##  -dp, --dbpattern: (Optional) Regex pattern to filter database names out.
##  -tp, --tblpattern: (Optional) Regex pattern to filter tables names out.
##  -p, --parallel: (Optional) Number of parrallel cores to use for executing hive queries.
##

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
        -s|--savepath)
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
        while read data; do
            echo -e "$data" |& tee -a "$SAVEPATH"
        done
    else
        # read from passed argument
        echo -e "$1" |& tee -a "$SAVEPATH"
    fi
}

# Output file save path
if [ -z "$SAVEPATH" ]
then
    SAVEPATH="./hive-tables-lastUpdateDate-`date +'%Y-%m-%d-%T'`.csv"
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

# List of databases to check
if [ -z "$DATABASES" ]
then
    DATABASES=`hive -S -e 'show databases;'`
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
    echo "Database ${DB}"
    tables=`hive --hiveconf hive.root.logger=OFF --database ${DB} -S -e 'show tables;' | grep -E -v "$TABLENAMEREGEX"`
    if [ -n "$tables" ]
    then
        echo -E ${tables}\
            | xargs -n1 -i -P$PARALLEL sh -c "hive --hiveconf hive.root.logger=OFF -S -e 'show create table ${DB}.{};'\
                | egrep 'transient_lastDdlTime'\
                | sed 's/[^0-9]//g'\
                | xargs -i$ sh -c 'date -d @$ +'%Y-%m-%d-%H:%M:%S''\
                | xargs -i$ echo -e ${DB}.{},$"\
            | log
    fi
done