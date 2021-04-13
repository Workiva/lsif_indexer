# lsif_indexer

An LSIF indexer for Dart source code. Uses some mechanisms from package:lsif-dart, but
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
