# Copyright (C) 2022-2023 CachyOS team
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#!/usr/bin/env bash

BEGIN { syncopated = 0; syncopated_v3 = 0; err = 1 }
{
  if ($0 == "[options]") {
    print;
    next;
  } else if ($0 == "[syncopated]") {
    syncopated = 1;
  } else if ($0 == "[syncopated-v3]") {
    syncopated_v3 = 1;
  } else if ($0 == "Architecture = x86_64" || $0 == "Architecture = x86_64 x86_64_v3" || $0 == "Architecture = x86_64 x86_64_v3 x86_64_v4") {
    print "Architecture = auto";
    next;
  }

  if (rm) {
    rm--;
    next;
  }
}

/^\[[^ \[\]]+\]/ {
  if (!syncopated) {
    print "[syncopated]";
    print "SigLevel = Optional TrustAll";
    print "Server = http://bender.syncopated.net/syncopated/repo/x86_64/";
    print "";
    syncopated = 1;
    err = 0;
  }

  if (!syncopated_v3) {
    print "[syncopated-v3]";
    print "SigLevel = Optional TrustAll";
    print "Server = http://bender.syncopated.net/syncopated/repo/x86_64_v3/";
    print "";
    syncopated_v3 = 1;
    err = 0;
  }
}
END {exit err}
1

# vim:set sw=2 sts=2 et:
