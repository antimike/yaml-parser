#!/bin/bash
# Poor man's YAML parser and writer

if [ -f "$BASH_INCLUDE" ]; then
    source "$BASH_INCLUDE"
else
    echo "Could not find 'include.sh'" >&2
    exit 23
fi

_yaml_usage() {
    cat <<-USAGE
	
	$(_underline "${__YAML_NAME__}")
	
	$(_underline -c '-' -C options)
	    -h      Show this message and exit
	
	USAGE
    return 0
}

#######################################
## READER functions
#######################################

_get_yaml_from_text() {
    # PASS prelim
    sed -n '/---/,/\.\.\./p' <<< "$*" | sed -e '1d' -e '$d'
}

_get_yaml_from_file() {
    # PASS prelim
    # Gets YAML text between start-of-doc sigil "---" and end-of-doc "..."
    # Assumes one YAML doc per file
    local text="$(cat "$1")"
    if [ $? -eq 0 ]; then
        _get_yaml_from_text "$text"
    fi
    return $?
}

_get_yaml_from_files() {
    # PASS prelim
    # Gets YAML fragments from passed files and sticks them in a caller-provided
    # array
    local -n results="$1" && shift
    for file in "$@"; do
        results+=( "$(_get_yaml_from_file "$file")" )
    done
    return $?
}

_yaml_get_dict_elem_linenos_text() {
    # PASS prelim
    local yaml="$1"
    local keys="$2"     # Keystack (colon-delimited)
    local re=           # Loop var: regex to search for next key
    local -i current=1  # Loop var: tracks how far we've scanned into the YAML
    local -i offset=1   # Loop var: tracks the location of the next key relative
                        # to $current
    local -i retstat=0     # To break loop if necessary
    local indent=""     # Incremented on each loop pass
    debug_vars keys re current retstat
    while [[ -n "$keys" && "$retstat" -eq 0 ]]; do
        local keys="${keys#:}"        # Remove leading :
        local key="${keys%%:*}"       # Get leading key from stack
        local keys="${keys#${key}}"   # Remove leading key from stack
        local re="^${indent}\(- \)\{0,1\}${key}:"     # Possibly array elem
                                                # TODO: Lookup shorthand for
                                                # \{0,1\} in `grep`'s regex
                                                # syntax
        local nlines=$(wc -l <<< "$yaml")
        {
            offset=$(sed '1d' <<< "$yaml" | grep -n "$re" | 
                cut -f1 -d: | head -1) &&
            [ $offset -gt 0 ] &&    # $offset = 0 iff `grep` fails
            let current+=offset &&  # Does `let` suppress errors like `local`?
            yaml="$(sed -n "${offset},\$p" <<< "$yaml" | sed '1d')";
        } || let retstat=25
        indent+="  "
        debug_vars yaml offset keys re retstat current
    done
    (( current > nlines )) && let current=nlines
    local -i last=$(grep -n -v "^${indent}" <<< "$yaml" |
        cut -f1 -d: | head -1) 2>/dev/null
    debug_vars keys retstat yaml current
    if [ "${last}" -gt 0 ]
    then
        debug_vars last yaml
        # $last is the position of the first line **not belonging to** the
        # desired block.  The last line in the block is thus
        # (( current + (last - 1) - 1 ))
        echo "${current},$(( current + last - 2 ))"
    else
        echo "${current},\$"
    fi
    return $retstat
}

_yaml_get_dict_elem_linenos_file() {
    # PASS prelim
    local yaml="$(_get_yaml_from_file "$1")"
    if [ $? -eq 0 ]; then
        _yaml_get_dict_elem_linenos_text "$yaml" "$2"
    fi
    return $?
}

_yaml_get_dict_elem_from_file() {
    local yaml="$(_get_yaml_from_file "$1")"
    if [ $? -eq 0 ]; then
        _yaml_get_dict_elem_from_text "$yaml" "$2"
    fi
    return $?
}

