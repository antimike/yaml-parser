#!/bin/bash
# Credit for `parse_yaml`:
# https://stackoverflow.com/questions/5014632/how-can-i-parse-a-yaml-file-from-a-linux-shell-script

parse_yaml() {
    # Reads a YAML file and assigns Bash variables based on parsed values
    # TODO: Reimplement this to use Bash arrays and associative arrays
    # Can use variable names as values in associative arrays; `typeset -p` can
    # be used to determine when text should be dereferenced
    # Primary use-cases:
    # - Tags: Need to get a Bash array of tags from YAML file
    #       - Tags at arbitrary depth?
    #       - Special (i.e., non-YAML) syntax for tags?
    # - 
    local prefix=$2     # To prepend to variable names (useful for avoiding
                        # namespace conflicts)
    local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
    sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
    awk -F$fs '{
        indent = length($1)/2;
        vname[indent] = $2;
        for (i in vname) {if (i > indent) {delete vname[i]}}
        if (length($3) > 0) {
            vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
            printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
        }
    }'
}

write_yaml() {
    :
}
