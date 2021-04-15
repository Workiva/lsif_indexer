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

import 'package:analyzer/src/generated/source.dart' show LineInfo;
import 'package:lsif_indexer/lsif_graph.dart';

/// The document entity in the LSIF graph.
class Document extends Scope {
  @override
  String get label => 'document';
  Document({this.uri, this.content, this.packageUri, this.lineInfo});
  Uri uri;
  Uri packageUri;
  String content;
  List<String> _contentLines;
  LineInfo lineInfo;
  Set<Declaration> declarations = {};
  List<Reference> references = [];

  String line(int lineNumber) {
    _contentLines ??= content.split('\n');
    return _contentLines[lineNumber];
  }

  @override
  Contains get contains => Contains(this);

  @override
  Map<String, Object> toLsif() => {
        ...super.toLsif(),
        'uri': '$uri',
        'languageId': 'dart',
      };
}
