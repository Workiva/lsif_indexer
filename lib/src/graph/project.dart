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

import 'package:lsif_indexer/lsif_graph.dart';

/// Contains the project and packageInformation nodes.
///
/// In Dart (I think) a project corresponds to a Dart package, so we should have
/// exactly one packageInformation that we emit at the start, and it applies to
/// all documents.
class Project extends Scope {
  @override
  String get label => 'project';
  List<Document> documents;

  Project(this.documents) {
    for (var doc in documents) {
      doc.project = this;
    }
  }

  // The validator doesn't like documents that contain nothing, so skip
  // libraries that are empty (most often those that are just re-exports)
  List<Document> get nonEmptyDocuments => [
        for (var d in documents)
          if (d.isNotEmpty) d
      ];

  @override
  Edge get contains => ProjectContains(this);

  @override
  Map<String, Object> toLsif() => {...super.toLsif(), 'kind': 'dart'};

  PackageInformation _packageInformation;
  PackageInformation get packageInformation {
    if (_packageInformation != null) {
      return _packageInformation;
    }
    var packageName = Uri.parse(documents.first.packageUri.pathSegments.first);
    _packageInformation = PackageInformation('package:$packageName');
    return _packageInformation;
  }

  @override
  void emit() {
    super.emit();
    packageInformation.emit();
  }
}

class PackageInformation extends Vertex {
  PackageInformation(this.url);

  /// The URL for the package.
  String url;

  @override
  bool operator ==(Object x) => x is PackageInformation && x.url == url;

  @override
  int get hashCode => url.hashCode;

  @override
  String get label => 'packageInformation';
  @override
  Map<String, Object> toLsif() => {
        ...super.toLsif(),
        'name': url,
        'manager': 'pub',
        'version': '',
      };
}
