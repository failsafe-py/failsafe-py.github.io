#!/bin/sh
# Build into _site/. Same container, no local Ruby.
set -e
cd "$(dirname "$0")/.."
exec docker run --rm \
  -v "$PWD:/srv/jekyll" \
  -v "$PWD/.bundle-cache:/usr/local/bundle" \
  jekyll/jekyll:4 \
  sh -c "bundle install && bundle exec rake search:init && bundle exec jekyll build ${JEKYLL_ARGS}"
