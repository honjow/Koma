mod host;
mod types;

use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use std::path::PathBuf;

#[derive(Parser)]
#[command(name = "koma-source-dev", about = "Dev host runner for Koma WASM sources")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Show source info and capabilities
    Info {
        /// Path to the compiled .wasm source
        wasm: PathBuf,
    },
    /// Run a source operation
    Run {
        /// Path to the compiled .wasm source
        wasm: PathBuf,
        /// Operation name (search, get_manga, get_chapters, get_pages, get_listings, get_manga_list, get_home, get_filters, get_settings, get_image_request)
        #[arg(long)]
        op: String,
        /// Request JSON (e.g. '{"query":"one piece","page":1,"limit":20}')
        #[arg(long)]
        request: String,
    },
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Info { wasm } => {
            let result = host::run_source_info(&wasm)?;
            println!("{}", serde_json::to_string_pretty(&result)?);
        }
        Commands::Run { wasm, op, request } => {
            let result = host::run_operation(&wasm, &op, &request)?;
            println!("{}", serde_json::to_string_pretty(&result)?);
        }
    }

    Ok(())
}
