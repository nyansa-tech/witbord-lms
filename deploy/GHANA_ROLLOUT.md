# Ghana rollout — Phase 1 (universities pilot)

One Witbord root account, **one Postgres database**, school isolation via Canvas **sub-accounts**. Branded login via vanity hosts (`knust.witbord.com`). See [VANITY_DOMAINS.md](VANITY_DOMAINS.md).

## Account tree

```text
Witbord (root)
├── Universities
│   ├── KNUST              → knust.witbord.com
│   ├── University of Ghana → ug.witbord.com
│   ├── University of Cape Coast → ucc.witbord.com
│   ├── Ashesi University  → ashesi.witbord.com
│   └── University of Education, Winneba → uew.witbord.com
├── Senior High Schools
│   └── (16 region folders — empty; add SHS later)
└── Private Schools
    └── (empty container)
```

Data for all schools lives in the **same database**. Permissions and courses are scoped by sub-account — not separate DBs.

## Seed on production

After deploy (image includes latest rake tasks):

```bash
cd /opt/witbord-lms
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env exec -T \
  -e RAILS_ENV=production web \
  bundle exec rake witbord:seed_ghana
```

`rake witbord:setup` (used by `first_boot.sh`) already calls `seed_ghana` after branding.

Idempotent: safe to re-run. Does **not** delete legacy sample schools under root-level region folders; prefer the new `Universities` / `Senior High Schools` tree.

List vanity maps:

```bash
docker compose -f deploy/docker-compose.prod.yml --env-file deploy/.env exec -T \
  -e RAILS_ENV=production web \
  bundle exec rake witbord:list_vanity
```

## Cloudflare

1. Wildcard DNS `*.witbord.com` → Elastic IP ([CLOUDFLARE.md](CLOUDFLARE.md))
2. Origin certificate must include `*.witbord.com`
3. Visit `https://knust.witbord.com/login` (etc.)

`learn.witbord.com` remains the main portal (no school theme override).

## Per-university checklist

1. Seed tree (above)
2. **Admin → Universities → [School] → Themes** — school logo/colors for vanity login
3. Create a school admin under that sub-account (Account Admins)
4. Courses / enrollments (manual or SIS CSV later)
5. Optional: school-specific auth later

## Add the next school

**Another university:**

```bash
# PARENT can be the sector account name
SCHOOL_NAME='Ghana Communication Technology University' PARENT='Universities' \
  bundle exec rake witbord:add_school

SCHOOL_NAME='Ghana Communication Technology University' SUBDOMAIN=gctu \
  bundle exec rake witbord:set_vanity
```

**First SHS** (under a region):

```bash
SCHOOL_NAME='Achimota School' PARENT='Greater Accra Region' \
  bundle exec rake witbord:add_school

SCHOOL_NAME='Achimota School' SUBDOMAIN=achimota \
  bundle exec rake witbord:set_vanity
```

(On EC2, prefix with `docker compose … exec -T -e RAILS_ENV=production web`.)

## Capacity

| Phase | Infra |
|-------|--------|
| Pilot universities (this phase) | Current single `t3.xlarge` + on-box Postgres is enough |
| Nationwide SHS | Plan scale-out (larger instance / RDS / jobs capacity) **before** bulk import |

## Out of scope (later)

- MoE / SIS bulk feeds
- Self-service school registration
- DB-per-school or sharding
