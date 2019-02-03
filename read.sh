#!/bin/bash

elasticsearchUrl='http://localhost:9200'
index="fiscal_v1"

# Add index template
echo "Adding index template (fiscal_template.json): "
curl -XPUT "${elasticsearchUrl}/_template/fiscal_template" -H "Content-Type: application/json" -d @fiscal_template.json
echo
echo

# Add pipeline for ingesting csv data
echo "Adding pipeline for ingesting csv data (parse_fiscal_pipeline.json): "
curl -XPUT "${elasticsearchUrl}/_ingest/pipeline/parse_fiscal" -H "Content-Type: application/json" -d @parse_fiscal_pipeline.json
echo
echo

# Prompt to delete if index exists
status=$(curl -s -o /dev/null -I -w "%{http_code}" http://localhost:9200/${index})
if [[ $status != 404 ]]; then
	read -p "The index ${index} exists, do you want to delete and re-import the data? " -n 1 -r
	echo    # (optional) move to a new line
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		echo "Deleting index ${index}"
	    curl -XDELETE "${elasticsearchUrl}/${index}"
	    echo
	    echo
	else
		echo "Did not answer yes, exiting."
		exit 1
	fi
fi

# Add the index
echo "Adding index ${index}"
curl -XPUT "${elasticsearchUrl}/${index}"
echo
echo

dataFile="the_State_of_California_All_Fiscal_Years.csv"

# Grab the file if it doesn't exist - change this link if the data updates
if [ ! -f $dataFile ]; then
	echo "Downloading data file ${dataFile}"
	wget -O $dataFile "https://s3.amazonaws.com/og-datamanager-uploads/production/grid_data_api/dataset_exports/758c8a00-c9a0-4178-90c3-1cd6e99d72f8/csvs/original/fiscalca20181009-5604-1o2qb06_all.csv?1539124943"
	echo
fi

# Turn csv into bulk request format
echo "Processing csv into bulk request format - this may take a few minutes"
tail -n +2 $dataFile | sed -e 's/"/\\"/g' | xargs -d '\n' printf '{"index":{"_index":"'"$index"'","_type":"budget","pipeline":"parse_fiscal"}\n{"budget":"%s"}\n' > requests.jsonl

# Clean previous
rm -rf split
mkdir split

# Split file into chunks to bulk index
split -l 5000 requests.jsonl split/

# Submit file as a bulk indexing request to elastic using the parse_fiscal pipeline
echo "Indexing data file"
total=$(ls split | wc -l | bc)
i=0;
echo -ne "[#          ] 0/${total} (0%)\r"
for f in split/*
do
	i=$(($i+1))

	# Need to add a newline at the end of each file
	last=$(tail -n 1 $f)
	if [[ ! -z "${last}" ]]; then
		echo "" >> "${f}"
	fi

	mod=$((${i}%2))
	if [[ $mod != 0 ]]; then
 		curl -s -XPOST "http://localhost:9200/_bulk" -H "Content-Type: application/x-ndjson" --data-binary "@${f}" > /dev/null
 	else
 		curl -s -XPOST "http://localhost:9200/_bulk" -H "Content-Type: application/x-ndjson" --data-binary "@${f}" > /dev/null &
 	fi

	progress='#'
	ticks=$(printf "%.0f" $(bc <<< "scale=1; ${i}/${total}*10"))
	for ((j=0;j<10;j++)); do
		if (( $ticks > $j )); then progress="${progress}#"; else progress="${progress} "; fi
	done

	percent=$(printf "%.0f" $(bc <<< "scale=2; ${i}/${total}*100"))
	echo -ne "[${progress}] ${i}/${total} (${percent}%)\r"
done

rm -rf split
rm requests.jsonl

echo "Import complete"
