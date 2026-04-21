use anyhow::{Context, Result};
use clap::Parser;
use rayon::prelude::*;
use regex::Regex;
use serde::{Deserialize, Serialize};
use std::collections::{HashMap, HashSet};
use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Parser, Debug)]
struct Args {
    #[arg(long, default_value_t = 40)]
    lines: usize,
    #[arg(long, default_value_t = 220)]
    width: usize,
    #[arg(long, default_value_t = 4)]
    display_id_width: usize,
    #[arg(long, default_value_t = 4)]
    left_age_width: usize,
    #[arg(long, default_value_t = 22)]
    right_stats_width: usize,
    #[arg(long, default_value_t = 6)]
    hpad: usize,
    #[arg(long, default_value_t = 6)]
    vpad: usize,
    #[arg(long, default_value_t = 4)]
    ipad: usize,
    #[arg(long, default_value_t = 240)]
    preview_chars: usize,
    #[arg(long, default_value_t = 262144)]
    max_decode_bytes: usize,
    #[arg(long, default_value_t = false)]
    refresh_all: bool,
    #[arg(long, default_value = "\\n")]
    composite_separator: String,
    #[arg(long, default_value_t = true, action = clap::ArgAction::Set)]
    relaunch_after_composite_action: bool,
}

#[derive(Serialize, Deserialize, Clone, Default)]
struct EntryMeta {
    first_seen: i64,
    kind: String,
    lines: Option<usize>,
    words: Option<usize>,
    chars: Option<usize>,
    preview: Option<String>,
}

#[derive(Serialize, Deserialize, Default)]
struct Cache {
    entries: HashMap<String, EntryMeta>,
}

#[derive(Clone)]
struct ListEntry {
    id: String,
    raw_preview: String,
}

fn now_epoch() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs() as i64
}

fn run_capture(cmd: &str, args: &[&str]) -> Result<Vec<u8>> {
    let out = Command::new(cmd)
        .args(args)
        .output()
        .with_context(|| format!("failed to run {}", cmd))?;
    if !out.status.success() {
        anyhow::bail!("command failed: {} {:?}", cmd, args);
    }
    Ok(out.stdout)
}

fn fmt_sci(n: usize) -> String {
    if n < 1000 {
        n.to_string()
    } else {
        let s = format!("{:.2e}", n as f64);
        s.replace("e+0", "e")
            .replace("e-0", "e-")
            .replace("e+", "e")
    }
}

fn fmt_age(delta: i64) -> String {
    match delta {
        d if d < 60 => format!("{}s", d),
        d if d < 3600 => format!("{}m", d / 60),
        d if d < 86400 => format!("{}h", d / 3600),
        d if d < 604800 => format!("{}d", d / 86400),
        d if d < 2592000 => format!("{}w", d / 604800),
        d if d < 31536000 => format!("{}M", d / 2592000),
        d => format!("{}y", d / 31536000),
    }
}

fn parse_list() -> Result<Vec<ListEntry>> {
    let stdout = run_capture("cliphist", &["list"])?;
    let text = String::from_utf8_lossy(&stdout);
    Ok(text
        .lines()
        .filter_map(|line| {
            line.split_once('\t').map(|(id, rest)| ListEntry {
                id: id.to_string(),
                raw_preview: rest.to_string(),
            })
        })
        .collect())
}

fn is_binary_preview(s: &str) -> bool {
    s.contains("[[ binary data")
}

fn decode_entry(id: &str) -> Result<Vec<u8>> {
    let mut child = Command::new("cliphist")
        .arg("decode")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()
        .context("spawn cliphist decode")?;

    child
        .stdin
        .as_mut()
        .unwrap()
        .write_all(format!("{}\t", id).as_bytes())?;

    let out = child.wait_with_output()?;
    if !out.status.success() {
        anyhow::bail!("cliphist decode failed for {}", id);
    }
    Ok(out.stdout)
}

fn count_text(s: &str) -> (usize, usize, usize) {
    let lines = if s.is_empty() { 0 } else { s.lines().count() };
    let words = s.split_whitespace().count();
    let chars = s.chars().count();
    (lines, words, chars)
}