_yaml_get_dict_elem_from_text() {
    # PASS prelim
    # Gets YAML elements associated to a dict key
    # Assumes the key is at the top level or in a top-level array
    local text="$1"
    local key="$2"
    local re="^\(${key}\|- ${key}\):"
    if [ -z "$key" ]; then
        echo "$text" && return 0
    elif grep "$re" <<< "$text" >/dev/null; then
        sed -n "/${re}/,/^[^[:space:]]/p" <<< "$text" |
            sed -e '/^  /!d' | sed -e 's/^  //'
    else
        return 1
    fi
}

_yaml_get_addr_elem_from_text() {
    # PASS prelim
    # Gets YAML element from key "address"
    # Assumes an address of the form "key1:key2:...:lastkey", where each key in
    # the list is directly below the previous one or is a member of an array
    # directly below the previous one
    local text="$1"
    local keys="$2"
    local key=
    local -i status=0
    debug_vars key keys
    while [ -n "$keys" ] && [ $status -eq 0 ]; do
        keys="${keys#:}"        # Remove leading :
        key="${keys%%:*}"       # Get leading key
        keys="${keys#${key}}"   # Remove leading key
        debug_vars text
        text="$(_yaml_get_dict_elem_from_text "$text" "$key")"
        debug_vars key keys text
        status=$?
    done
    echo "$text"
    return $status
}

_yaml_get_addr_elem_from_file() {
    # PASS prelim
    local yaml="$(_get_yaml_from_file "$1")"
    if [ $? -eq 0 ]; then
        _yaml_get_addr_elem_from_text "$yaml" "$2"
    fi
    return $?
}

#######################################
## WRITER functions
#######################################

_yaml_indent_text() {
    local -i level=1
    if [ "$1" = "-n" ]; then
        shift && level="$1" && shift ||
            return -1
    fi
    sed 's/^/  /' <<< "$*"
}

_yaml_print_array() {
    # PASS prelim
    # Prints all passed args as a top-level YAML array
    printf -- '- %s\n' "$@"
}

_yaml_print_bash_map() {
    # FAIL prelim
    local -n map="$1"
    debug_vars map
    for key in "${!map[@]}"; do
        printf '%s:\n%s\n' "$key" "$(sed 's/^/  /' <<< "${map[$key]}")"
    done
}

_yaml_substitute_file_contents() {
    # PASS prelim
    # Replaces all text between the YAML markers --- and ... with the passed
    # substitute text
    local file="$1"
    local yaml="$(sed 's/$/\\/' <<< "$2")"  # Escape newlines for sed
    sed -n -e 'p' -e "/---/eecho '$yaml'" -e '/---/ba' \
        -e ':a;/\.\.\./{p;b};$q1;n;ba' "$file"
}

_yaml_append_dict_elem_text() {
    local yaml="$1"
    local keys="$2"
    local append="$3"
    local existing=
}

_yaml_update_dict_elem_text() {
    # PASS prelim
    # NOTE: `local foo=$(bar baz)` will suppress failed return values from `bar
    # baz`.  `local foo= ; foo=$(bar baz);` should be used instead.
    local yaml="$1"
    local keys="$2"
    local subst="$3"
    local range=        # Wow, this is stupid :/
    range="$(_yaml_get_dict_elem_linenos_text "$yaml" "$keys")" ||
        return $?
    debug_vars yaml keys subst range
    local -i start=${range%%,*}
    local -i end=${range##*,}
    local indent="$(sed -n "${start}p" <<< "$yaml" |
        sed "s/^\(\s*\)[^\s].*$/\1/")"
    let start-=1    # We want to "append", not "insert" (because an insert
                    # requires addressing a line that may no longer exist)
    subst="$(sed "s/^/${indent}/" <<< "$subst")"
    debug "indent = '$indent'"
    debug_vars range start subst
    sed "${range}d" <<< "$yaml" | sed "${start}a\\${subst}" 2>/dev/null
    return $?
}

_yaml_update_dict_elem_file() {
    # PASS prelim
    local yaml="$(_get_yaml_from_file "$1")"
    if [ $? -eq 0 ]; then
        _yaml_update_dict_elem_text "$yaml" "$2" "$3"
    fi
    return $?
}

