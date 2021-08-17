# YAML Parser

## Summary
Tools for parsing and writing YAML configuration files and frontmatter with minimal dependencies.

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
* Efficient partial traversal: should support searching for a specific map key or list item "address," e.g.

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

### Challenges
* How to efficiently represent graphs in Bash?
    * Perhaps use awk instead?
        * e.g., `SYMTAB` can be used to construct rudimentary "pointers" which can be stored in string-indexed arrays

### Ideas
* "Generic parser" based on input DFA grammar?
    * Equivalent to developing markup for general [lm-diagrams][lm-diagrams]
    * Well-understood problem: Could use ANTLR, Bison, Yacc, etc.
    * .g4 file format to represent generative grammar
* Can use `@include` directive (`gawk`-specific) to break up implementation
* Use "tea-leaves"-style sorting: insert extra numerical fields which can easily be sorted (e.g., based on indentation)
* "Standard" decomposition (see, e.g., [this parser tutorial][parser-tutorial]):
    * Reader
        * `peek()`
        * `isEOF()`
        * `consume(k)`
    * Lexer / Tokenizer
        * Whitespace and comments need to be sensibly handled at this level
        * Can write whitespace tokens to dedicated "whitestream," e.g.
        * `peek()`
        * `consume()`
    * Parser
        * `parse()`
    * Error handler

### Grammar

Simplified YAML grammar in [BNF notation](#bnf):
```bnf
<yaml> ::= <scalar> | <map> | <array>
<map> ::= <kv-pair> \n <map> | ""
<array> ::= <item> \n <array> | ""
<scalar> ::= <escaped-line> \n <scalar> | TEXT
<kv-pair> ::= <key> TEXT | <key> \n <yaml>
<key> ::= TEXT ':'
<escaped-line> ::= TEXT '|'
<label> ::=
<reference> ::=
```

#### Unsupported YAML features
* Uniqueness of map keys?
* Sequence (i.e., **unordered** arrays)

#### Grammar specification metalanguage
<a name="antlr"></a> Simplified ANTLR:
* Terminals should be ALLCAPS, nonterminals lowercase
* Can use `|` to represent branching
* Production rules:
    * `nonterm : R(nonterms, terms) ;`, where `R(...)` denotes a regexp built out of its arguments
* Non-ANTLR symbols / conveniences to simplify use with `awk` and `sed`:
    * `start` and `end` symbols / nonterminals

<a name="bnf"></a> BNF-style:
* `<nonterminal> ::= expr1 | expr2 | ... | exprn`
* "Parameterized" production rules?
    * e.g., parameterizing a YAML root nonterminal by the indentation level, as in `<yaml{n}>` or `<yaml[n]>`

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
[parser-tutorial]: https://medium.com/swlh/writing-a-parser-getting-started-44ba70bb6cc9
[lm-diagrams]: http://languagemachine.sourceforge.net/picturebook.html