fn collapse_preview(s: &str, max_chars: usize) -> String {
    let mut out = s.split_whitespace().collect::<Vec<_>>().join(" ");
    if out.chars().count() > max_chars {
        out = out.chars().take(max_chars).collect::<String>();
    }
    out
}

fn load_cache(path: &Path) -> Cache {
    fs::read_to_string(path)
        .ok()
        .and_then(|s| serde_json::from_str(&s).ok())
        .unwrap_or_default()
}

fn save_cache(path: &Path, cache: &Cache) -> Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::write(path, serde_json::to_vec_pretty(cache)?)?;
    Ok(())
}

fn read_text_file(path: &Path) -> String {
    fs::read_to_string(path).unwrap_or_default()
}

fn write_text_file(path: &Path, content: &str) -> Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::write(path, content)?;
    Ok(())
}

fn clear_file(path: &Path) -> Result<()> {
    write_text_file(path, "")
}

fn current_buffer_text() -> String {
    match Command::new("wl-paste").arg("-n").output() {
        Ok(out) if out.status.success() => String::from_utf8_lossy(&out.stdout).to_string(),
        _ => String::new(),
    }
}

fn clipboard_equals_text(s: &str) -> bool {
    current_buffer_text() == s
}

fn stats_label(prefix: &str, s: &str) -> String {
    let (l, w, c) = count_text(s);
    format!("{} L{} W{} C{}", prefix, fmt_sci(l), fmt_sci(w), fmt_sci(c))
}

fn build_prompt(composite_path: &Path) -> String {
    let buf = current_buffer_text();
    let composite = read_text_file(composite_path);
    format!(
        "{} | {} > ",
        stats_label("buf", &buf),
        stats_label("sel", &composite)
    )
}

fn write_clipboard(bytes: &[u8]) -> Result<()> {
    let mut child = Command::new("wl-copy")
        .stdin(Stdio::piped())
        .spawn()
        .context("spawn wl-copy")?;
    child.stdin.as_mut().unwrap().write_all(bytes)?;
    let _ = child.wait()?;
    Ok(())
}

fn build_visible_line(
    display_id: usize,
    age: &str,
    preview: &str,
    stats: &str,
    display_id_w: usize,
    age_w: usize,
    stats_w: usize,
    width: usize,
) -> String {
    let left = format!(
        "{:>display_id_w$} {:<age_w$}",
        display_id,
        age,
        display_id_w = display_id_w,
        age_w = age_w
    );
    let right = format!("{:>stats_w$}", stats, stats_w = stats_w);

    let reserved = display_id_w + 1 + age_w + 1 + 1 + stats_w;
    let mid_w = width.saturating_sub(reserved).max(8);

    let mut p = preview.chars().take(mid_w).collect::<String>();
    let p_len = p.chars().count();
    if p_len < mid_w {
        p.push_str(&" ".repeat(mid_w - p_len));
    }

    format!("{} {} {}", left, p, right)
}

fn parse_separator(s: &str) -> String {
    s.replace("\\n", "\n").replace("\\t", "\t")
}

fn load_selected_index(path: &Path) -> usize {
    read_text_file(path).trim().parse::<usize>().unwrap_or(0)
}

fn save_selected_index(path: &Path, index: usize) -> Result<()> {
    write_text_file(path, &index.to_string())
}

fn relaunch_self() {
    let exe = match std::env::current_exe() {
        Ok(v) => v,
        Err(_) => return,
    };

    let args: Vec<String> = std::env::args().skip(1).collect();
    let _ = Command::new(exe).args(args).spawn();
}

