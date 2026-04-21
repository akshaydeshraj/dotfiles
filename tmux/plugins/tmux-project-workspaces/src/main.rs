use rayon::prelude::*;
use std::collections::{HashMap, HashSet};
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

#[derive(Clone, Debug)]
struct Context {
    projects_file: PathBuf,
    notify_dir: PathBuf,
    current_session: String,
    sessions: HashMap<String, Option<String>>,
}

#[derive(Clone, Debug)]
struct WorktreeRow {
    path: String,
    branch: String,
    kind: String,
}

fn main() {
    let mut args = env::args().skip(1);
    match args.next().as_deref() {
        Some("render") => render_cmd(),
        Some("describe-row") => {
            let key = args.next().unwrap_or_default();
            let path = args.next().unwrap_or_default();
            let repo = args.next().unwrap_or_default();
            let kind = args.next().unwrap_or_default();
            describe_row_cmd(&key, &path, &repo, &kind);
        }
        Some("resolve-repo") => {
            let name = args.next().unwrap_or_default();
            if let Some(repo) = resolve_repo_by_name(&context(), &name) {
                println!("{repo}");
            }
        }
        Some("untracked-candidates") => untracked_candidates_cmd(),
        Some("find-delete-target") => {
            let session = args.next().unwrap_or_default();
            if let Some((repo, wt_path, kind)) = find_delete_target(&context(), &session) {
                println!("{repo}\t{wt_path}\t{kind}");
            }
        }
        Some("create-worktree") => {
            let repo = args.next().unwrap_or_default();
            let branch = args.next().unwrap_or_default();
            create_worktree_cmd(&repo, &branch);
        }
        Some("remove-worktree") => {
            let session = args.next().unwrap_or_default();
            remove_worktree_cmd(&session);
        }
        Some("untrack-project") => {
            let repo = args.next().unwrap_or_default();
            untrack_project_cmd(&repo);
        }
        Some("kill-policy") => {
            let key = args.next().unwrap_or_default();
            kill_policy_cmd(&key);
        }
        Some("open-plain-session") => {
            let query = args.next().unwrap_or_default();
            let client = args.next().unwrap_or_default();
            open_plain_session_cmd(&query, &client);
        }
        Some("open-worktree-session") => {
            let repo = args.next().unwrap_or_default();
            let wt_path = args.next().unwrap_or_default();
            let branch = args.next().unwrap_or_default();
            let client = args.next().unwrap_or_default();
            open_worktree_session_cmd(&repo, &wt_path, &branch, &client);
        }
        _ => {
            eprintln!(
                "usage: tmux-project-workspaces <render|describe-row|resolve-repo|untracked-candidates|find-delete-target|create-worktree|remove-worktree|untrack-project|kill-policy|open-plain-session|open-worktree-session>"
            );
            std::process::exit(1);
        }
    }
}

fn render_cmd() {
    let ctx = context();
    let projects = list_projects(&ctx.projects_file);
    let plain_sessions = list_plain_sessions(&ctx.sessions);

    if projects.is_empty() && plain_sessions.is_empty() {
        println!(
            "\tHINT:\t\x1b[90m(no projects yet - type a repo name + enter to add, or ^a to pick)\x1b[0m\t\t\t\t"
        );
        return;
    }

    println!("new-worktree\tACTION:new-worktree\t\x1b[32m+ new worktree\x1b[0m\t\t\t\taction");

    if !projects.is_empty() {
        println!("\tSECTION:projects\t\x1b[1;33mProjects\x1b[0m\t\t\t\tsection");
        let project_blocks: Vec<String> = projects
            .par_iter()
            .map(|repo| render_project(repo, &ctx))
            .collect();
        for block in project_blocks {
            print!("{block}");
        }
    }

    if !plain_sessions.is_empty() {
        println!("\tSECTION:plain\t\x1b[1;36mSessions\x1b[0m\t\t\t\tsection");
        for (session, path) in plain_sessions {
            let marker = if session == ctx.current_session {
                " ●"
            } else {
                ""
            };
            let path = path.unwrap_or_else(|| home_dir().display().to_string());
            println!(
                "{session}\tSESSION:{session}\t    \x1b[36m{session:<36}\x1b[0m\t\x1b[90m[live]{marker} [session]\x1b[0m\t{path}\t\tplain"
            );
        }
    }
}

