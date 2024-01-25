# PHP-Tester

## Description

This is a simple helper, which launches a php container with an editor, a live-refreshing output, and (if requested) a database instance.

## Use

runner.sh [options]

## Options

- `--db`: Launches an additional mysql-container and sets up the php script with corresponding bootstrapping
- `--editor <editor>`: Additionally launches the editor of your choice
- `--version <version>`: Which php version to use (defaults to 8.1)
- `--file <file>`: Which file to mount into the containter (defaults to a random temp file if omitted)
- `--help`: Displays a help text

## Requirements

- Docker (thats how it spawns all the containers)
- tmux (for opening all the windows at once)
