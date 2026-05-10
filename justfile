# arkade-native build recipes

# Development
cli *ARGS:
    cargo run -p arkade-cli -- {{ARGS}}

check:
    cargo check --workspace

build:
    cargo build --workspace

test:
    cargo test --workspace

fmt:
    cargo fmt --all

fmt-check:
    cargo fmt --all -- --check

clippy:
    cargo clippy --workspace -- -D warnings

# Full pre-commit check
pre-commit: fmt-check clippy test

# UniFFI bindings
gen-swift:
    cargo build -p arkade-core --release
    cargo run -p uniffi-bindgen generate \
        --library target/release/libarkade_core.dylib \
        --language swift \
        --out-dir ios/Bindings

gen-kotlin:
    cargo build -p arkade-core --release
    cargo run -p uniffi-bindgen generate \
        --library target/release/libarkade_core.dylib \
        --language kotlin \
        --out-dir android/app/src/main/java

# iOS (future)
build-ios-sim:
    cargo build -p arkade-core --release --target aarch64-apple-ios-sim

build-ios-device:
    cargo build -p arkade-core --release --target aarch64-apple-ios

# Android (future)
build-android:
    cargo ndk -t arm64-v8a -t x86_64 build -p arkade-core --release
