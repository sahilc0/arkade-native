fn main() {
    uniffi::generate_scaffolding("src/arkade_core.udl").unwrap_or_else(|_| {
        // If no UDL file, use proc-macro mode (no scaffolding needed)
    });
}