fn describe_row_cmd(key: &str, path: &str, repo: &str, kind: &str) {
    match key {
        "ACTION:new-worktree" => {
            println!("Actions\nenter/^n: choose project and create worktree");
        }
        k if k.starts_with("REPO:") => {
            println!("Projects\nenter/^n: new worktree  ^x: untrack\nrepo: {repo}");
        }
        "SECTION:projects" => {
            println!("Projects\n^a: add repo");
        }
        "SECTION:plain" => {
            println!("Sessions\nenter: switch");
        }
        k if k.starts_with("SESSION:") => {
            let shown_path = if path.is_empty() {
                home_dir().display().to_string()
            } else {
                path.to_string()
            };
            println!("Sessions\nenter: switch\npath: {shown_path}");
        }
        k if k.starts_with("HINT:") => {
            println!("Hints\n^a: add repo");
        }
        k if k.contains('/') => {
            if kind == "primary" {
                println!(
                    "Projects\nenter: switch  ^p: PR\nprimary checkout: delete disabled\npath: {path}"
                );
            } else {
                println!("Projects\nenter: switch  ^d: delete  ^p: PR\npath: {path}");
            }
        }
        _ => println!("Picker\nenter: switch"),
    }
}

fn untracked_candidates_cmd() {
    let ctx = context();
    for repo in untracked_candidates(&ctx) {
        println!("{repo}");
    }
}

fn create_worktree_cmd(repo: &str, branch: &str) {
    if repo.is_empty() || branch.is_empty() {
        std::process::exit(0);
    }

    let ctx = context();
    let Some(repo) = canonicalize_repo_arg(repo) else {
        eprintln!("unable to resolve repo: {repo}");
        std::process::exit(1);
    };

    let name = repo_basename(&repo);
    let worktree_root = env_path(
        "PROJECT_WORKSPACES_WORKTREE_ROOT",
        home_dir().join("worktrees"),
    );
    let wt_path = worktree_root.join(&name).join(branch);
    if let Some(parent) = wt_path.parent() {
        let _ = fs::create_dir_all(parent);
    }

    let wt_str = wt_path.to_string_lossy().into_owned();
    let attached = worktree_rows(&repo).iter().any(|row| row.path == wt_str);
    if !attached {
        if git_ref_exists(&repo, &format!("refs/heads/{branch}")) {
            if let Err(err) = run_checked("git", &["-C", &repo, "worktree", "add", &wt_str, branch])
            {
                eprintln!("{err}");
                std::process::exit(1);
            }
        } else if git_ref_exists(&repo, &format!("refs/remotes/origin/{branch}")) {
            if let Err(err) = run_checked(
                "git",
                &[
                    "-C",
                    &repo,
                    "worktree",
                    "add",
                    "--track",
                    "-b",
                    branch,
                    &wt_str,
                    &format!("origin/{branch}"),
                ],
            ) {
                eprintln!("{err}");
                std::process::exit(1);
            }
        } else if let Err(err) = run_checked(
            "git",
            &["-C", &repo, "worktree", "add", "-b", branch, &wt_str],
        ) {
            eprintln!("{err}");
            std::process::exit(1);
        }
    }

    let _ = add_project_path(&ctx.projects_file, &repo);
    println!("{repo}\t{wt_str}\t{name}\t{branch}");
}

fn remove_worktree_cmd(session: &str) {
    if session.is_empty() || !session.contains('/') {
        eprintln!("bad session name: {session}");
        std::process::exit(1);
    }

    let ctx = context();
    let Some((repo, wt_path, kind)) = find_delete_target(&ctx, session) else {
        eprintln!("unable to resolve worktree for {session}");
        std::process::exit(1);
    };

    if kind == "primary" {
        eprintln!("refusing to remove primary checkout: {session}");
        std::process::exit(2);
    }

    let branch = session
        .split_once('/')
        .map(|(_, branch)| branch.to_string())
        .unwrap_or_default();

    if let Err(err) = run_checked(
        "git",
        &["-C", &repo, "worktree", "remove", "--force", &wt_path],
    ) {
        eprintln!("{err}");
    }
    if Path::new(&wt_path).exists() {
        let _ = fs::remove_dir_all(&wt_path);
    }

    let branch_delete = run_checked("git", &["-C", &repo, "branch", "-d", &branch])
        .or_else(|_| run_checked("git", &["-C", &repo, "branch", "-D", &branch]));
    if let Err(err) = branch_delete {
        eprintln!("{err}");
    }

    println!("{repo}\t{wt_path}\t{kind}\t{branch}");
}

