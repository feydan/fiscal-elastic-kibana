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

# Submit each line as an indexing request to elastic using the parse_fiscal pipeline
echo "Indexing data file, this could take several hours"
total=$(wc -l < ${dataFile} | bc)
i=0;
requests=''
while read f1; do
	i=$(($i+1))

	# Skip the header line
	if [[ $i == 1 ]]; then 
		echo -ne "[#          ] 0/${total} (0%)\r"
		continue; 
	fi

	# Escapes quotes
	f1=$(echo $f1 | sed 's/\"/\\\"/g');

	# Bulk indexing request have an action and a doc
	action=$(printf '{"index":{"_index":"%s","_type":"budget","pipeline":"parse_fiscal"}' "$index")
	doc=$(printf '{"budget":"%s"}' "$f1")

	# Build the bulk request
	requests=$(printf '%s\n%s\n%s' "$requests" "$action" "$doc")

	# If we are not at our payload continue
	mod=$((${i}%100))
	if [[ $mod != 0 ]]; then
		continue;
	fi

	# Make the bulk request
	curl -s -XPOST "http://localhost:9200/_bulk" -H "Content-Type: application/x-ndjson" -d "${requests}
" > /dev/null
	# Reset requests
	requests=''

	progress='#'
	ticks=$(printf "%.0f" $(bc <<< "scale=1; ${i}/${total}*10"))
	for ((j=0;j<10;j++)); do
		if (( $ticks > $j )); then progress="${progress}#"; else progress="${progress} "; fi
	done

	percent=$(printf "%.0f" $(bc <<< "scale=2; ${i}/${total}*100"))
	echo -ne "[${progress}] ${i}/${total} (${percent}%)\r"
done < $dataFile

# Submit final payload
if [[ $requests != '' ]]; then
	# Make the bulk request
	curl -s -XPOST "http://localhost:9200/_bulk" -H "Content-Type: application/x-ndjson" -d "${requests}
" > /dev/null
fi

echo "Import complete"
