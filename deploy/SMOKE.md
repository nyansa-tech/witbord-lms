# Production smoke test

Run after `first_boot.sh` and Cloudflare DNS are live.

## 1. Health

```bash
curl -sI https://learn.witbord.com/login | head -5
# Expect HTTP/2 200 (or 302 to login)
```

## 2. Login

1. Open `https://learn.witbord.com/login`
2. Sign in with `CANVAS_LMS_ADMIN_EMAIL` / password from `deploy/.env`
3. Confirm branding: Witbord name, green theme, Nyansa footer link

## 3. Branding rake (if not already)

```bash
cd /opt/witbord-lms
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env run --rm \
  -e RAILS_ENV=production \
  web bundle exec rake witbord:setup
```

## 4. File upload (S3)

1. Create a course → upload a small PDF/image
2. Confirm object appears in `s3://witbord-files-prod/`
3. Confirm the file downloads via Witbord UI

## 5. Email (SES)

```bash
# From Rails console in web container
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env run --rm \
  -e RAILS_ENV=production \
  web bundle exec rails runner 'Message.create!(...)' 
```

Or trigger “Forgot password” for a verified recipient (sandbox) / any recipient (production SES).

Check SES → Sending statistics for bounces.

## 6. Jobs

```bash
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env ps
# web, jobs, postgres, redis, nginx should be Up
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env logs jobs --tail 50
```

## 7. Cross-links

- LMS footer / help → `https://nyansa.tech`
- Nyansa site CTAs → `https://learn.witbord.com`

## 8. Vanity school host (optional)

```bash
# After creating a school + theme:
SCHOOL_NAME='KNUST' SUBDOMAIN=knust bundle exec rake witbord:set_vanity
```

1. Open `https://knust.witbord.com/login` (wildcard DNS + origin cert required)
2. Confirm that school’s theme (not the root Witbord theme)
3. `learn.witbord.com/login` still shows the root theme

## Pass criteria

- [ ] HTTPS login works
- [ ] Admin can open `/accounts/1`
- [ ] Upload lands in S3
- [ ] Email sends (or queued without SMTP errors)
- [ ] `jobs` container processing without crash loop
- [ ] (If enabled) school vanity login shows school theme
