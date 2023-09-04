#!/bin/sh
# Copyright (c) 2023 noOvertimeGroup
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

has_errors=0

# 获取git暂存的所有go代码
allgofiles=$(git diff --cached --name-only --diff-filter=ACM | grep '.go$' | grep -v 'vendor*' | grep -v '*.pb.go')

# 高版本兼容
declare -a gofiles
declare -a godirs
for allfile in ${allgofiles[@]}; do
    gofiles+=("$allfile")
    dir=$(dirname "$allfile")
    godirs+=("$dir")
done

godirs=$(echo "${godirs[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')

[ -z "$gofiles" ] && exit 0

check_gofmt() {
    unformatted=$(gofmt -l ${gofiles[@]})
    if [ -n "$unformatted" ]; then
        echo >&2 "gofmt Fail:\n Run following command:"
        for f in ${unformatted[@]}; do
            echo >&2 " gofmt -w $PWD/$f"
        done
        echo "\n"
        has_errors=1
    fi
}

check_goimports() {
    if goimports >/dev/null 2>&1; then
        unimports=$(goimports -l ${gofiles[@]})
        if [  -n "$unimports" ]; then
            echo >&2 "goimports Fail:\nRun following command:"
            for f in ${unimports[@]};do
                echo >&2 " goimports -w $PWD/$f"
            done
            echo "\n"
            has_errors=1
        fi
    else
        echo 'Error: goimports not install. Run: "go install golang.org/x/tools/cmd/goimports@latest"' >&2
        exit 1
    fi
}

check_govet() {
    show_vet_header=true
    for dir in ${godirs[@]}; do
        vet=$(go vet $PWD/$dir 2>&1)
        if [ -n "$vet" -a $show_vet_header = true ]; then
            echo "govet Fail:"
            show_vet_header=false
        fi
        if [ -n "$vet" ]; then
            echo "$vet\n"
            has_errors=1
        fi
    done
}

check_gotest() {
    test=$(go test ./... -race -cover -failfast)
    if [ $? -ne 0 ]; then
        echo "go test Fail:"
        echo "$test\n"
        has_errors=1
    fi
}

check_gofmt
check_goimports
check_govet
check_gotest

exit $has_errors