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

import 'dart:collection';

import 'package:path/path.dart' as path;

extension PathExtensions on String {
  /// Normalizes [this], simplifying it by handling `..`, and `.`, and
  /// removing redundant path separators whenever possible.
  ///
  /// Note that this is *not* guaranteed to return the same result for two
  /// equivalent input paths. For that, see [path.canonicalize]. Or, if you're using
  /// paths as map keys, pass [path.equals] and [path.hash] to [HashMap].
  ///
  ///     path/./to/..//file.text'.normalized; // -> 'path/file.txt'
  ///
  /// See [path.normalize()]
  String get normalized => path.normalize(this);

  /// Creates a new path by appending the given path parts to [path.current].
  /// Equivalent to [path.join()] with [path.current] as the first argument. Example:
  ///
  ///     'path'.absolute; // -> '/your/current/dir/path'
  ///
  /// See [path.absolute()]
  String get absolute => path.absolute(this);
}
