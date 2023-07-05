# TeslaEnergyGateway

Monitors my Tesla Energy Gateway from the command line. Makes noise when production stops or starts, and alerts in Slack. Also sends informational messages to Slack every 15 minutes and indexes the data into Elasticsearch.

```bash
export GW_PWD='password'
export GW_SLACK='webhookurl'
export GW_ES_URL='elasticapiurl'
export GW_ES_API_KEY='elasticapikey'
ruby stats.rb
```
