#!/bin/bash -eu
# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
################################################################################
#
# The following code is rewritten by mahaloz and taken directly from Google OSS-Fuzz platform
# to make compiling 1.18 Go binaries to libfuzzer possible outside of the bulky OSS-Fuzz container
#

function rewrite_go_fuzz_harness() {
        fuzzer_filename=$1
        fuzz_function=$2

        # Create a copy of the fuzzer to not modify the existing fuzzer.
        cp $fuzzer_filename "${fuzzer_filename}"_fuzz_.go
        mv $fuzzer_filename /tmp/
        fuzzer_fn="${fuzzer_filename}"_fuzz_.go

        # Replace *testing.F with *go118fuzzbuildutils.F.
        echo "replacing *testing.F"
        sed -i "s/func $fuzz_function(\([a-zA-Z0-9]*\) \*testing\.F)/func $fuzz_function(\1 \*go118fuzzbuildutils\.F)/g" "${fuzzer_fn}"

        # Import https://github.com/AdamKorcz/go-118-fuzz-build.
        # This changes the line numbers from the original fuzzer.
        sed -i 's/import (/import \(go118fuzzbuildutils "github.com\/AdamKorcz\/go-118-fuzz-build\/utils"\)\n\nimport \(/' "${fuzzer_fn}"

}

function build_native_go_fuzzer() {
        fuzzer=$1
        function=$2
        path=$3
        tags="-tags gofuzz"
        go-118-fuzz-build -o $fuzzer.a -func $function $abs_file_dir
        clang -fsanitize=fuzzer $fuzzer.a -o $fuzzer
}


path=$1
function=$2
fuzzer=$3
tags="-tags gofuzz"

# Get absolute path.
abs_file_dir=$(go list $tags -f {{.Dir}} $path)
fuzzer_filename=$(grep -r -l  -s "$function" "${abs_file_dir}")

# Test if file contains a line with "func $function" and "testing.F".
if [ $(grep -r "func $function" $fuzzer_filename | grep "testing.F" | wc -l) -eq 1 ]
then

        rewrite_go_fuzz_harness $fuzzer_filename $function
        build_native_go_fuzzer $fuzzer $function $abs_file_dir

        # Clean up.
        rm "${fuzzer_filename}_fuzz_.go"
        mv /tmp/$(basename $fuzzer_filename) $fuzzer_filename
else
        echo "Could not find the function: func ${function}(f *testing.F)"
fi

