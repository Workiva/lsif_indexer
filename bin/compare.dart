// Copyright 2020 Workiva Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:io';
import 'dart:convert';

/// Compare two LSIF files as graphs.
///
/// Used to verify that this can create input that's sufficiently similar to
/// the lsif-dart generator.
///
/// Prints 'failed' (or else throws) if there's not a match. Prints 'matched'
/// if it succeeded.
void main(List<String> args) {
  print('Iterating ${args.last}');
  print('looking for matches in ${args.first}');
  var one = read(args.first).toSet();
  var two = read(args.last);

  var counted = 1;
  print('There are ${two.length} entries in ${args.last}');
  for (var entry in two) {
    print('entry #${counted++}');
    var corresponding = correspondingEntry(entry, one);
  }
  if (one.isNotEmpty) {
    print('failed');
    one.forEach(print);
  } else {
    print('matched');
  }
}

/// Read the file as lines of JSON-encoded data.
List<Map<String, Object>> read(String path) {
  var f = File(path);
  var lines = f.readAsLinesSync();
  return lines.map<Map<String, Object>>((each) => json.decode(each)).toList();
}

/// Attributes that contain ids - we can't compare these directly.
const idAttributes = ['id', 'data', 'inV', 'outV', 'document'];

/// Attributes with collections of ids - we just compare that these have
/// the correct lengths.
const idCollectionAttributes = ['inVs', 'outVs'];

/// Don't compare these labels, verified manually.
const labelsToIgnore = ['metaData'];

/// Verify that we can find a match for [entry] among those in [available].
///
/// Throws if we can't find an entry, so we can debug it.
Map<String, Object> correspondingEntry(
    Map<String, Object> entry, Set<Map<String, Object>> available) {
  var sameLabel = available.where((each) => each['label'] == entry['label']).toList();
  print('Looking for match for $entry in ${sameLabel.length} candidates');
  for (var candidate in sameLabel) {
    print('Comparing\n  $candidate');
    if (match(entry, candidate)) {
      available.remove(candidate);
      return candidate;
    }
  }
  throw StateError('No match for $entry');
}

/// Does [entry] correspond to [candidate], given that the node numberings
/// may be different.
bool match(Map<String, Object> entry, Map<String, Object> candidate) {
  if (labelsToIgnore.contains(entry['label'])) {
    return true;
  }

  /// We write some debug info to make the files easier to read manually. Ignore that.
  var debugKeys = entry.keys.where((each) => each.startsWith('_debug')).toList();
  for (var key in debugKeys) {
    entry.remove(key);
  }

  if (entry.keys.length != candidate.keys.length) return false;
  var matched = true;
  entry.forEach((key, value) {
    var otherValue = candidate[key];
    // We compare collections of IDs by length, since the actual numbers will be different.
    if (idCollectionAttributes.contains(key)) {
      var l1 = (value as List).length;
      var l2 = (otherValue as List).length;
      matched = matched && (l1 == l2);
    } else if (idAttributes.contains(key)) {
      // Just verify that ID attributes are present.
      matched = matched && (value != null && (otherValue != null));
    } else if (key == 'end' || key == 'start') {
      // For ranges, our entries may be larger than the the originals, but make
      // sure they contain the original range.
      matched = matched && spans(entry, candidate);
    } else {
      // Compare the values. To do simple map equality, just compare the toString.
      matched = matched && ('$value' == '$otherValue');
    }
  });
  return matched;
}

// This has a range. Verify that the start of entry is on the same line as candidate, and no later in the line.
// Similarly, verify that the end is strictly after that of candidate. It can be on a line further down, for example
// if we get a full method with body vs. just the method name. Another case is a declaration where we include
// initialization ('var *i = 0*;) but the thing we're comparing
// against only includes the variable name.
bool spans(dynamic entry, dynamic candidate) {
  var entryStartLine = entry['start']['line'];
  var candidateStartLine = candidate['start']['line'];
  var entryStartColumn = entry['start']['character'];
  var candidateStartColumn = candidate['start']['character'];
  var entryEndLine = entry['end']['line'];
  var candidateEndLine = candidate['end']['line'];
  var entryEndColumn = entry['end']['character'];
  var candidateEndColumn = candidate['end']['character'];
  if (entryStartLine != candidateStartLine) {
    return false;
  }
  if (entryStartColumn > candidateStartColumn) {
    return false;
  }
  if (entryEndLine < candidateEndLine) {
    return false;
  }
  if (entryEndLine == candidateEndLine) {
    return entryEndColumn >= candidateEndColumn;
  }
  // The end line is greater, in which case the column doesn't matter.
  return true;
}
