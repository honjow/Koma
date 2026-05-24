mod host;
mod types;

use anyhow::Result;
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
    /// Run all operations sequentially and report pass/fail
    TestAll {
        /// Path to the compiled .wasm source
        wasm: PathBuf,
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
        Commands::TestAll { wasm } => {
            run_test_all(&wasm)?;
        }
    }

    Ok(())
}

fn run_op_quiet(wasm: &PathBuf, op: &str, request: &str) -> Result<serde_json::Value> {
    host::run_operation(wasm, op, request)
}

fn is_ok(v: &serde_json::Value) -> bool {
    v.get("ok").and_then(|v| v.as_bool()).unwrap_or(false)
}

fn data(v: &serde_json::Value) -> &serde_json::Value {
    v.get("data").unwrap_or(v)
}

fn error_msg(v: &serde_json::Value) -> &str {
    v.get("error")
        .and_then(|e| e.get("message").or(Some(e)))
        .and_then(|m| m.as_str())
        .unwrap_or("ok=false")
}

fn item_count(v: &serde_json::Value, key: &str) -> usize {
    data(v).get(key).and_then(|a| a.as_array()).map(|a| a.len()).unwrap_or(0)
}

fn first_id(v: &serde_json::Value, key: &str) -> Option<String> {
    data(v)
        .get(key)
        .and_then(|a| a.as_array())
        .and_then(|a| a.first())
        .and_then(|item| item.get("id"))
        .and_then(|id| id.as_str())
        .map(|s| s.to_string())
}

fn run_test_all(wasm: &PathBuf) -> Result<()> {
    const TOTAL: usize = 10;
    let mut passed = 0usize;

    let mut print_pass = |op: &str, summary: &str| {
        println!("✓ {} — {}", op, summary);
        passed += 1;
    };
    let mut print_fail = |op: &str, err: &str| {
        println!("✗ {} — {}", op, err);
    };

    // --- search (dependent: provides manga_id for get_manga/get_chapters/get_pages) ---
    let mut manga_id: Option<String> = None;
    let mut chapter_id: Option<String> = None;

    match run_op_quiet(wasm, "search", r#"{"query":"test"}"#) {
        Err(e) => print_fail("search", &e.to_string()),
        Ok(v) if !is_ok(&v) => print_fail("search", error_msg(&v)),
        Ok(v) => {
            let count = item_count(&v, "items");
            manga_id = first_id(&v, "items");
            print_pass("search", &format!("{} items", count));
        }
    }

    // --- get_manga (depends on manga_id from search; request field is "mangaId") ---
    if let Some(ref id) = manga_id {
        let req = format!(r#"{{"mangaId":"{}"}}"#, id);
        match run_op_quiet(wasm, "get_manga", &req) {
            Err(e) => print_fail("get_manga", &e.to_string()),
            Ok(v) if !is_ok(&v) => print_fail("get_manga", error_msg(&v)),
            Ok(v) => {
                let title = data(&v)
                    .get("manga")
                    .and_then(|m| m.get("title"))
                    .and_then(|t| t.as_str())
                    .unwrap_or("(no title)");
                print_pass("get_manga", &format!("title: {}", title));
            }
        }
    } else {
        print_fail("get_manga", "skipped — no manga ID from search");
    }

    // --- get_chapters (depends on manga_id; request field is "mangaId") ---
    if let Some(ref id) = manga_id {
        let req = format!(r#"{{"mangaId":"{}"}}"#, id);
        match run_op_quiet(wasm, "get_chapters", &req) {
            Err(e) => print_fail("get_chapters", &e.to_string()),
            Ok(v) if !is_ok(&v) => print_fail("get_chapters", error_msg(&v)),
            Ok(v) => {
                let count = item_count(&v, "items");
                chapter_id = first_id(&v, "items");
                print_pass("get_chapters", &format!("{} chapters", count));
            }
        }
    } else {
        print_fail("get_chapters", "skipped — no manga ID from search");
    }

    // --- get_pages (depends on chapter_id; request field is "chapterId") ---
    if let Some(ref id) = chapter_id {
        let req = format!(r#"{{"chapterId":"{}"}}"#, id);
        match run_op_quiet(wasm, "get_pages", &req) {
            Err(e) => print_fail("get_pages", &e.to_string()),
            Ok(v) if !is_ok(&v) => print_fail("get_pages", error_msg(&v)),
            Ok(v) => {
                let count = item_count(&v, "pages");
                print_pass("get_pages", &format!("{} pages", count));
            }
        }
    } else {
        print_fail("get_pages", "skipped — no chapter ID from get_chapters");
    }

    // --- independent operations ---
    macro_rules! run_independent {
        ($op:expr, $req:expr, $summary:expr) => {
            match run_op_quiet(wasm, $op, $req) {
                Err(e) => print_fail($op, &e.to_string()),
                Ok(v) if !is_ok(&v) => print_fail($op, error_msg(&v)),
                Ok(v) => {
                    let summary: String = $summary(&v);
                    print_pass($op, &summary);
                }
            }
        };
    }

    run_independent!("get_listings", r#"{}"#, |v: &serde_json::Value| {
        format!("{} items", item_count(v, "items"))
    });

    run_independent!("get_manga_list", r#"{"page":"1"}"#, |v: &serde_json::Value| {
        format!("{} items", item_count(v, "items"))
    });

    run_independent!("get_filters", r#"{}"#, |v: &serde_json::Value| {
        format!("{} filters", item_count(v, "filters"))
    });

    run_independent!("get_settings", r#"{}"#, |v: &serde_json::Value| {
        let field_count = data(v).as_object().map(|o| o.len()).unwrap_or(0);
        format!("{} fields", field_count)
    });

    run_independent!("get_home", r#"{}"#, |v: &serde_json::Value| {
        format!("{} items", item_count(v, "items"))
    });

    run_independent!("get_image_request", r#"{"url":"https://example.com/img.jpg"}"#, |v: &serde_json::Value| {
        let has_url = data(v).get("url").and_then(|u| u.as_str()).is_some();
        if has_url { "ok".into() } else { "missing url field".into() }
    });

    println!("\nResults: {}/{} passed", passed, TOTAL);
    Ok(())
}