fn main() -> Result<()> {
    let args = Args::parse();
    let home = std::env::var("HOME").context("HOME not set")?;
    let xdg_state = std::env::var("XDG_STATE_HOME").unwrap_or(format!("{}/.local/state", home));
    let xdg_cache = std::env::var("XDG_CACHE_HOME").unwrap_or(format!("{}/.cache", home));

    let cache_path = PathBuf::from(format!("{}/cliphist/rich-cache.json", xdg_state));
    let composite_path = PathBuf::from(format!("{}/cliphist/composite.txt", xdg_state));
    let selected_index_path = PathBuf::from(format!("{}/cliphist/selected-index.txt", xdg_state));
    let thumb_dir = PathBuf::from(format!("{}/cliphist/thumbnails", xdg_cache));
    fs::create_dir_all(&thumb_dir)?;
    if let Some(parent) = composite_path.parent() {
        fs::create_dir_all(parent)?;
    }
    if !composite_path.exists() {
        clear_file(&composite_path)?;
    }
    if !selected_index_path.exists() {
        save_selected_index(&selected_index_path, 0)?;
    }

    let mut cache = load_cache(&cache_path);
    let entries = parse_list()?;
    if entries.is_empty() {
        let _ = Command::new("fuzzel")
            .args(["-d", "--prompt-only", "cliphist: please store something first "])
            .status();
        return Ok(());
    }

    let now = now_epoch();
    let ids: HashSet<String> = entries.iter().map(|e| e.id.clone()).collect();
    cache.entries.retain(|k, _| ids.contains(k));

    for e in &entries {
        cache.entries.entry(e.id.clone()).or_insert_with(|| EntryMeta {
            first_seen: now,
            kind: if is_binary_preview(&e.raw_preview) {
                "binary".into()
            } else {
                "text".into()
            },
            ..Default::default()
        });
    }

    let misses: Vec<ListEntry> = entries
        .iter()
        .filter(|e| {
            if is_binary_preview(&e.raw_preview) {
                return false;
            }
            let m = cache.entries.get(&e.id).cloned().unwrap_or_default();
            args.refresh_all
                || m.lines.is_none()
                || m.words.is_none()
                || m.chars.is_none()
                || m.preview.is_none()
        })
        .cloned()
        .collect();

    let existing_first_seen: HashMap<String, i64> = cache
        .entries
        .iter()
        .map(|(k, v)| (k.clone(), v.first_seen))
        .collect();

    let refreshed: Vec<(String, EntryMeta)> = misses
        .par_iter()
        .filter_map(|e| {
            let decoded = decode_entry(&e.id).ok()?;
            let text = if decoded.len() > args.max_decode_bytes {
                String::from_utf8_lossy(&decoded[..args.max_decode_bytes]).to_string()
            } else {
                String::from_utf8_lossy(&decoded).to_string()
            };
            let (l, w, c_text) = count_text(&text);
            Some((
                e.id.clone(),
                EntryMeta {
                    first_seen: *existing_first_seen.get(&e.id).unwrap_or(&now),
                    kind: "text".into(),
                    lines: Some(l),
                    words: Some(w),
                    chars: Some(if decoded.len() > args.max_decode_bytes {
                        decoded.len()
                    } else {
                        c_text
                    }),
                    preview: Some(collapse_preview(&text, args.preview_chars)),
                },
            ))
        })
        .collect();

    for (id, meta) in refreshed {
        cache.entries.insert(id, meta);
    }
    save_cache(&cache_path, &cache)?;

    let bin_re = Regex::new(r"binary data.*(jpg|jpeg|png|bmp)").unwrap();
    let mut menu_lines = Vec::new();

    for (idx, e) in entries.iter().enumerate() {
        let meta = cache.entries.get(&e.id).cloned().unwrap_or_default();
        let age = fmt_age(now - meta.first_seen);
        let stats = if meta.kind == "binary" {
            "L- W- C-".to_string()
        } else {
            format!(
                "L{} W{} C{}",
                fmt_sci(meta.lines.unwrap_or(0)),
                fmt_sci(meta.words.unwrap_or(0)),
                fmt_sci(meta.chars.unwrap_or(0))
            )
        };
        let body = if meta.kind == "binary" {
            e.raw_preview.clone()
        } else {
            meta.preview.unwrap_or_else(|| e.raw_preview.clone())
        };

        let display = build_visible_line(
            idx,
            &age,
            &body,
            &stats,
            args.display_id_width,
            args.left_age_width,
            args.right_stats_width,
            args.width.saturating_sub(4),
        );
        menu_lines.push(format!("{}\t{}", e.id, display));

        if meta.kind == "binary" {
            if let Some(cap) = bin_re.captures(&e.raw_preview) {
                let ext = cap.get(1).map(|m| m.as_str()).unwrap_or("bin");
                let thumb = thumb_dir.join(format!("{}.{}", e.id, ext));
                if !thumb.exists() {
                    if let Ok(bytes) = decode_entry(&e.id) {
                        let _ = fs::write(&thumb, bytes);
                    }
                }
            }
        }
    }

    let mut remembered_index = load_selected_index(&selected_index_path);
    if remembered_index >= menu_lines.len() {
        remembered_index = menu_lines.len().saturating_sub(1);
    }

    let prompt = build_prompt(&composite_path);
    let mut child = Command::new("fuzzel")
        .args([
            "-d",
            "--index",
            "--placeholder",
            "Search clipboard...",
            "--prompt",
            &prompt,
            "--counter",
            "--no-sort",
            "--lines",
            &args.lines.to_string(),
            "--width",
            &args.width.to_string(),
            "--horizontal-pad",
            &args.hpad.to_string(),
            "--vertical-pad",
            &args.vpad.to_string(),
            "--inner-pad",
            &args.ipad.to_string(),
            "--with-nth",
            "{2}",
            "--select-index",
            &remembered_index.to_string(),
        ])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()
        .context("spawn fuzzel")?;

    {
        let stdin = child.stdin.as_mut().unwrap();
        stdin.write_all(menu_lines.join("\n").as_bytes())?;
    }

    let out = child.wait_with_output()?;
    let exit = out.status.code().unwrap_or(1);
    let selected_index = String::from_utf8_lossy(&out.stdout)
        .trim()
        .parse::<usize>()
        .ok();

    if let Some(index) = selected_index {
        let _ = save_selected_index(&selected_index_path, index);
    }

    let item = selected_index
        .and_then(|index| entries.get(index))
        .map(|e| e.id.clone())
        .unwrap_or_default();

    let sep = parse_separator(&args.composite_separator);

    match exit {
        19 => {
            let mut c = Command::new("fuzzel")
                .args([
                    "-d",
                    "--placeholder",
                    "Delete history?",
                    "--lines",
                    "2",
                    "--width",
                    "40",
                ])
                .stdin(Stdio::piped())
                .stdout(Stdio::piped())
                .spawn()?;
            c.stdin.as_mut().unwrap().write_all(b"No\nYes\n")?;
            let o = c.wait_with_output()?;
            if String::from_utf8_lossy(&o.stdout).trim() == "Yes" {
                let _ = Command::new("cliphist").arg("wipe").status();
                let _ = fs::remove_dir_all(&thumb_dir);
                cache.entries.clear();
                let _ = save_cache(&cache_path, &cache);
                let _ = clear_file(&composite_path);
                let _ = save_selected_index(&selected_index_path, 0);
            }
        }
        10 => {
            if !item.is_empty() {
                let mut child = Command::new("cliphist")
                    .arg("delete")
                    .stdin(Stdio::piped())
                    .spawn()?;
                child
                    .stdin
                    .as_mut()
                    .unwrap()
                    .write_all(format!("{}\n", item).as_bytes())?;
                let _ = child.wait();
                cache.entries.remove(&item);
                let _ = save_cache(&cache_path, &cache);
            }
        }
        11 => {
            if !item.is_empty() {
                let line = entries.iter().find(|e| e.id == item);
                if let Some(e) = line {
                    if !is_binary_preview(&e.raw_preview) {
                        let new_content = String::from_utf8_lossy(&decode_entry(&item)?).to_string();
                        let mut composite = read_text_file(&composite_path);
                        if composite.is_empty() {
                            composite = new_content;
                        } else {
                            composite.push_str(&sep);
                            composite.push_str(&new_content);
                        }
                        write_text_file(&composite_path, &composite)?;
                        if args.relaunch_after_composite_action {
                            relaunch_self();
                        }
                    }
                }
            }
        }
        12 => {
            let composite = read_text_file(&composite_path);
            if !composite.is_empty() {
                write_clipboard(composite.as_bytes())?;
                clear_file(&composite_path)?;
            }
            return Ok(());
        }
        13 => {
            clear_file(&composite_path)?;
            if args.relaunch_after_composite_action {
                relaunch_self();
            }
        }
        0 => {
            if !item.is_empty() {
                write_clipboard(&decode_entry(&item)?)?;
            }
        }
        _ => {}
    }

    Ok(())
}
