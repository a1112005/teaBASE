#!/bin/bash
# * https://dotfiles.github.io/
# * https://news.ycombinator.com/item?id=11070797

set -eo pipefail

export GIT_DIR="${XDG_DATA_HOME:-$HOME/Library/Application Support}"/teaBASE/dotfiles.git
export GIT_WORK_TREE="$HOME"

BUNDLE="$(cd "$(dirname "$0")"/.. && pwd)"

main() {
  if test -d "$GIT_DIR"; then
    pull
    push
  elif [ -t 0 ]; then
    # ^^ launchd cannot do this stuff; we need an interactive session

    if ! gh auth status >/dev/null 2>&1; then
      gh auth login
    fi

    if ! gh repo view dotfiles --json id >/dev/null 2>&1; then
      gh repo create dotfiles --private
      clone
      git commit --allow-empty --message 'r0'
      push
    elif cold_start_choice; then
      gum format "# unimplemented" "we’ll get to it soon. soz"
      #cold_start
      #clone
    elif test $? -eq 1; then
      clone
      cd .
      git checkout --force HEAD  # replaces tracked files. ignores untracked files
      push
    else
      exit 130  # CTRL-C on cold_start_choice
    fi
  fi
}

clone() {
  USER="$(gh api user --jq '.login')"
  gh repo clone "git@github.com:$USER/dotfiles.git" "$GIT_DIR" -- --bare
  configure
  cp -f "$BUNDLE/Resources/dotfile-sync-exclude" "$GIT_DIR/info/exclude"
  rm "$GIT_DIR"/hooks/*.sample  # gardening
}

configure() {
  git config user.name "teaBASE"
  git config user.email "hello@tea.xyz"
  git config commit.gpgSign false
}

cold_start_choice() {
    gum format \
        "# GitHub dotfiles repo found" \
        "we can either replace the files here or perform an interactive merge." \
        "" \
        "* interactive merge allows you to choose how to combine both sets of files before committing, merging and pushing back to GitHub." \
        "* *replace* overwrites local files from your remote GitHub repo. No other files will be effected." \
        "" \
        "> ⌃C to abort"

    gum confirm --affirmative=Merge --negative=Replace
}

cold_start() {
  # TODO what if the repo has no commits?

  unset GIT_DIR  # or breaks our temporary clone

  cd "$(mktemp -d)"

  env -u GIT_WORK_TREE gh repo clone dotfiles .
  configure

  git checkout -b cold-start
  git add .

  if ! git diff-index --quiet HEAD --; then
    git commit --message "in situ ($(hostname))"
    git checkout main --force
    if ! git merge --no-ff cold-start --message "r$(git rev-list --count HEAD)"; then
      resolve
    fi
    git push origin main
  fi

  export GIT_DIR="${XDG_DATA_HOME:-$HOME/Library/Application Support}"/teaBASE/dotfiles.git
}

pull() {
  if ! git pull origin main --no-ff; then
    resolve
  fi
}

resolve() {
  #TODO if editor is a cli then we need terminal to be launched
  #  ^^ ideally pick a merge client of some sort

  if test "$EDITOR" = "code"; then
    EDITOR="code --wait"
  fi
  # get the user to handle the merge
  git diff --name-only --relative -z --diff-filter=U | xargs -0 ${EDITOR}
  git merge --continue
}

push() {
  set +e  # prevent errors for no files
  git add "$HOME/.aws/config"
  git add "$HOME/.bash_login"
  git add "$HOME/.bashrc"
  git add "$HOME/.bash_profile"
  git add "$HOME/.config/btop/btop.conf"
  git add "$HOME/.config/fish/config.fish"
  git add "$HOME/.config/**/config.xml"
  git add "$HOME/.config/**/config.yml"
  git add "$HOME/.config/**/config.json"
  git add "$HOME/.config/**/settings.json"
  git add "$HOME/.gitconfig"
  git add "$HOME/.profile"
  git add "$HOME/.ssh/config"
  git add "$HOME/.vimrc"
  git add "$HOME/.zprofile"
  git add "$HOME/.zshrc"
  set -e

  if ! git diff-index --quiet HEAD --; then
    git commit --message "r$(git rev-list --count HEAD)"
    git push origin main
  fi
}

prep() {
  export PATH="$BUNDLE/MacOS:${PATH:+:$PATH}"

  set -a
  eval "$(pkgx +gh +gum +git)"
  set +a

  if test "$VERBOSE"; then
    set -x
  fi
}

prep
main
