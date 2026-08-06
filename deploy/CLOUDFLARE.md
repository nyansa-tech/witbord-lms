# Cloudflare for Witbord LMS (`witbord.com`)

## Zone setup

1. Add site **witbord.com** to Cloudflare
2. Change nameservers at the registrar to Cloudflare’s
3. SSL/TLS mode: **Full (strict)**
4. Always Use HTTPS: On
5. Minimum TLS: 1.2

## Origin certificate (EC2 nginx)

1. SSL/TLS → **Origin Server** → **Create Certificate**
2. Hostnames: `learn.witbord.com`, `*.witbord.com`, `witbord.com`
3. Save as:
   - `deploy/certs/origin.pem`
   - `deploy/certs/origin.key`
4. Restart nginx:  
   `docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env up -d nginx`

## DNS records

| Type | Name | Content | Proxy |
|------|------|---------|-------|
| A | `learn` | `<EC2 Elastic IP>` | Proxied (orange cloud) |
| A | `*` | `<EC2 Elastic IP>` | Proxied (school vanity hosts) |
| A or CNAME | `@` | (see redirect) | Proxied |
| CNAME | `www` | `witbord.com` | Proxied |

> **Wildcard SSL:** On Cloudflare Free, edge certs cover `learn.witbord.com` and similar; for full `*.witbord.com` coverage use **Advanced Certificate Manager** or Cloudflare’s paid Universal SSL wildcard. Origin certificate should include `*.witbord.com` and `learn.witbord.com`.

## School vanity hosts (Phase 2)

Example: `knust.witbord.com` → same Witbord app, **KNUST school theme on the login page**.

1. Cloudflare: wildcard `*` A record (above)
2. Origin cert SANs: `learn.witbord.com`, `*.witbord.com`
3. Nginx already uses `server_name learn.witbord.com *.witbord.com;`
4. Map the school:

```bash
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env run --rm \
  -e RAILS_ENV=production \
  -e SCHOOL_NAME='KNUST' \
  -e SUBDOMAIN=knust \
  web bundle exec rake witbord:set_vanity
```

5. In Admin → that school → **Themes**, set logo/colors (requires sub-account themes; enabled by `witbord:setup`)
6. Open `https://knust.witbord.com/login` — should show that school’s branding
7. List mappings: `rake witbord:list_vanity`

Reserved subdomains (not treated as schools): `www`, `learn`, `app`, `api`, `files`, `mail`, …

See also [`VANITY_DOMAINS.md`](VANITY_DOMAINS.md).


## Redirects

**Rules** → **Redirect Rules** (or Bulk Redirects):

1. `https://witbord.com/*` → `https://learn.witbord.com/$1` (301)
2. `https://www.witbord.com/*` → `https://learn.witbord.com/$1` (301)

## Cache

- Create a Cache Rule: **Bypass cache** for `learn.witbord.com` path `*` initially (safest for LMS)
- Later: cache `/dist/*` with long TTL if you fingerprint assets

## WAF (basic)

- Enable managed free WAF ruleset
- Rate limit `/login*` if you see brute force attempts

## Email DNS for SES (on this zone)

After SES domain verification, add the CNAME/TXT records AWS shows for DKIM and SPF/DMARC, for example:

- SPF TXT on `@`: `v=spf1 include:amazonses.com ~all`
- DMARC TXT on `_dmarc`: `v=DMARC1; p=none; rua=mailto:admin@witbord.com`

## Checklist

- [ ] `learn.witbord.com` resolves via Cloudflare
- [ ] Browser shows valid HTTPS (Cloudflare edge cert)
- [ ] Origin cert installed; Full (strict) does not 526
- [ ] Apex/www redirect to learn
- [ ] Login page loads at `https://learn.witbord.com/login`
- [ ] (Phase 2) `*` A record + `*.witbord.com` on origin cert
- [ ] (Phase 2) School vanity login branded after `witbord:set_vanity`
