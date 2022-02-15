fn main() -> Result<(), Box<dyn std::error::Error>> {
    tonic_build::configure()
        .build_server(true)
        .build_client(false)
        .compile(
            &["proto/envoy/service/ext_proc/v3/external_processor.proto"],
            &["proto"]
        )?;
    Ok(())
}
