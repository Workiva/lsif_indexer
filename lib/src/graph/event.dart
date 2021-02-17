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

/// Event entities in the LSIF graph.
abstract class Event extends Vertex {
  @override
  String get label => r'$event';
  Event(this.scope) : super();
  Element scope;
  @override
  Map<String, Object> toLsif() => {
        ...super.toLsif(),
        'kind': _kind,
        'scope': scope.label,
        'data': scope.jsonId
      };

  String get _kind;
}

class BeginEvent extends Event {
  @override
  String get _kind => 'begin';
  BeginEvent(Element scope) : super(scope);
}

class EndEvent extends Event {
  @override
  String get _kind => 'end';
  EndEvent(Element scope) : super(scope);
}
