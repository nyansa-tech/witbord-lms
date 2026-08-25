# Witbord LMS

**Witbord** is a modern learning management system by
[Nyansa Technologies](https://nyansa.tech), built for multi-university
deployment. It is based on the open-source
[Canvas LMS](https://github.com/instructure/canvas-lms) project and remains
available under the AGPLv3 license.

In product and documentation, the product name is **Witbord**. Marketing may
refer to it as *Witbord by Nyansa Technologies*.

Repository: [nyansa-tech/witbord-lms](https://github.com/nyansa-tech/witbord-lms)

# Installation

For local development with Docker:

```bash
docker-compose up -d
docker-compose run --rm web bundle exec rake db:initial_setup
```

Then open [http://localhost:3000](http://localhost:3000)
(default admin: `admin@example.com` / `admin`).

More detail: [Developing with Docker](doc/docker/developing_with_docker.md)

# Upstream

Witbord is derived from Canvas LMS by Instructure Inc. Upstream project and
historical documentation:

- [Canvas LMS on GitHub](https://github.com/instructure/canvas-lms)
- [Canvas LMS wiki](https://github.com/instructure/canvas-lms/wiki)
