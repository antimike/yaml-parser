# YAML Parser

## Summary
Tools for parsing and writing YAML configuration files and frontmatter with minimal dependencies (Bash).

## Design goals
* Extensible and hackable syntax:
    * Should be easy to modify the already-implemented syntax constructs and to add new ones
* Plugin-compatible:
    * Should support a simple, conventions-based plugin architecture
* Portable:
    * A primary use-case is on fresh Linux installations, to help manage system "onboarding" and configuration
* Minimal dependencies:
    * Can rely on Bash 4.XX, git, GNU awk / sed
* Unobtrusive:
    * Should be intuitive and easy to use, supporting complex constructs only when they feel natural or are required

## Specs

### Basic
* Support conversion to / from Bash arrays and associative arrays
* Extract subtrees at arbitrary "addresses":
    * DSL?
    * YAQL?
    * Basic format: key1:key2:...:lastkey
* Templating
* Linking:
    * Filesystem (local) or Internet
    * Probably already part of standard YAML...?
* YAML references
* `include`-style directive

### Fancy
* Tags
* YAQL
* Yglu queries / addresses
* User-defined types

### Really fancy
* Vim syntax file for query DSL

## Design
Elements, per [the docs][yaml-docs]:
* "Dump" direction: native datastructure --> human-readable stream
    * Represent --> node graph ([representation](#representation))
    * Serialize --> event tree ([serialization](#serialization))
    * Present --> character stream ([presentation](#presentation))
* "Load" direction: stream --> native datastructure
    * Parse --> [serialization](#serialization)
    * Compose --> [representation](#representation)
    * Construct --> [native datastructure](#native-datastructure)

### Data structures
* <a name="presentation"></a> Presentation
    * styles
    * comments
    * whitespace
    * directives
    * templates
* <a name="serialization"></a> Serialization
    * anchors
    * aliases
    * ordered keys
* <a name="representation"></a> Representation
    * tags
    * explicit types
    * canonical string values
* <a name="native-datastructure"></a> Native datastructure
    * opaque program data

## Intersecting projects
* Tags:
    * Management / composition library
    * Filesystem
* Templating:
    * Secrets management using `pass`
    * Template expression evaluation using Bash / Perl / Python / whatever
    * Some kind of "filesystem hook" for creating / deleting temp files containing secrets when required by arbitrary applications

---

[yaml-docs]: https://yaml.org/spec/1.2/spec.html
