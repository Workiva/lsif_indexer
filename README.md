> [!WARNING]
> This repo has been deprecated, and it's functionality replaced by [scip-dart](https://github.com/Workiva/scip-dart). Please refer to that repo for generating precise code intelligence for dart.

# lsif_indexer

An [LSIF] indexer for Dart source code. Uses some mechanisms from package:lsif-dart, but
rewritten from scratch and significantly simpler.

## Quick Start

Activate lsif_indexer:
```bash
$ pub global activate -sgit https://github.com/Workiva/lsif_indexer
```

Run the indexer on a package:
```bash
$ pub global run lsif_indexer -o dump.lsif
```

Optionally provide:
| Command | Abbreviation | Description | Default |
| --- | --- | --- | --- |
| `output` | `o` | Specify the output file | Terminal standard output |
| `root` | `r` | Specify the root of the project you are indexing | Current directory |

## Resources
 - The LSP/LSIF [specification] - not as specific as it might be.
 - A Sourcegraph document on [writing an indexer] has some explanations.

[LSIF]:https://lsif.dev/
[specification]:https://microsoft.github.io/language-server-protocol/specifications/lsif/0.4.0/specification/
[writing an indexer]:https://docs.sourcegraph.com/code_intelligence/explanations/writing_an_indexer


