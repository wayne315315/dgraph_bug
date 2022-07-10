# Large data failed to commit on dgraph-v21.12.0 #
## What happened ##
The large data (eg. large geojson in our example) used to be written successfully on **dgraph-v21.03.2** somehow failed to commit on **dgraph-v21.12.0**
The root cause seems to be the combination of
* the introduction of ***Skiplist*** implementation on **dgraph-v21.12.0**.
* the fixed hardcorded value of ***badger.maxValSize = 1 << 20***

<br>**Note that the failure does not just limit to live loader, same failure happens to pydgraph imports**

## Environment ##
* **OS** : ```Ubuntu 18.04.2 LTS```
* **Dgraph Binary**
```
Dgraph version   : v21.12.0
Dgraph codename  : zion
Dgraph SHA-256   : 078c75df9fa1057447c8c8afc10ea57cb0a29dfb22f9e61d8c334882b4b4eb37
Commit SHA-1     : d62ed5f15
Commit timestamp : 2021-12-02 21:20:09 +0530
Branch           : HEAD
Go version       : go1.17.3
jemalloc enabled : true
```
* **Dgraph server**
```
num_alpha : 1
num_zero : 1
alpha_image : dgraph/dgraph:v21.12.0
zero_image : dgraph/dgraph:v21.12.0
ratel_image : dgraph/ratel:v21.12.0
```
## How to reproduce the error ##
#### Step 1 - Launch dgraph server with 1 alpha and 1 zero and 1 ratel ####
**`cd dgraph_bug && docker-compose up`**
#### Step 2 - Live load all files in data, which consists of the geojson of 2 countries Canada (CA) and Russia (RU) ####
**`dgraph live -a localhost:9080 -z localhost:5080 -s data/country.schema -f data -U xid -c 10 --verbose`** <br><br>
**Check you alpha log during importing, you should see some error like this <br>**
`alpha_1  | E0709 23:03:11.870728      20 mvcc.go:302] Invalid Entry. len(key): 36 len(val): 1096520`

#### Step 3 - Visit dgraph dashboard on `localhost:8000` and run the query below with \<id\> replaced by CA and RU respectively ####
You will see the `country.location` (geojson) on Russia is imported but ***NOT*** Canada.<br>
Run the same example on dgraph server with all images with tags of ***v21.03.2***, you will see both geojson are successfully imported
```
query foo()
{
  demo(func: type(Country))
  @filter(eq(id, <id>))
  {
    id
    name
    country.location
  }
}
```
## Possible cause ##
* The error seems to stem from the replacement of the function ***CommitToDisk*** with ***ToSkiplist*** in : https://github.com/dgraph-io/dgraph/blob/v21.12.0/posting/mvcc.go?plain=1#L276
* Large data can't pass **badger.ValidEntry** since the **maxValSize** in badger is fixed to ***1 << 20*** (i.e. ***1048576***) : https://github.com/dgraph-io/badger/blob/master/txn.go?plain=1#L362
* Error throws after passing the badger superflag 
**`dgraph alpha --my=alpha:7080 --security "whitelist=10.0.0.0/8,172.0.0.0/8,192.168.0.0/16" --zero=zero:5080 --badger "valuethreshold=2048576"`**
`alpha_1  | 2022/07/10 00:34:28 Invalid ValueThreshold, must be less or equal to 1048576`

***Hope there is a solution on importing large geojson data***
