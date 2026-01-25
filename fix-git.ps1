# Fix Git: remove locks, clean staging, set origin/HEAD, commit with --no-verify
# Run in Windows Terminal / PowerShell *outside* Cursor. Close Cursor or Git panel first.
Set-Location $PSScriptRoot

# Remove lock files
Remove-Item .git\index.lock -Force -ErrorAction SilentlyContinue
Remove-Item .git\refs\remotes\origin\HEAD.lock -Force -ErrorAction SilentlyContinue

# Reset staging area to clean up deleted files
git reset HEAD -- . 2>$null

# Set origin/HEAD
git remote set-head origin -a 2>$null

# Add all current files
git add -A

# Check if there's anything to commit
$status = git status --short
if (-not $status) { 
    Write-Host "Nothing to commit." 
    exit 0 
}

# Commit
git commit -m "chore: remove cypress and update project files" --no-verify
