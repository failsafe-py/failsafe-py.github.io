#!/bin/sh
# Jekyll runs in a container: system Ruby is 2.6 and cannot build modern Jekyll,
# and nothing is installed into the system or home gem paths.
set -e
cd "$(dirname "$0")/.."
exec docker run --rm -it \
  -v "$PWD:/srv/jekyll" \
  -v "$PWD/.bundle-cache:/usr/local/bundle" \
  -p 4000:4000 \
  jekyll/jekyll:4 \
  sh -c "bundle install && bundle exec rake search:init && bundle exec jekyll serve --host 0.0.0.0 --livereload"
