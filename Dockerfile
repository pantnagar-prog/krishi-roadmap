# ---------------------------------------------------------------------------
# Uttarakhand Krishi Roadmap — static single-page site
#
# The site is plain HTML/CSS/JS, so there is nothing to compile. We copy the
# static assets into a minimal nginx image and serve them. The result is a
# ~50 MB image containing nginx and the site, and nothing else.
#
#   Build:  docker build -t krishi-roadmap:latest .
#   Run:    docker run --rm -p 8080:8080 krishi-roadmap:latest
#   Visit:  http://localhost:8080
#
# If this ever grows a build step (npm, Hugo, Tailwind...), add a first stage
# here that produces the files, and COPY --from=build into the runtime stage.
# ---------------------------------------------------------------------------

FROM nginx:1.27-alpine

LABEL org.opencontainers.image.title="Uttarakhand Krishi Roadmap" \
      org.opencontainers.image.description="Front page for the Government of Uttarakhand's Krishi Roadmap"

# Our own server config: gzip, cache headers, security headers, /healthz.
# Replaces the stock default.conf that listens on port 80.
COPY nginx.conf /etc/nginx/conf.d/default.conf

# The site itself. Files are listed explicitly so nothing stray can sneak in.
COPY index.html   /usr/share/nginx/html/
COPY UK-logo.png  /usr/share/nginx/html/

# nginx:alpine ships an unprivileged `nginx` user. Run as it instead of root.
# The stock image expects root to own the pid file and cache dirs, so hand
# those over first. (This is also why the config listens on 8080, not 80 —
# a non-root process cannot bind ports below 1024.)
RUN touch /var/run/nginx.pid \
 && chown -R nginx:nginx /var/run/nginx.pid /var/cache/nginx /usr/share/nginx/html

USER nginx

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://127.0.0.1:8080/healthz || exit 1

CMD ["nginx", "-g", "daemon off;"]
