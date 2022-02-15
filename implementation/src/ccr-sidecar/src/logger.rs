use log::{Record, Level, Metadata, SetLoggerError, LevelFilter};

static DEFAULT_LOGGER: Logger = Logger;

struct Logger;

impl log::Log for Logger {
    fn enabled(&self, metadata: &Metadata) -> bool {
        metadata.level() <= Level::Info
    }

    fn log(&self, record: &Record) {
        if self.enabled(record.metadata()) {
            println!("{} - {}", record.level(), record.args());
        }
    }

    fn flush(&self) {}
}

pub fn init(verbose: bool) -> Result<(), SetLoggerError> {
    let level_filter = if verbose { LevelFilter::Debug } else { LevelFilter::Info };
    log::set_logger(&DEFAULT_LOGGER)
        .map(|()| log::set_max_level(level_filter))
}