fn untrack_project_cmd(repo: &str) {
    if repo.is_empty() {
        std::process::exit(0);
    }
    let ctx = context();
    if let Some(resolved) = canonicalize_repo_arg(repo) {
        let _ = remove_project_path(&ctx.projects_file, &resolved);
        println!("{resolved}");
    }
}

fn kill_policy_cmd(key: &str) {
    let ctx = context();
    let decision = kill_policy(&ctx, key);
    println!("{}\t{}", decision.action, decision.message);
    if decision.action == "blocked" {
        std::process::exit(2);
    }
}

fn open_plain_session_cmd(query: &str, client: &str) {
    let session = sanitize_session_name(query);
    let session = if session.is_empty() {
        "scratch".to_string()
    } else {
        session
    };

    if !tmux_session_exists(&session) {
        if let Err(err) = run_checked(
            "tmux",
            &[
                "new-session",
                "-ds",
                &session,
                "-c",
                &home_dir().to_string_lossy(),
                "-n",
                &session,
            ],
        ) {
            eprintln!("{err}");
            std::process::exit(1);
        }
    }

    if let Err(err) = switch_to_session(&session, client) {
        eprintln!("{err}");
        std::process::exit(1);
    }

    println!("{session}");
}

fn open_worktree_session_cmd(repo: &str, wt_path: &str, branch: &str, client: &str) {
    if repo.is_empty() || wt_path.is_empty() || branch.is_empty() {
        std::process::exit(0);
    }

    let repo_name = repo_basename(repo);
    let session = format!("{repo_name}/{branch}");
    if !tmux_session_exists(&session) {
        if let Some(init_script) = worktree_init_script(repo) {
            let mut cmd = Command::new(init_script);
            cmd.current_dir(wt_path)
                .env("TMUX_SESSION", &session)
                .env("WORKTREE_PATH", wt_path)
                .env("BRANCH", branch)
                .env("REPO_ROOT", repo);
            let _ = cmd.status();
        }

        let home = home_dir().to_string_lossy().into_owned();
        let _ = home; // silence if optimized path changes later
        if let Err(err) = run_checked(
            "tmux",
            &["new-session", "-ds", &session, "-c", wt_path, "-n", "work"],
        ) {
            eprintln!("{err}");
            std::process::exit(1);
        }
        let _ = run_checked(
            "tmux",
            &[
                "new-window",
                "-t",
                &format!("{session}:"),
                "-n",
                "git",
                "-c",
                wt_path,
                "lazygit",
            ],
        );
        let _ = run_checked(
            "tmux",
            &[
                "new-window",
                "-t",
                &format!("{session}:"),
                "-n",
                "free",
                "-c",
                wt_path,
            ],
        );
        let _ = run_checked(
            "tmux",
            &["set-environment", "-t", &session, "WORKTREE_PATH", wt_path],
        );
        let _ = run_checked(
            "tmux",
            &["set-environment", "-t", &session, "REPO_ROOT", repo],
        );
        let _ = run_checked(
            "tmux",
            &["set-environment", "-t", &session, "WORKTREE_BRANCH", branch],
        );
        let _ = run_checked("tmux", &["select-window", "-t", &format!("{session}:work")]);
    }

    if let Err(err) = switch_to_session(&session, client) {
        eprintln!("{err}");
        std::process::exit(1);
    }

    println!("{session}");
}

fn context() -> Context {
    let projects_file = env_path(
        "PROJECT_WORKSPACES_PROJECTS_FILE",
        default_state_dir().join("projects.txt"),
    );
    let notify_dir = env_path(
        "PROJECT_WORKSPACES_NOTIFY_DIR",
        default_cache_dir().join("notify"),
    );
    let current_session = run("tmux", ["display-message", "-p", "#S"])
        .map(|s| s.trim().to_string())
        .unwrap_or_default();
    let sessions = tmux_sessions();

    Context {
        projects_file,
        notify_dir,
        current_session,
        sessions,
    }
}

