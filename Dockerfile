FROM golang:1.18 as builder 

RUN apt update && apt install clang vim -y 

# grab target dependencies
RUN go install github.com/zeromicro/go-zero/tools/goctl@latest && \
    go install github.com/AdamKorcz/go-118-fuzz-build@latest && \
    go install golang.org/dl/gotip@latest && \
    gotip download 

# get local files for harnessing
COPY . go-zero

# find, compile, and move harness 
RUN cd /go/pkg/mod/github.com/zeromicro/go-zero\@* && \
    cd core/stringx && \
    go get github.com/AdamKorcz/go-118-fuzz-build/utils && \ 
    cp /go/go-zero/tools/compile_native_go_fuzzer.sh . && \
    chmod +x compile_native_go_fuzzer.sh && \
    ./compile_native_go_fuzzer.sh replacer_fuzz_test.go FuzzReplacerReplace fuzz_stringx_replacer && \
    cp fuzz_stringx_replacer /fuzz_stringx_replacer 

FROM golang:1.18
COPY --from=builder /fuzz_stringx_replacer /
