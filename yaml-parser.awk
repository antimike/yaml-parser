#!/usr/bin/awk -f
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
# - Alias lookup table (?)

BEGIN {
    # Non-whitespace regex
    non_ws = "[^\\s]"
    # whitespace regex
    ws = "\\s"
    # Line-continuation regex
    line_cont = "\\|$"

    ORS="\013"      # Vertical tab
    s_tag="\002"    # "start of text"
    f_tag="\003"    # "end of text"
    header="\001"   # ASCII "header" char

    nodes["start"]=1000
    nodes["last"]=999
    prev=999
    indent=""

    # TODO: Add a mechanism for tracking "expected indent" of next line / node
    # (e.g., when a map key expects to be followed by a value at one level of
    # indentation higher)

    root = s_tag f_tag
}

# * Terminal nodes require indents over parents
# <root>@<nonterminals>|<terminal>
# Only nonterminals can have atomic (terminal) children

# Starting point:
# Case 1: - ...
#     Here, either push an "array" type nonterminal or verify that one exists
# Case 2: ... : ...
#     Push a "dict" nonterminal to P
#     Push a "KV" nonterminal Q
#     Push Q -> "key" -> (...)
#     Push Q -> "val" -> (...)

# Special chars:
#     * Terminals
#     * Nonterminals
#     * Reference

{
    # prev_level = level
    if ((level = match($0, /[^\s]/)) <= 0) {
        next
    }
    split(prev, ancestors, /[:\[]/)
    parent = ""
    for (idx = 1; idx < level; ++idx) {
        curr = ancestors[idx]
        parent = parent (curr ~ "]$" ? "[" : ":") curr
    }
    nodes[parent] = type

    # } else if (level < prev_level) {
    #     # Backtrack
    # } else if (level > prev_level) {
    #     # Child node
    #     parent = prev
    # }
    # prev = branch(node($0))
    # node_ids[++num_nodes]["id"] = prev["id"]
    # node_ids[++num_nodes]["level"] = level
}

function node(string) {
    # Node "constructor"
    # Elements:
    # - Serialized ID / address (suitable for printing)
    # - 
}

function branch(arr) {
    # Adds a node "struct" to the tree of previously-traversed nodes
}

# "struct" node:
# - type (scalar, key, value, item)
# - content
# - parent
# - birth_order (index of this node in parent's "children" sub-array)
# - nchildren
# - children, numerically-indexed (starting with 1001)
function add_node(type, content, parent) {
    # Adds a node "struct" to the nodes array (updating parent node as well)
    nodes[++nodes["last"], "type"]=type
    nodes[nodes["last"], "content"]=content
    nodes[nodes["last"], "parent"]=parent
    nodes[nodes["last"], "nchildren"]=0     # Technically this is not needed
    nodes[nodes["last"], "birth_order"]=++nodes[parent, "nchildren"]
    nodes[parent, 1000 + nodes[parent, "nchildren"]]=nodes["last"]
    return nodes["last"]
}

# High-level overview of algorithm:
# - Determine whether to set / increment nodestart
#   - If nodestart:
#       - Set indent
#       - Obtain parent node index
#       - Switch type based on metachars encountered:
#           - Array elem:
#               - Check parent node type == sequence
#                   - If map, fail
#                   - If unset, set
#                   - If atomic, change
#               - Add atomic node and set content with "expect" flag (?)
#           - Map elem:
#               - Check parent node type == map
#                   - If sequence, fail
#                   - If unset, set,
#                   - If atomic, change
#               - Add KV pair node
#                   - Add key subnode and set content
#                   - Add value subnode and set "expect" flag (?)
#           - Atomic:
#               - Check "expect" flags (?)
#                   - If no further content expected, fail?
#               - Create new node with type "atomic" and add raw content
#   - else:
#       - Consume metachars and set "expect" flags (?)
#       - Add raw content to curr node

function get_parent() {
    # Backtracks through previously-encountered nodes until one with a lower
    # indentation level than the current node is encountered
    # TODO: Implement
}

function indent_depth(text) {
    # Returns the indentation depth of a string
    # Not necessary; keeping for illustrative purposes
    # (use length(indent) in the script body)
    match(text, /^\(\s*\)[^\s]/)
    return (RLENGTH-1)/2
}