#[derive(Clone, Debug)]
struct KillDecision {
    action: &'static str,
    message: String,
}

fn render_project(repo: &str, ctx: &Context) -> String {
    let name = Path::new(repo)
        .file_name()
        .map(|s| s.to_string_lossy().into_owned())
        .unwrap_or_else(|| repo.to_string());
    let rows = worktree_rows(repo);
    let mut out = String::new();

    if rows.is_empty() {
        out.push_str(&format!(
            "{name}\tREPO:{name}\t\x1b[90m▸ {name}\x1b[0m\t\t{repo}\t{repo}\trepo\n"
        ));
        return out;
    }

    out.push_str(&format!(
        "{name}\tREPO:{name}\t\x1b[1;33m▾ {name}\x1b[0m\t\t{repo}\t{repo}\trepo\n"
    ));

    let rendered_rows: Vec<String> = rows
        .par_iter()
        .map(|row| {
            let session = format!("{name}/{}", row.branch);
            let mut markers = String::new();
            if session == ctx.current_session {
                markers.push_str(" ●");
            }
            if ctx.notify_dir.join(&session).exists() {
                markers.push_str(" 🤖");
            }
            if worktree_dirty(&row.path) {
                markers.push_str(" ◆");
            }
            let live = if ctx.sessions.contains_key(&session) {
                "[live]"
            } else {
                "[stopped]"
            };
            let age = git_log_age(&row.path).unwrap_or_default();
            let mut tags = String::new();
            if row.kind == "primary" {
                tags.push_str(" [primary]");
            }
            if markers.contains('◆') {
                tags.push_str(" [dirty]");
                markers = markers.replace(" ◆", "");
            }
            if markers.contains('🤖') {
                tags.push_str(" [agent]");
                markers = markers.replace(" 🤖", "");
            }
            format!(
                "{session}\t{session}\t    \x1b[36m{:<36}\x1b[0m\t\x1b[90m{live}{markers}{tags} {age}\x1b[0m\t{}\t{repo}\t{}\n",
                row.branch, row.path, row.kind
            )
        })
        .collect();

    for row in rendered_rows {
        out.push_str(&row);
    }

    out
}

fn list_projects(projects_file: &Path) -> Vec<String> {
    let Ok(contents) = fs::read_to_string(projects_file) else {
        return Vec::new();
    };

    let mut seen = HashSet::new();
    let mut projects = Vec::new();
    for line in contents.lines() {
        let p = line.trim();
        if p.is_empty() || p.starts_with('#') {
            continue;
        }
        let path = Path::new(p);
        if !is_git_repo(path) {
            continue;
        }
        if seen.insert(p.to_string()) {
            projects.push(p.to_string());
        }
    }
    projects.sort_by_key(|s| s.to_lowercase());
    projects
}

fn add_project_path(projects_file: &Path, repo: &str) -> std::io::Result<()> {
    let mut projects = list_projects(projects_file);
    if projects.iter().any(|p| p == repo) {
        return Ok(());
    }
    projects.push(repo.to_string());
    projects.sort_by_key(|s| s.to_lowercase());
    write_projects(projects_file, &projects)
}

fn remove_project_path(projects_file: &Path, repo: &str) -> std::io::Result<()> {
    let projects: Vec<String> = list_projects(projects_file)
        .into_iter()
        .filter(|p| p != repo)
        .collect();
    write_projects(projects_file, &projects)
}

fn write_projects(projects_file: &Path, projects: &[String]) -> std::io::Result<()> {
    if let Some(parent) = projects_file.parent() {
        fs::create_dir_all(parent)?;
    }
    let mut contents = String::new();
    for project in projects {
        contents.push_str(project);
        contents.push('\n');
    }
    fs::write(projects_file, contents)
}

