# SSL / TLS Certificate Expiry Monitor (`cert-monitor`)

A lightweight Bash script that checks live TLS certificates over port `443` using `openssl` and dispatches multi-channel alerts (Mobile Push, Slack, Discord, Telegram, WhatsApp, Email) via [AlertHub](https://alerthub.io) before they expire.

> Read the full walkthrough: **[How to Never Miss a Domain or SSL Certificate Renewal](https://alerthub.io/guides/never-miss-domain-ssl-renewal)**

## Features

- **SNI-Aware Checks:** Uses `openssl s_client -servername` so it inspects the exact certificate served behind Nginx, reverse proxies, CDNs, and shared load balancers.
- **Tiered Urgency:**
  - **14 days or fewer (configurable):** Sends a `warning` (`medium` priority) alert.
  - **3 days or fewer:** Escalates to an `error` (`high` priority) urgent alert.
  - **Unreachable / Handshake Failure:** Immediately triggers an `error` (`high` priority) alert if port `443` fails to return a valid certificate.
- **Minimal Dependencies:** Uses standard Linux utilities (`bash`, `openssl`, `curl`, `python3`, and GNU `date`)—no background daemons or third-party runtimes required.

## Quick Install

Download the script into `/usr/local/bin` and make it executable:

```bash
sudo curl -fsSL [https://raw.githubusercontent.com/alerthubio/examples/main/cert-monitor/check-ssl-expiry.sh](https://raw.githubusercontent.com/alerthubio/examples/main/cert-monitor/check-ssl-expiry.sh) \
  -o /usr/local/bin/check-ssl-expiry.sh && sudo chmod +x /usr/local/bin/check-ssl-expiry.sh
```

## Configuration

### 1. Add Your Domains

Open `/usr/local/bin/check-ssl-expiry.sh` and list the domains you want to monitor in the `DOMAINS` array:

```bash
DOMAINS=(
  "example.com"
  "api.example.com"
  "status.example.com"
)
```

### 2. Environment Variables

| Variable | Required | Default | Description |
| :--- | :--- | :--- | :--- |
| `ALERTHUB_USER_ID` | Yes | — | Your AlertHub User ID (found in your dashboard settings). |
| `ALERTHUB_API_KEY` | Yes | — | Your AlertHub API key (`X-API-KEY`). |
| `WARN_DAYS` | No | `14` | Number of days before expiration to trigger a `warning` alert. |

To keep credentials out of your crontab, store them in a root-readable environment file such as `/etc/alerthub.env`:

```bash
sudo tee /etc/alerthub.env > /dev/null << 'EOF'
ALERTHUB_USER_ID=your_user_id
ALERTHUB_API_KEY=your_api_key
WARN_DAYS=14
EOF

sudo chmod 600 /etc/alerthub.env
```

## Usage & Cron Setup

### Test Manually

Run the script in your terminal to verify your configuration:

```bash
set -a && source /etc/alerthub.env && set +a
/usr/local/bin/check-ssl-expiry.sh
```

*(Note: The script produces no output when all certificates have more than `WARN_DAYS` remaining.)*

### Schedule Daily via Cron

Open your crontab (`crontab -e`) and schedule the check to run every morning at `08:30 UTC`:

```crontab
30 8 * * * set -a && . /etc/alerthub.env && set +a && /usr/local/bin/check-ssl-expiry.sh
```

## Example Alert Payload

When a certificate approaches expiration or fails validation, the script sends a `POST` request to `https://alerthub.io/api/event/{ALERTHUB_USER_ID}`:

```json
{
  "title": "SSL expires in 9 days: example.com",
  "body": "Live TLS certificate for example.com expires on Nov 26 12:00:00 2026 GMT. Auto-renewal may have stalled.",
  "status": "warning",
  "priority": "medium",
  "source": "cert-monitor"
}
```

## Resources

- **Full Guide:** [How to Never Miss a Domain or SSL Certificate Renewal](https://alerthub.io/guides/never-miss-domain-ssl-renewal)
- **API Documentation:** [alerthub.io/docs](https://alerthub.io/docs)
- **Create a Free Account:** [alerthub.io](https://alerthub.io)
