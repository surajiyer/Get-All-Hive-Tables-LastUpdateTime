#!/bin/bash
##
## Author: Suraj Iyer
## Description: Get last update time for all tables in all hive databases.
## Usage: bash ./hive_tables_lastupdatetime.sh -db "<database-name>" -s "/path/to/file"
## Parameters:
##  -db, --database: Optional specific comma-separated database(s) to focus on. If not provided, it will go over all databases.
##  -s, --savepath: Output file save path.
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
if [ -z $SAVEPATH ]
then
    SAVEPATH="./hive-tables-lastUpdateDate-`date +'%Y-%m-%d-%T'`.csv"
fi

# List of databases to check
if [ -z $DATABASES ]
then
    DATABASES=`hive -S -e 'show databases;'`
fi

log "table,lastUpdateTime"
for DB in $DATABASES
do
    # echo "Database $DB"
    hive --hiveconf hive.root.logger=OFF --database $DB -S -e 'show tables;' | xargs -n1 -i -P6 sh -c "hive --hiveconf hive.root.logger=OFF -S -e 'show create table $DB.{};' | egrep 'transient_lastDdlTime' | sed 's/[^0-9]//g' | xargs -i$ sh -c 'date -d @$ +'%Y-%m-%d-%H:%M:%S'' | xargs -i$ echo -e $DB.{},$" | log
done