fn tmux_sessions() -> HashMap<String, Option<String>> {
    let mut sessions = HashMap::new();
    if let Some(output) = run(
        "tmux",
        ["list-sessions", "-F", "#{session_name}|#{session_path}"],
    ) {
        for line in output.lines() {
            let mut parts = line.splitn(2, '|');
            let name = parts.next().unwrap_or("").trim();
            if name.is_empty() {
                continue;
            }
            let path = parts
                .next()
                .map(|p| p.trim().to_string())
                .filter(|p| !p.is_empty());
            sessions.insert(name.to_string(), path);
        }
    }
    sessions
}

fn list_plain_sessions(
    sessions: &HashMap<String, Option<String>>,
) -> Vec<(String, Option<String>)> {
    let mut rows: Vec<_> = sessions
        .iter()
        .filter(|(name, _)| !name.contains('/'))
        .map(|(name, path)| (name.clone(), path.clone()))
        .collect();
    rows.sort_by_key(|(name, _)| name.to_lowercase());
    rows
}

fn worktree_rows(repo: &str) -> Vec<WorktreeRow> {
    let Some(output) = run("git", ["-C", repo, "worktree", "list", "--porcelain"]) else {
        return Vec::new();
    };

    let mut rows = Vec::new();
    let mut wt: Option<String> = None;
    for line in output.lines() {
        if let Some(rest) = line.strip_prefix("worktree ") {
            wt = Some(rest.to_string());
            continue;
        }
        if let Some(rest) = line.strip_prefix("branch ") {
            if let Some(wt_path) = wt.take() {
                let branch = rest.trim_start_matches("refs/heads/").to_string();
                let kind = if wt_path == repo {
                    "primary"
                } else {
                    "worktree"
                };
                rows.push(WorktreeRow {
                    path: wt_path,
                    branch,
                    kind: kind.to_string(),
                });
            }
        }
    }
    rows
}

fn resolve_repo_by_name(ctx: &Context, name: &str) -> Option<String> {
    if name.is_empty() {
        return None;
    }

    let mut seen = HashSet::new();
    for repo in list_projects(&ctx.projects_file) {
        if repo_basename(&repo) == name && seen.insert(repo.clone()) {
            return Some(repo);
        }
    }

    for repo in zoxide_repos() {
        if repo_basename(&repo) == name && seen.insert(repo.clone()) {
            return Some(repo);
        }
    }

    None
}

fn untracked_candidates(ctx: &Context) -> Vec<String> {
    let tracked: HashSet<String> = list_projects(&ctx.projects_file).into_iter().collect();
    let mut seen = HashSet::new();
    let mut repos = Vec::new();

    for repo in zoxide_repos() {
        if tracked.contains(&repo) {
            continue;
        }
        if seen.insert(repo.clone()) {
            repos.push(repo);
        }
    }

    repos.sort_by_key(|s| s.to_lowercase());
    repos
}

fn zoxide_repos() -> Vec<String> {
    let Some(output) = run("zoxide", ["query", "-l"]) else {
        return Vec::new();
    };
    output
        .lines()
        .map(str::trim)
        .filter(|line| !line.is_empty())
        .filter(|line| is_git_repo(Path::new(line)))
        .map(ToOwned::to_owned)
        .collect()
}

fn find_delete_target(ctx: &Context, session: &str) -> Option<(String, String, String)> {
    if session.is_empty() || !session.contains('/') {
        return None;
    }

    let repo_name = session.split('/').next().unwrap_or_default();
    let branch = session.split_once('/').map(|(_, b)| b).unwrap_or_default();

    if let Some(session_path) = ctx.sessions.get(session).and_then(|p| p.clone()) {
        if Path::new(&session_path).is_dir()
            && let Some(repo) = canonical_repo_from_path(&session_path)
        {
            let kind = if session_path == repo {
                "primary"
            } else {
                "worktree"
            };
            return Some((repo, session_path, kind.to_string()));
        }
    }

    for repo in list_projects(&ctx.projects_file) {
        if repo_basename(&repo) != repo_name {
            continue;
        }
        for row in worktree_rows(&repo) {
            if row.branch == branch {
                return Some((repo.clone(), row.path, row.kind));
            }
        }
    }

    None
}

