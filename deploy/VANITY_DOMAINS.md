# School vanity domains (`knust.witbord.com`)

Phase 2: Cloudflare wildcard + app middleware that brands the **login page** from the school sub-account.

## How it works

```text
knust.witbord.com
        │
        ▼
 Cloudflare (*.witbord.com) ──► nginx ──► Canvas
        │
        └── WitbordVanityHost middleware
              └── finds Account with vanity_subdomain=knust
              └── login/logged-out pages use that account's Theme
```

- Still **one** Witbord root account and database
- After login, normal Canvas permissions apply (school admin / teacher / student)
- `learn.witbord.com` stays the main portal (no school branding override)

## Setup checklist

1. Cloudflare wildcard DNS + SSL (see [`CLOUDFLARE.md`](CLOUDFLARE.md))
2. Origin certificate includes `*.witbord.com`
3. Enable sub-account themes (done by `rake witbord:setup`)
4. Create the school sub-account
5. Assign subdomain:

```bash
SCHOOL_NAME='KNUST' SUBDOMAIN=knust bundle exec rake witbord:set_vanity
```

6. Theme the school: **Admin → KNUST → Themes**
7. Visit `https://knust.witbord.com/login`

## Name fallback

If `vanity_subdomain` is not set, middleware also matches a **slug of the account name**:

- `Achimota School` → `achimota-school.witbord.com`

Prefer an explicit `SUBDOMAIN` for short URLs like `knust`.

## Local testing

```bash
# /etc/hosts
127.0.0.1 knust.localhost learn.localhost

# Allow host
ADDITIONAL_ALLOWED_HOSTS=knust.localhost,learn.localhost

# domain.yml development domain should end with a base you can nest under,
# or temporarily set HostUrl.default_host to learn.witbord.com in console tests.
```

For Docker local, easiest check is a request with Host header:

```bash
curl -sH "Host: knust.witbord.com" http://localhost:3000/login/canvas | head
```

(Requires `HostUrl.default_host` / domain config whose base is `witbord.com`.)

## Ops commands

| Task | Command |
|------|---------|
| Map school | `SCHOOL_NAME='…' SUBDOMAIN=… rake witbord:set_vanity` |
| List maps | `rake witbord:list_vanity` |
