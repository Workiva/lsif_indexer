// Copyright 2020 Workiva Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// --------------------------------------------------
//
// This lsif_indexer software is based on a number of software repositories with
// separate copyright notices and/or license terms. Your use of the source
// code for the these software repositories is subject to the terms and
// conditions of the following licenses:
//
// lsif-dart: https://github.com/sourcegraph/lsif-dart
// Copyright Anton Astashov. All rights reserved.
// Licensed under the BSD-2 Clause License: https://github.com/sourcegraph/lsif-dart/blob/master/LICENSE
//
// crossdart: https://github.com/astashov/crossdart
// Copyright Anton Astashov. All rights reserved.
// Licensed under the BSD-2 Clause License: https://github.com/astashov/crossdart/blob/master/LICENSE

import 'dart:io';

import 'package:lsif_indexer/analyzer.dart';
import 'package:lsif_indexer/src/arguments.dart';
import 'package:lsif_indexer/src/emitter.dart';
import 'package:lsif_indexer/src/util/path_extensions.dart';
import 'package:path/path.dart';

/// Generate LSIF information for the directory provided from the [arguments], or
/// the current directory if not specified.
///
/// The destination of the output is based on the [arguments].
void main(List<String> arguments) async {
  final config = ArgumentParser().parse(arguments);

  // Exit early if the arguments were invalid
  if (!config.isValid) return;

  emitter = config.output == null
      ? Emitter.standardOutput()
      : Emitter.fileOutput(config.output);

  Future<void> _analyze() async {
    await Analyzer(
      packageRoot: config.projectRoot?.absolute?.normalized ??
          Directory.current.absolute.path,
      filesToAnalyze: config.rest.map(absolute).toList(),
    ).analyzePackage();
  }

  await emitter.use(_analyze);
}
