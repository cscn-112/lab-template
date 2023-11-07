use cxx_build;

fn main() {
    cxx_build::bridge("src/main.rs") // returns a cc::Build
        .file("src/main.cpp")
        .flag_if_supported("-std=c++11")
        .compile("lab-template");

    println!("cargo:rerun-if-changed=src/main.rs");
    println!("cargo:rerun-if-changed=src/main.cpp");
}
