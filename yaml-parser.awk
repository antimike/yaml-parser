#!/bin/awk -f
# SUMMARY:
# A script to parse raw YAML input into an event stream suitable for consumption
# by a YAML composer (i.e., representation constructor).
#
# INVOKING THIS SCRIPT:
# For the shebang, one could also try `/usr/bin/env -S awk -f`.
# Unfortunately, both variants are, strictly speaking, non-portable.  The most
# palatable solution that is also fully portable seems to be to use `sed` to
# extract the `awk` script from its file and `exec` or `eval` it, as in:
# ```sh
# #!/bin/sh
# exec awk "$(sed '1,2d' "$0")" "$@"
#
# BEGIN { if (!len) len = 1; end = start + len }
# { for (i = start; i < end; i++) { print $1 } }
# ```
# See <https://stackoverflow.com/questions/1418245/invoking-a-script-which-has-an-awk-shebang-with-parameters-vars> for more info.
#
# PARSER SPECS:
# Per the YAML docs, the parser's job is to serialize an input stream to an
# **event stream**: An ordered, rooted tree with node aliasing.  Typing,
# tagging, and conversion of scalars to canonical forms need not be handled by
# the parser.
#
# Global state:
# - Parent node
# - Alias lookup table

