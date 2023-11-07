#[cxx::bridge]
mod ffi {
    unsafe extern "C++" {
        include!("cpp/src/main.cpp");

        fn app();
    }
}

fn main() {
    println!("Hello, world!");

    print!("From C++: ");

    ffi::app();
}