fn kill_policy(ctx: &Context, key: &str) -> KillDecision {
    if key.is_empty()
        || key.starts_with("ACTION:")
        || key.starts_with("REPO:")
        || key.starts_with("HINT:")
        || key.starts_with("SECTION:")
    {
        return KillDecision {
            action: "blocked",
            message: "no kill action for this row".to_string(),
        };
    }

    if let Some(session) = key.strip_prefix("SESSION:") {
        if ctx.sessions.contains_key(session) {
            return KillDecision {
                action: "kill",
                message: session.to_string(),
            };
        }
        return KillDecision {
            action: "blocked",
            message: format!("session not running: {session}"),
        };
    }

    if !ctx.sessions.contains_key(key) {
        if let Some((repo, _wt_path, kind)) = find_delete_target(ctx, key) {
            if kind == "primary" {
                return KillDecision {
                    action: "blocked",
                    message: format!("protected primary checkout: {key}"),
                };
            }

            let branch = key
                .split_once('/')
                .map(|(_, branch)| branch.to_string())
                .unwrap_or_default();
            let Some(base) = local_base_branch(&repo) else {
                return KillDecision {
                    action: "blocked",
                    message: format!("no local main/master in {}", repo_basename(&repo)),
                };
            };

            if branch == base {
                return KillDecision {
                    action: "blocked",
                    message: format!("refusing to remove base branch worktree: {key}"),
                };
            }

            if branch_disposable(&repo, &branch, &base) {
                return KillDecision {
                    action: "remove",
                    message: key.to_string(),
                };
            }
        }
        return KillDecision {
            action: "blocked",
            message: format!("session not running: {key}"),
        };
    }

    let Some((repo, _wt_path, kind)) = find_delete_target(ctx, key) else {
        return KillDecision {
            action: "blocked",
            message: format!("unable to resolve session: {key}"),
        };
    };

    if kind == "primary" {
        return KillDecision {
            action: "blocked",
            message: format!("protected primary checkout: {key}"),
        };
    }

    let branch = key
        .split_once('/')
        .map(|(_, branch)| branch.to_string())
        .unwrap_or_default();

    let Some(base) = local_base_branch(&repo) else {
        return KillDecision {
            action: "blocked",
            message: format!("no local main/master in {}", repo_basename(&repo)),
        };
    };

    if branch == base {
        return KillDecision {
            action: "blocked",
            message: format!("refusing to kill base branch session: {key}"),
        };
    }

    if branch_disposable(&repo, &branch, &base) {
        KillDecision {
            action: "remove",
            message: key.to_string(),
        }
    } else {
        KillDecision {
            action: "blocked",
            message: format!("not merged into {base}: {branch}"),
        }
    }
}

fn canonical_repo_from_path(path: &str) -> Option<String> {
    let common = run("git", ["-C", path, "rev-parse", "--git-common-dir"])?;
    let common = common.trim();
    if common.is_empty() {
        return None;
    }

    let common_path = if common.starts_with('/') {
        PathBuf::from(common)
    } else {
        Path::new(path).join(common)
    };
    let canonical = fs::canonicalize(common_path).ok()?;
    let canonical_str = canonical.to_string_lossy();

    if let Some(repo) = canonical_str.strip_suffix("/.git") {
        Some(repo.to_string())
    } else {
        Some(canonical_str.into_owned())
    }
}

fn local_base_branch(repo: &str) -> Option<String> {
    if git_ref_exists(repo, "refs/heads/main") {
        Some("main".to_string())
    } else if git_ref_exists(repo, "refs/heads/master") {
        Some("master".to_string())
    } else {
        None
    }
}

fn branch_merged_into(repo: &str, branch: &str, base: &str) -> bool {
    Command::new("git")
        .args(["-C", repo, "merge-base", "--is-ancestor", branch, base])
        .status()
        .map(|status| status.success())
        .unwrap_or(false)
}

fn branch_disposable(repo: &str, branch: &str, base: &str) -> bool {
    if branch == base {
        return false;
    }

    branch_matches(repo, branch, base) || branch_merged_into(repo, branch, base)
}

fn branch_matches(repo: &str, branch: &str, base: &str) -> bool {
    let Some(branch_sha) = rev_parse(repo, branch) else {
        return false;
    };
    let Some(base_sha) = rev_parse(repo, base) else {
        return false;
    };
    branch_sha == base_sha
}

