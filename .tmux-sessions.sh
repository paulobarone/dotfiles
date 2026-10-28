#!/bin/bash

PROJ="$HOME/Projects"
mkdir -p "$PROJ"

tmux has-session -t main 2>/dev/null || tmux new-session -d -s main -c "$PROJ"
tmux has-session -t secondary 2>/dev/null || tmux new-session -d -s secondary -c "$PROJ"
tmux has-session -t third 2>/dev/null || tmux new-session -d -s third -c "$PROJ"

tmux attach-session -t main
