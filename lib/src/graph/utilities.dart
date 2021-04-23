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

import 'package:analyzer/dart/element/element.dart';
import 'package:lsif_indexer/lsif_graph.dart' as lsif;

extension SetUtilities<T> on Set<T> {
  /// Add [element] if we don't already have an equal
  /// member, and return either [element] or the existing member.
  T addIfAbsent(T element) {
    var existing = lookup(element);
    if (existing == null) {
      add(element);
      return element;
    } else {
      return existing;
    }
  }
}

extension ElementSource on Element {
  /// Is this element part of the current library.
  // TODO: I don't think this is right. We are treating references from other libraries
  // in the same package as cross-package references. I think it works, but we should probably avoid.
  bool isLocaTo(lsif.Document document) => source.uri == document.packageUri;

  /// Does this element come from the Dart SDK.
  bool get isSdk => library.identifier.startsWith('dart');
}