fn rev_parse(repo: &str, rev: &str) -> Option<String> {
    run("git", ["-C", repo, "rev-parse", rev]).map(|s| s.trim().to_string())
}

fn sanitize_session_name(raw: &str) -> String {
    let mut out = String::new();
    let mut last_dash = false;
    for ch in raw.chars() {
        let normalized = if ch == '/' || ch.is_whitespace() {
            '-'
        } else {
            ch
        };
        if normalized.is_ascii_alphanumeric()
            || normalized == '_'
            || normalized == '.'
            || normalized == '-'
        {
            if normalized == '-' {
                if last_dash {
                    continue;
                }
                last_dash = true;
            } else {
                last_dash = false;
            }
            out.push(normalized);
        }
    }
    out.trim_matches('-').to_string()
}

fn tmux_session_exists(session: &str) -> bool {
    let target = format!("={session}");
    Command::new("tmux")
        .args(["has-session", "-t", &target])
        .stderr(Stdio::null())
        .stdout(Stdio::null())
        .status()
        .map(|status| status.success())
        .unwrap_or(false)
}

fn switch_to_session(session: &str, client: &str) -> Result<String, String> {
    let target = format!("={session}");
    if client.is_empty() {
        run_checked("tmux", &["switch-client", "-t", &target])
    } else {
        run_checked("tmux", &["switch-client", "-c", client, "-t", &target])
    }
}

fn worktree_init_script(repo: &str) -> Option<PathBuf> {
    let script = Path::new(repo).join(".worktree-init.sh");
    if script.is_file() { Some(script) } else { None }
}

fn canonicalize_repo_arg(repo: &str) -> Option<String> {
    let path = Path::new(repo);
    if is_git_repo(path) {
        let canonical = fs::canonicalize(path).ok()?;
        return Some(canonical.to_string_lossy().into_owned());
    }
    canonical_repo_from_path(repo)
}

fn repo_basename(repo: &str) -> String {
    Path::new(repo)
        .file_name()
        .map(|s| s.to_string_lossy().into_owned())
        .unwrap_or_else(|| repo.to_string())
}

fn is_git_repo(path: &Path) -> bool {
    path.exists() && (path.join(".git").exists() || path.join(".git").is_file())
}

fn worktree_dirty(path: &str) -> bool {
    run("git", ["-C", path, "status", "--porcelain"])
        .map(|s| !s.trim().is_empty())
        .unwrap_or(false)
}

fn git_log_age(path: &str) -> Option<String> {
    run("git", ["-C", path, "log", "-1", "--format=%cr"]).map(|s| s.trim().to_string())
}

fn run<const N: usize>(cmd: &str, args: [&str; N]) -> Option<String> {
    let output = Command::new(cmd).args(args).output().ok()?;
    if !output.status.success() {
        return None;
    }
    String::from_utf8(output.stdout).ok()
}

fn run_checked(cmd: &str, args: &[&str]) -> Result<String, String> {
    let output = Command::new(cmd)
        .args(args)
        .output()
        .map_err(|err| err.to_string())?;
    if output.status.success() {
        return String::from_utf8(output.stdout).map_err(|err| err.to_string());
    }
    let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();
    if stderr.is_empty() {
        Err(format!("{cmd} failed"))
    } else {
        Err(stderr)
    }
}

fn git_ref_exists(repo: &str, ref_name: &str) -> bool {
    Command::new("git")
        .args(["-C", repo, "show-ref", "--verify", "--quiet", ref_name])
        .status()
        .map(|status| status.success())
        .unwrap_or(false)
}

fn env_path(key: &str, default: PathBuf) -> PathBuf {
    env::var_os(key).map(PathBuf::from).unwrap_or(default)
}

fn home_dir() -> PathBuf {
    env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("/"))
}

fn default_state_dir() -> PathBuf {
    env::var_os("XDG_STATE_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| home_dir().join(".local/state"))
        .join("tmux-project-workspaces")
}

fn default_cache_dir() -> PathBuf {
    env::var_os("XDG_CACHE_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| home_dir().join(".cache"))
        .join("tmux-project-workspaces")
}
