# Get-All-Hive-Tables-LastUpdateTime

Bash script to get the last update time of all hive tables.

Input:  
- **-db, --database**: (Optional) Specific comma-separated database(s) to focus on. If not provided, it will go over all databases.  
- **-s, --savepath**: (Optional) Output file save path.
- **-dp, --dbpattern**: (Optional) Regex pattern to filter database names out.
- **-tp, --tblpattern**: (Optional) Regex pattern to filter tables names out.
- **-p, --parallel**: (Optional) Number of parrallel cores to use for executing hive queries.

Output:  
CSV file containing two columns 'table' (table name) and 'lastUpdateTime' (datetime string).

Example use:

1. Run `bash ./hive_tables_lastupdatetime.sh -s "./output.csv"` in a terminal on the AAP platform to get last update time for all tables in all databases on AAP.
2. Run `bash ./hive_tables_lastupdatetime.sh -db "customer_interactions" -s "./output.csv"` to get last update time of all tables in the customer interactions database on AAP.
3. Run `bash ./hive_tables_lastupdatetime.sh -db "customer_interactions"` to save the output to an automatically generated file name such as "hive-tables-lastUpdateDate-2019-06-14-11:39:24.csv" saved within the working directory of the script.
4. Run `bash ./hive_tables_lastupdatetime.sh -dp "tmp"` to filter out databases which contain the keyword "tmp".
5. Run `bash ./hive_tables_lastupdatetime.sh -db "customer_interactions" -tp "tmp"` to filter out tables from customer interactions database which contain the keyword "tmp".
6. Run `bash ./hive_tables_lastupdatetime.sh -p "6"` to query up to 6 tables per database in parallel.