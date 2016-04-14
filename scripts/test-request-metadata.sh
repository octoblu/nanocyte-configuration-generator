#!/bin/sh
SERVER="meshblu.octoblu.com:443"

meshblu-util register -s $SERVER > ../tmp/meshblu-searcher.json

WANTS_METADATA_UUID=$(meshblu-util register -o -s $SERVER -f ./request-metadata.json | jq '.uuid')
echo $WANTS_METADATA_UUID

NO_METADATA_UUID=$(meshblu-util register -o -s $SERVER -f ./no-metadata.json | jq '.uuid')
echo $NO_METADATA_UUID

QUERY="{\"uuid\": {\"\$in\": [$WANTS_METADATA_UUID, $NO_METADATA_UUID]}, \"octoblu.flow.forwardMetadata\": true}"

echo "meshblu-util search -q '$QUERY' ../tmp/meshblu-searcher.json"
