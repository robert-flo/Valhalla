# Make compatibility aliases

Compatibility aliases preserve familiar short commands while the modular Make
interface is integrated incrementally. `make help-aliases` displays only aliases
whose destination target is currently available.

## Development

| Alias | Target |
| --- | --- |
| `vm` | `dev-vm` |
| `dev-vm-size` | `dev-vm-storage` |

## Git

| Aliases | Target |
| --- | --- |
| `a`, `git-a` | `git-add` |
| `c`, `git-c` | `git-commit` |
| `cm`, `git-cm` | `git-cm` |
| `ac`, `git-ac` | `git-add-commit` |
| `p`, `git-p` | `git-push` |
| `l`, `git-l` | `git-pull` |
| `st`, `s`, `git-st`, `git-s` | `git-status` |
| `d`, `git-d` | `git-diff` |
| `lg`, `git-lg` | `git-log` |
| `af`, `git-af` | `git-add-fuzzy` |
| `fuck`, `git-fuck` | `git-amend` |
| `bye`, `git-bye` | `git-prune-branches` |
| `df`, `git-df` | `git-diff-fuzzy` |
| `fc`, `git-fc` | `git-search CODE="..."` |
| `fm`, `git-fm` | `git-search MSG="..."` |

Aliases for system, update, generation, logging, formatting, and documentation
modules remain commented in the alias source. Each group can be enabled when
its backing Make module is added; unavailable aliases are not declared or
advertised in the runtime help.
