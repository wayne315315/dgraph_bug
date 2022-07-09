#!/bin/bash

dgraph live -a localhost:9080 -z localhost:5080 -s data/country.schema -f data -U xid -c 10 --verbose