_yaml_insert_addr_elem_text() {
    # Inserts text at a given "address" in the passed YAML text
    local yaml="$1"
    local keys="$2"
    local key=
    local -i status=0
    debug_vars key keys
    while [ -n "$keys" ] && [ $status -eq 0 ]; do
        keys="${keys#:}"        # Remove leading :
        key="${keys%%:*}"       # Get leading key from stack
        keys="${keys#${key}}"   # Remove leading key from stack
        yaml="$(_yaml_insert_dict_elem_text "$yaml" "$key")"
        debug_vars key keys yaml
        status=$?
    done
    echo "$yaml"
    return $status
}

_yaml_insert_dict_elem_file() {
    # Inserts text at a given "address" in the passed YAML doc
    local file="$1" && shift
    local keys="$2" && shift
    
}

_yaml_addr_lookup() {
    # PASS prelim
    # Alias of _yaml_get_addr_elem_from_text
    # Gets YAML element from key "address"
    # Assumes an address of the form "key1:key2:...:lastkey", where each key in
    # the list is directly below the previous one or is a member of an array
    # directly below the previous one
    # Can also be used as a test of whether an address currently exists in a
    # YAML doc
    local text="$1"
    local keys="$2"
    local key=
    local -i status=0
    debug_vars key keys
    while [ -n "$keys" ] && [ $status -eq 0 ]; do
        keys="${keys#:}"        # Remove leading :
        key="${keys%%:*}"       # Get leading key
        keys="${keys#${key}}"   # Remove leading key
        debug_vars text
        text="$(_yaml_get_dict_elem_from_text "$text" "$key")"
        debug_vars key keys text
        status=$?
    done
    echo "$text"
    return $status
}

_yaml_addr_ensure() {
    local yaml="$1"
    local keys="$2"
    local new=
    until (_yaml_addr_lookup "$yaml" "$keys" >/dev/null); do
        :
    done
}

_yaml_addr_append() {
    :
}

_yaml_addr_set() {
    # Overwrites any text in the passed address with the passed substitute text
    # If the passed address does not yet exist, creates it
    # Recursive
    local yaml="$1"
    local keys="${2#:}"         # Remove leading colon
    local new="$3"
    local old=
    if [ -z "$yaml" ]; then     # Recursive base case
                                # (insert new chain of keys)
        debug "Recursive base case reached: empty YAML text"
        debug_vars yaml keys new old
        _yaml_update_dict_elem_text \
            "$(awk '
                BEGIN {RS=":"; indent="";}
                {printf "%s%s:\n", indent, $0; indent=indent"  ";}
                ' <<< "${keys}:")" "$keys" "$new"
    elif [ -z "$keys" ]; then   # Recursive base case
                                # (top-level insert)
        debug "Recursive base case reached: empty keychain"
        debug_vars yaml keys new old
        sed "$a\\${new}" <<< "$yaml"
    else
        local first="${keys%%:*}"
        local rest="${keys#${first}}"
        debug_vars yaml keys new old first
        if ! { old="$(_yaml_addr_lookup "$yaml" "$first")"; }; then
            debug "Address not found!  Recursing..."
            debug_vars yaml keys new old first
            sed "\$a\\$(_yaml_addr_set "" "$keys" "$new")" <<< "$yaml"
        else
            debug "Address found!  Recursing..."
            debug_vars yaml keys new old first rest
            _yaml_update_dict_elem_text \
                "$yaml" \
                "$first" \
                "$(_yaml_addr_set "$old" "$rest" "$new" 2>/dev/tty)"
        fi
    fi
    return $?
}

_yaml_addr_update() {
    # Same as _yaml_addr_set, except that it fails if the address does not exist
    :
}

#######################################
## main
#######################################

main() {
    if [ -n "${DEBUG+x}" ]; then
        if [ $# -gt 0 ]; then
            local func="$1" && shift
            $func "$@"
        else
            _yaml_usage
        fi
    fi
    exit $?
}

main "$@"
