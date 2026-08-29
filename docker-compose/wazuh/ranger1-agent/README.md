# Wazuh Agent for ranger1

Docker-based Wazuh agent for **ranger1** reporting to the Wazuh manager on **endurance** (192.168.5.30).

## Configuration

- **Manager Address**: 192.168.5.30 (endurance)
- **Manager Port**: 11514 (agent communication)
- **Enrollment Port**: 11515 (agent registration)
- **Agent Name**: ranger1
- **Logging**: Syslog to 192.168.5.16:514 (Graylog)

## Deployment

### Prerequisites

1. Docker and Docker Compose installed on ranger1
2. Network connectivity to endurance (192.168.5.30) on ports 11514 and 11515

### Deploy

```bash
# Navigate to the agent directory
cd /path/to/wazuh-agent

# Start the agent in background
docker compose up -d

# Verify the agent is running
docker compose logs -f
```

### Verify Registration

From **endurance**, verify the agent is registered:

```bash
TOKEN=$(curl -sk -u wazuh-wui:'<API_PASSWORD>' -X POST "https://localhost:55000/security/user/authenticate" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['token'])")
curl -sk -H "Authorization: Bearer $TOKEN" "https://localhost:55000/agents?pretty=true" | python3 -c "
import sys, json
for a in json.load(sys.stdin)['data']['affected_items']:
    print(f\"{a['id']}  {a['name']}  {a['status']}  {a.get('ip','?')}\")"
```

The agent should appear with status `active` within 30 seconds.

## Monitoring

- **Dashboard**: https://192.168.5.30/
- **Wazuh API**: https://192.168.5.30:55000
- **Logs**: Streamed to Graylog at 192.168.5.16:514 with tag `wazuh-agent-ranger1`

## Troubleshooting

### Check agent logs

```bash
docker compose logs -f wazuh.agent
```

### Verify connectivity to manager

```bash
docker compose exec wazuh.agent bash
# Inside container:
ping 192.168.5.30
curl -v telnet://192.168.5.30:11514
```

### Restart the agent

```bash
docker compose restart wazuh.agent
```
