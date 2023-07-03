# TeslaEnergyGateway

Monitors my Tesla Energy Gateway from the command line. Makes noise when production stops or starts, and alerts in Slack. Also sends informational messages to Slack every 15 minutes.

```bash
export GW_PWD='password'
export GW_SLACK='webhookurl'
ruby stats.rb
```
