#!/bin/bash
set -e
curl -fsS https://raw.githubusercontent.com/tidwall/pkg.sh/master/pkg.sh > /tmp/pkg.sh
chmod +x /tmp/pkg.sh
mv /tmp/pkg.sh /usr/local/bin/pkg.sh
